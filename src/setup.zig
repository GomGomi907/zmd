const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
const Io = std.Io;
const file_assoc = @import("file_assoc.zig");
pub const file_assoc_win32 = @import("file_assoc_win32.zig");
const zmd = @import("zmd");

const DWORD = u32;
const UINT = u32;
const LPCWSTR = [*:0]const u16;
const LPWSTR = [*:0]u16;

extern "kernel32" fn GetModuleFileNameW(hModule: ?*anyopaque, lpFilename: LPWSTR, nSize: DWORD) callconv(.winapi) DWORD;
extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) DWORD;
extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;
extern "kernel32" fn CreateMutexW(attributes: ?*anyopaque, initial_owner: windows.BOOL, name: LPCWSTR) callconv(.winapi) ?windows.HANDLE;
extern "kernel32" fn WaitForSingleObject(handle: windows.HANDLE, milliseconds: DWORD) callconv(.winapi) DWORD;
extern "kernel32" fn ReleaseMutex(handle: windows.HANDLE) callconv(.winapi) windows.BOOL;
extern "kernel32" fn CloseHandle(handle: windows.HANDLE) callconv(.winapi) windows.BOOL;
extern "kernel32" fn MoveFileExW(existing: LPCWSTR, new: ?LPCWSTR, flags: DWORD) callconv(.winapi) windows.BOOL;
extern "kernel32" fn GetFileAttributesExW(filename: LPCWSTR, info_level: c_int, data: *WIN32_FILE_ATTRIBUTE_DATA) callconv(.winapi) windows.BOOL;
extern "version" fn GetFileVersionInfoSizeW(filename: LPCWSTR, handle: ?*DWORD) callconv(.winapi) DWORD;
extern "version" fn GetFileVersionInfoW(filename: LPCWSTR, handle: DWORD, length: DWORD, data: *anyopaque) callconv(.winapi) windows.BOOL;
extern "version" fn VerQueryValueW(block: *const anyopaque, sub_block: LPCWSTR, buffer: *?*anyopaque, length: *UINT) callconv(.winapi) windows.BOOL;
extern "user32" fn MessageBoxW(hWnd: ?*anyopaque, lpText: LPCWSTR, lpCaption: LPCWSTR, uType: UINT) callconv(.winapi) c_int;

const MB_OK: UINT = 0x00000000;
const MB_ICONINFORMATION: UINT = 0x00000040;
const MB_ICONERROR: UINT = 0x00000010;
const wait_object_0: DWORD = 0;
const wait_abandoned: DWORD = 128;
const wait_timeout: DWORD = 258;
const maintenance_timeout_ms: DWORD = 10_000;
pub const uninstall_helper_argument = "--uninstall-helper";
const VS_FIXEDFILEINFO = extern struct {
    signature: DWORD,
    struct_version: DWORD,
    file_version_ms: DWORD,
    file_version_ls: DWORD,
    product_version_ms: DWORD,
    product_version_ls: DWORD,
    file_flags_mask: DWORD,
    file_flags: DWORD,
    file_os: DWORD,
    file_type: DWORD,
    file_subtype: DWORD,
    file_date_ms: DWORD,
    file_date_ls: DWORD,
};
const WIN32_FILE_ATTRIBUTE_DATA = extern struct {
    attributes: DWORD,
    creation_low: DWORD,
    creation_high: DWORD,
    access_low: DWORD,
    access_high: DWORD,
    write_low: DWORD,
    write_high: DWORD,
    size_high: DWORD,
    size_low: DWORD,
};
const InstallState = struct { io: Io, source: []const u8, installed: []const u8, dir: []const u8 };
const UninstallState = struct { io: Io, install_dir: []const u8, helper: []const u8 };
const RegistrationState = struct { exe: []const u8, dir: []const u8 };

pub fn isSetupExecutable(exe_arg: []const u8) bool {
    const name = std.fs.path.basename(exe_arg);
    return std.ascii.indexOfIgnoreCase(name, "setup") != null;
}

pub fn isSetupArgument(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--uninstall") or std.mem.eql(u8, arg, uninstall_helper_argument);
}

