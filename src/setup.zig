const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const file_assoc = @import("file_assoc.zig");

const DWORD = u32;
const UINT = u32;
const LPCWSTR = [*:0]const u16;
const LPWSTR = [*:0]u16;

extern "kernel32" fn GetModuleFileNameW(hModule: ?*anyopaque, lpFilename: LPWSTR, nSize: DWORD) callconv(.winapi) DWORD;
extern "user32" fn MessageBoxW(hWnd: ?*anyopaque, lpText: LPCWSTR, lpCaption: LPCWSTR, uType: UINT) callconv(.winapi) c_int;

const MB_OK: UINT = 0x00000000;
const MB_ICONINFORMATION: UINT = 0x00000040;
const MB_ICONERROR: UINT = 0x00000010;

pub fn isSetupExecutable(exe_arg: []const u8) bool {
    const name = std.fs.path.basename(exe_arg);
    return std.ascii.indexOfIgnoreCase(name, "setup") != null;
}

pub fn run(allocator: std.mem.Allocator, io: Io, environ_map: *std.process.Environ.Map, args: []const []const u8) !void {
    var quiet = false;
    var uninstall_requested = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--quiet")) {
            quiet = true;
        } else if (std.mem.eql(u8, arg, "--uninstall")) {
            uninstall_requested = true;
        } else if (std.mem.eql(u8, arg, "--help")) {
            if (!quiet) alert(allocator, "zmd setup", "Run zmd-setup.exe to install zmd for the current user.\n\nOptions:\n  --quiet       Install without a success dialog\n  --uninstall   Remove zmd's file association registration", .info);
            return;
        } else {
            fatal(allocator, "zmd setup", "Unknown setup option", error.InvalidArgument, quiet);
        }
    }

    if (uninstall_requested) {
        uninstall(allocator) catch |err| fatal(allocator, "zmd setup", "Unable to uninstall zmd", err, quiet);
        if (!quiet) alert(allocator, "zmd setup", "Removed zmd's Windows file association registration.", .info);
        return;
    }

    install(allocator, io, environ_map, quiet) catch |err| fatal(allocator, "zmd setup", "Unable to install zmd", err, quiet);
}

fn install(allocator: std.mem.Allocator, io: Io, environ_map: *std.process.Environ.Map, quiet: bool) !void {
    if (builtin.os.tag != .windows) return error.UnsupportedPlatform;

    const install_dir = try installDir(allocator, environ_map);
    defer allocator.free(install_dir);

    const installed_exe = try std.fs.path.join(allocator, &.{ install_dir, "zmd.exe" });
    defer allocator.free(installed_exe);

    const source_exe = try currentExePath(allocator);
    defer allocator.free(source_exe);

    try Io.Dir.cwd().createDirPath(io, install_dir);
    try Io.Dir.copyFileAbsolute(source_exe, installed_exe, io, .{
        .replace = true,
        .make_path = true,
    });
    try file_assoc.installExecutablePath(allocator, installed_exe);

    if (!quiet) {
        const message = try std.fmt.allocPrint(
            allocator,
            "Installed zmd to:\n{s}\n\nzmd is now registered as a Windows Markdown app. In Windows Open with, choose zmd and select Always to make .md files use the zmd document icon.",
            .{installed_exe},
        );
        alert(allocator, "zmd setup", message, .info);
    }
}

fn uninstall(allocator: std.mem.Allocator) !void {
    if (builtin.os.tag != .windows) return error.UnsupportedPlatform;
    try file_assoc.uninstall(allocator);
}

fn installDir(allocator: std.mem.Allocator, environ_map: *std.process.Environ.Map) ![]u8 {
    const local_app_data = environ_map.get("LOCALAPPDATA") orelse return error.LocalAppDataMissing;
    if (local_app_data.len == 0) return error.LocalAppDataMissing;
    return std.fs.path.join(allocator, &.{ local_app_data, "Programs", "zmd" });
}

fn currentExePath(allocator: std.mem.Allocator) ![]u8 {
    var capacity: DWORD = 260;
    while (capacity <= 32768) : (capacity *= 2) {
        const buffer = try allocator.allocSentinel(u16, capacity, 0);
        const len = GetModuleFileNameW(null, buffer.ptr, capacity);
        if (len == 0) {
            allocator.free(buffer);
            return error.ExecutablePathUnavailable;
        }
        if (len < capacity - 1) {
            const path = try std.unicode.wtf16LeToWtf8Alloc(allocator, buffer[0..len]);
            allocator.free(buffer);
            return path;
        }
        allocator.free(buffer);
    }
    return error.ExecutablePathTooLong;
}

const AlertIcon = enum {
    info,
    err,
};

fn alert(allocator: std.mem.Allocator, title: []const u8, text: []const u8, icon: AlertIcon) void {
    const fallback_title = std.unicode.utf8ToUtf16LeStringLiteral("zmd setup");
    const fallback_text = std.unicode.utf8ToUtf16LeStringLiteral("zmd setup message");
    const title_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, title) catch null;
    const text_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, text) catch null;

    const flags = MB_OK | switch (icon) {
        .info => MB_ICONINFORMATION,
        .err => MB_ICONERROR,
    };
    _ = MessageBoxW(
        null,
        if (text_w) |slice| slice.ptr else fallback_text.ptr,
        if (title_w) |slice| slice.ptr else fallback_title.ptr,
        flags,
    );
}

fn fatal(allocator: std.mem.Allocator, title: []const u8, context: []const u8, err: anyerror, quiet: bool) noreturn {
    if (!quiet) {
        const message = std.fmt.allocPrint(allocator, "{s}: {s}", .{ context, @errorName(err) }) catch context;
        alert(allocator, title, message, .err);
    }
    std.process.exit(1);
}

test "detects setup executable names" {
    try std.testing.expect(isSetupExecutable("zmd-setup.exe"));
    try std.testing.expect(isSetupExecutable("C:\\Temp\\zmd-setup-windows-x86_64.exe"));
    try std.testing.expect(!isSetupExecutable("C:\\Users\\LGS\\AppData\\Local\\Programs\\zmd\\zmd.exe"));
}