pub fn run(allocator: std.mem.Allocator, io: Io, environ_map: *std.process.Environ.Map, args: []const []const u8) !void {
    if (args.len >= 2 and std.mem.eql(u8, args[1], uninstall_helper_argument)) {
        if (args.len != 3) fatal(allocator, "zmd uninstall", "Invalid uninstall helper arguments", error.InvalidArgument, false);
        const parent_pid = std.fmt.parseInt(DWORD, args[2], 10) catch fatal(allocator, "zmd uninstall", "Invalid parent process", error.InvalidArgument, false);
        runUninstallHelper(allocator, io, environ_map, parent_pid) catch |err| fatal(allocator, "zmd uninstall", "Unable to remove zmd. Close every zmd window and try again", err, false);
        return;
    }
    var quiet = false;
    var uninstall_requested = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--quiet")) {
            quiet = true;
        } else if (std.mem.eql(u8, arg, "--uninstall")) {
            uninstall_requested = true;
        } else if (std.mem.eql(u8, arg, "--help")) {
            if (!quiet) alert(allocator, "zmd setup", "Run zmd-setup.exe to install zmd for the current user.\n\nOptions:\n  --quiet       Install without a success dialog\n  --uninstall   Remove zmd for the current user", .info);
            return;
        } else {
            fatal(allocator, "zmd setup", "Unknown setup option", error.InvalidArgument, quiet);
        }
    }

    if (uninstall_requested) {
        launchUninstall(allocator, io, environ_map) catch |err| fatal(allocator, "zmd uninstall", "Unable to start removal", err, false);
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

    try withMaintenanceLock(allocator, struct {
        fn run(a: std.mem.Allocator, state: InstallState) !void {
            try Io.Dir.cwd().createDirPath(state.io, state.dir);
            try copyInstallation(a, state.io, state.source, state.installed);
            const installed_stat = try Io.Dir.cwd().statFile(state.io, state.installed, .{});
            const estimated_size_kb: u32 = @intCast(@min((installed_stat.size + 1023) / 1024, std.math.maxInt(u32)));
            try file_assoc.installRegisteredExecutable(a, state.installed, state.dir, zmd.version, estimated_size_kb);
        }
    }.run, InstallState{ .io = io, .source = source_exe, .installed = installed_exe, .dir = install_dir });

    if (!quiet) {
        const message = try std.fmt.allocPrint(
            allocator,
            "Installed zmd to:\n{s}\n\nzmd is now registered as a Windows Markdown app. In Windows Open with, choose zmd and select Always to make .md files use the zmd document icon.",
            .{installed_exe},
        );
        alert(allocator, "zmd setup", message, .info);
    }
}

pub fn copyInstallation(allocator: std.mem.Allocator, io: Io, source: []const u8, target: []const u8) !void {
    Io.Dir.copyFileAbsolute(source, target, io, .{ .replace = true, .make_path = true }) catch |err| switch (err) {
        error.AccessDenied => try @import("updater_win32.zig").replacePreservingOld(allocator, io, source, target),
        else => return err,
    };
}

fn launchUninstall(allocator: std.mem.Allocator, io: Io, environ_map: *std.process.Environ.Map) !void {
    const install_dir = try installDir(allocator, environ_map);
    defer allocator.free(install_dir);
    const installed_exe = try std.fs.path.join(allocator, &.{ install_dir, "zmd.exe" });
    defer allocator.free(installed_exe);
    const current = try currentExePath(allocator);
    defer allocator.free(current);
    if (!try @import("uninstall_windows_win32.zig").pathsEqual(allocator, current, installed_exe)) return error.NotInstalledExecutable;
    const temp = environ_map.get("TEMP") orelse return error.TempDirectoryMissing;
    const helper_name = try uninstallHelperName(io, allocator, current);
    defer allocator.free(helper_name);
    const helper_path = try std.fs.path.join(allocator, &.{ temp, helper_name });
    defer allocator.free(helper_path);
    try ensureUninstallHelper(io, allocator, current, helper_path);
    const pid = try std.fmt.allocPrint(allocator, "{}", .{GetCurrentProcessId()});
    defer allocator.free(pid);
    _ = try std.process.spawn(io, .{ .argv = &.{ helper_path, uninstall_helper_argument, pid }, .stdin = .ignore, .stdout = .ignore, .stderr = .ignore, .create_no_window = true });
}

fn uninstallHelperName(io: Io, allocator: std.mem.Allocator, source: []const u8) ![]u8 {
    const candidate = try Io.Dir.cwd().readFileAlloc(io, source, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(candidate);
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(candidate, &digest, .{});
    const encoded = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, "zmd-uninstall-helper-{s}-{s}.exe", .{ zmd.version, encoded[0..16] });
}

fn ensureUninstallHelper(io: Io, allocator: std.mem.Allocator, source: []const u8, helper_path: []const u8) !void {
    const existing = Io.Dir.cwd().readFileAlloc(io, helper_path, allocator, .limited(16 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => {
            try Io.Dir.copyFileAbsolute(source, helper_path, io, .{ .replace = false, .make_path = true });
            return;
        },
        else => return err,
    };
    defer allocator.free(existing);
    const candidate = try Io.Dir.cwd().readFileAlloc(io, source, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(candidate);
    if (!std.mem.eql(u8, existing, candidate)) return error.UninstallHelperCollision;
}

fn runUninstallHelper(allocator: std.mem.Allocator, io: Io, environ_map: *std.process.Environ.Map, parent_pid: DWORD) !void {
    try waitForParent(parent_pid);
    const install_dir = try installDir(allocator, environ_map);
    defer allocator.free(install_dir);
    const helper_path = try currentExePath(allocator);
    defer allocator.free(helper_path);
    try withMaintenanceLock(allocator, struct {
        fn run(a: std.mem.Allocator, state: UninstallState) !void {
            const installed_exe = try std.fs.path.join(a, &.{ state.install_dir, "zmd.exe" });
            defer a.free(installed_exe);
            try validateUninstallHelperAt(a, state.io, state.install_dir, state.helper);
            try @import("uninstall_windows_win32.zig").closeInstalledWindows(a, installed_exe, 15_000);
            try applyUninstallAt(a, windows.HKEY_CURRENT_USER, state.io, state.install_dir, state.helper);
        }
    }.run, UninstallState{ .io = io, .install_dir = install_dir, .helper = helper_path });
}

pub fn waitForParent(parent_pid: DWORD) !void {
    try @import("updater_win32.zig").waitForProcess(parent_pid);
}

pub fn applyUninstallAt(allocator: std.mem.Allocator, root: windows.HKEY, io: Io, install_dir: []const u8, helper_path: []const u8) !void {
    return applyUninstallAtWithRegistry(ProductionRegistry, allocator, root, io, install_dir, helper_path);
}

const ProductionRegistry = struct {
    fn uninstall(allocator: std.mem.Allocator, root: windows.HKEY) !void {
        try file_assoc_win32.uninstallApplicationAtRoot(allocator, root);
    }
    fn install(allocator: std.mem.Allocator, root: windows.HKEY, exe: []const u8, dir: []const u8) !void {
        const size_kb = try installedSizeKb(allocator, exe);
        try file_assoc_win32.installRegisteredExecutableAtRoot(allocator, root, exe, dir, zmd.version, size_kb);
    }
};

pub fn applyUninstallAtWithRegistry(comptime Registry: type, allocator: std.mem.Allocator, root: windows.HKEY, io: Io, install_dir: []const u8, helper_path: []const u8) !void {
    const installed_exe = try std.fs.path.join(allocator, &.{ install_dir, "zmd.exe" });
    defer allocator.free(installed_exe);
    try validateUninstallHelperAt(allocator, io, install_dir, helper_path);

    const backup = try std.fmt.allocPrint(allocator, "{s}.uninstalling-{}-{}", .{ installed_exe, GetCurrentProcessId(), GetTickCount64() });
    defer allocator.free(backup);
    try movePath(allocator, installed_exe, backup);
    errdefer movePath(allocator, backup, installed_exe) catch {};
    Registry.uninstall(allocator, root) catch |err| {
        movePath(allocator, backup, installed_exe) catch return error.UninstallRollbackFailed;
        Registry.install(allocator, root, installed_exe, install_dir) catch return error.UninstallRollbackFailed;
        file_assoc_win32.notifyAssociationChanged();
        return err;
    };
    Io.Dir.deleteFileAbsolute(io, backup) catch |err| {
        movePath(allocator, backup, installed_exe) catch return error.UninstallRollbackFailed;
        Registry.install(allocator, root, installed_exe, install_dir) catch return error.UninstallRollbackFailed;
        file_assoc_win32.notifyAssociationChanged();
        return err;
    };
    file_assoc_win32.notifyAssociationChanged();
    Io.Dir.deleteDirAbsolute(io, install_dir) catch {};
}

pub fn validateUninstallHelperAt(allocator: std.mem.Allocator, io: Io, install_dir: []const u8, helper_path: []const u8) !void {
    const installed_exe = try std.fs.path.join(allocator, &.{ install_dir, "zmd.exe" });
    defer allocator.free(installed_exe);
    const installed = Io.Dir.cwd().readFileAlloc(io, installed_exe, allocator, .limited(16 * 1024 * 1024)) catch |err| switch (err) {
        error.AccessDenied, error.FileBusy => return error.UninstallFileBusy,
        else => return err,
    };
    defer allocator.free(installed);
    const helper = try Io.Dir.cwd().readFileAlloc(io, helper_path, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(helper);
    if (!std.mem.eql(u8, installed, helper)) return error.UninstallHelperMismatch;
}

fn movePath(allocator: std.mem.Allocator, source: []const u8, destination: []const u8) !void {
    const source_w = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, source);
    defer allocator.free(source_w);
    const destination_w = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, destination);
    defer allocator.free(destination_w);
    if (!MoveFileExW(source_w.ptr, destination_w.ptr, 0).toBool()) return error.UninstallFileBusy;
}

pub fn startInstalledMaintenance(local_app_data: ?[]const u8) void {
    const base = local_app_data orelse return;
    const allocator = std.heap.page_allocator;
    const current = currentExePath(allocator) catch return;
    defer allocator.free(current);
    const expected = std.fs.path.join(allocator, &.{ base, "Programs", "zmd", "zmd.exe" }) catch return;
    defer allocator.free(expected);
    if (!(@import("uninstall_windows_win32.zig").pathsEqual(allocator, current, expected) catch false)) return;
    const owned = allocator.dupe(u8, base) catch return;
    const context = allocator.create(MaintenanceContext) catch {
        allocator.free(owned);
        return;
    };
    context.* = .{ .local_app_data = owned };
    const thread = std.Thread.spawn(.{}, installedMaintenanceWorker, .{context}) catch {
        allocator.free(owned);
        allocator.destroy(context);
        return;
    };
    thread.detach();
}

const MaintenanceContext = struct { local_app_data: []u8 };

fn installedMaintenanceWorker(context: *MaintenanceContext) void {
    const allocator = std.heap.page_allocator;
    defer {
        allocator.free(context.local_app_data);
        allocator.destroy(context);
    }
    repairInstalledRegistration(allocator, context.local_app_data) catch {};
}

pub fn repairInstalledRegistration(allocator: std.mem.Allocator, local_app_data: []const u8) !void {
    const current = try currentExePath(allocator);
    defer allocator.free(current);
    const install_dir = try std.fs.path.join(allocator, &.{ local_app_data, "Programs", "zmd" });
    defer allocator.free(install_dir);
    const expected = try std.fs.path.join(allocator, &.{ install_dir, "zmd.exe" });
    defer allocator.free(expected);
    if (!try @import("uninstall_windows_win32.zig").pathsEqual(allocator, current, expected)) return;
    try withMaintenanceLock(allocator, struct {
        fn run(a: std.mem.Allocator, state: RegistrationState) !void {
            if (!try fileVersionMatches(a, state.exe, zmd.version)) return;
            if (try file_assoc_win32.registeredExecutableIsCurrent(a, windows.HKEY_CURRENT_USER, state.exe, zmd.version)) return;
            const size_kb = try installedSizeKb(a, state.exe);
            try file_assoc.installRegisteredExecutable(a, state.exe, state.dir, zmd.version, size_kb);
        }
    }.run, RegistrationState{ .exe = expected, .dir = install_dir });
}

fn installedSizeKb(allocator: std.mem.Allocator, path: []const u8) !u32 {
    const path_w = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, path);
    defer allocator.free(path_w);
    var data: WIN32_FILE_ATTRIBUTE_DATA = undefined;
    if (!GetFileAttributesExW(path_w.ptr, 0, &data).toBool()) return error.InstalledExecutableUnavailable;
    const size = (@as(u64, data.size_high) << 32) | data.size_low;
    return @intCast(@min((size + 1023) / 1024, std.math.maxInt(u32)));
}

fn fileVersionMatches(allocator: std.mem.Allocator, path: []const u8, expected: []const u8) !bool {
    const semantic = std.SemanticVersion.parse(expected) catch return false;
    const path_w = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, path);
    defer allocator.free(path_w);
    const size = GetFileVersionInfoSizeW(path_w.ptr, null);
    if (size == 0) return false;
    const data = try allocator.alloc(u8, size);
    defer allocator.free(data);
    if (!GetFileVersionInfoW(path_w.ptr, 0, size, data.ptr).toBool()) return false;
    const root = std.unicode.utf8ToUtf16LeStringLiteral("\\");
    var value: ?*anyopaque = null;
    var value_len: UINT = 0;
    if (!VerQueryValueW(data.ptr, root.ptr, &value, &value_len).toBool() or value_len < @sizeOf(VS_FIXEDFILEINFO)) return false;
    const info: *const VS_FIXEDFILEINFO = @ptrCast(@alignCast(value orelse return false));
    return info.signature == 0xFEEF04BD and
        (info.product_version_ms >> 16) == semantic.major and
        (info.product_version_ms & 0xffff) == semantic.minor and
        (info.product_version_ls >> 16) == semantic.patch;
}

fn withMaintenanceLock(allocator: std.mem.Allocator, comptime operation: anytype, state: anytype) !void {
    const name = std.unicode.utf8ToUtf16LeStringLiteral("Local\\zmd-update-replace");
    const mutex = CreateMutexW(null, .FALSE, name.ptr) orelse return error.MaintenanceLockUnavailable;
    defer _ = CloseHandle(mutex);
    switch (WaitForSingleObject(mutex, maintenance_timeout_ms)) {
        wait_object_0, wait_abandoned => {},
        wait_timeout => return error.MaintenanceLockTimeout,
        else => return error.MaintenanceLockFailed,
    }
    defer _ = ReleaseMutex(mutex);
    try operation(allocator, state);
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
