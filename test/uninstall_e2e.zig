const std = @import("std");
const windows = std.os.windows;
const setup = @import("setup");
const file_assoc = setup.file_assoc_win32;

const DWORD = u32;
const LPCWSTR = [*:0]const u16;

extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) DWORD;
extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;
extern "kernel32" fn CreateFileW(
    filename: LPCWSTR,
    desired_access: DWORD,
    share_mode: DWORD,
    security: ?*anyopaque,
    creation_disposition: DWORD,
    flags: DWORD,
    template: ?windows.HANDLE,
) callconv(.winapi) windows.HANDLE;
extern "kernel32" fn CloseHandle(handle: windows.HANDLE) callconv(.winapi) windows.BOOL;
extern "advapi32" fn RegCreateKeyExW(
    key: windows.HKEY,
    sub_key: LPCWSTR,
    reserved: DWORD,
    class: ?LPCWSTR,
    options: DWORD,
    access: windows.REGSAM,
    security: ?*anyopaque,
    result: *windows.HKEY,
    disposition: ?*DWORD,
) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegOpenKeyExW(
    key: windows.HKEY,
    sub_key: LPCWSTR,
    options: DWORD,
    access: windows.REGSAM,
    result: *windows.HKEY,
) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegQueryValueExW(
    key: windows.HKEY,
    value_name: LPCWSTR,
    reserved: ?*DWORD,
    value_type: ?*DWORD,
    data: ?[*]u8,
    data_size: *DWORD,
) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegDeleteTreeW(key: windows.HKEY, sub_key: LPCWSTR) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegCloseKey(key: windows.HKEY) callconv(.winapi) windows.LSTATUS;

const error_success: windows.LSTATUS = 0;
const error_file_not_found: windows.LSTATUS = 2;
const key_read: windows.REGSAM = windows.ACCESS_MASK.Specific.Key.READ;
const key_write: windows.REGSAM = windows.ACCESS_MASK.Specific.Key.WRITE;
const key_read_write: windows.REGSAM = @bitCast(@as(u32, @bitCast(key_read)) | @as(u32, @bitCast(key_write)));
const generic_read: DWORD = 0x80000000;
const open_existing: DWORD = 3;

const Fixture = struct {
    tmp: std.testing.TmpDir,
    root_path: []u8,
    root_path_w: [:0]u16,
    registry: windows.HKEY,
    install_dir: []u8,
    installed_exe: []u8,
    helper_exe: []u8,
    personal_document: []u8,

    fn init() !Fixture {
        var tmp = std.testing.tmpDir(.{});
        errdefer tmp.cleanup();
        const temp_root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", std.testing.allocator);
        defer std.testing.allocator.free(temp_root);
        const install_dir = try std.fs.path.join(std.testing.allocator, &.{ temp_root, "한글 경로 with space" });
        errdefer std.testing.allocator.free(install_dir);
        const installed_exe = try std.fs.path.join(std.testing.allocator, &.{ install_dir, "zmd.exe" });
        errdefer std.testing.allocator.free(installed_exe);
        const helper_exe = try std.fs.path.join(std.testing.allocator, &.{ temp_root, "zmd-uninstall-helper.exe" });
        errdefer std.testing.allocator.free(helper_exe);
        const personal_document = try std.fs.path.join(std.testing.allocator, &.{ install_dir, "개인 문서.md" });
        errdefer std.testing.allocator.free(personal_document);

        try std.Io.Dir.cwd().createDirPath(std.testing.io, install_dir);
        try std.Io.Dir.cwd().writeFile(std.testing.io, .{ .sub_path = installed_exe, .data = "same zmd executable bytes" });
        try std.Io.Dir.cwd().writeFile(std.testing.io, .{ .sub_path = helper_exe, .data = "same zmd executable bytes" });
        try std.Io.Dir.cwd().writeFile(std.testing.io, .{ .sub_path = personal_document, .data = "keep this document" });

        const root_path = try std.fmt.allocPrint(std.testing.allocator, "Software\\zmd-uninstall-e2e-{}-{}", .{ GetCurrentProcessId(), GetTickCount64() });
        errdefer std.testing.allocator.free(root_path);
        const root_path_w = try std.unicode.utf8ToUtf16LeAllocZ(std.testing.allocator, root_path);
        errdefer std.testing.allocator.free(root_path_w);
        var registry: windows.HKEY = undefined;
        try std.testing.expectEqual(error_success, RegCreateKeyExW(
            windows.HKEY_CURRENT_USER,
            root_path_w.ptr,
            0,
            null,
            0,
            key_read_write,
            null,
            &registry,
            null,
        ));
        errdefer {
            _ = RegCloseKey(registry);
            _ = RegDeleteTreeW(windows.HKEY_CURRENT_USER, root_path_w.ptr);
        }
        try file_assoc.installRegisteredExecutableAtRoot(std.testing.allocator, registry, installed_exe, install_dir, "9.8.7", 123);

        return .{
            .tmp = tmp,
            .root_path = root_path,
            .root_path_w = root_path_w,
            .registry = registry,
            .install_dir = install_dir,
            .installed_exe = installed_exe,
            .helper_exe = helper_exe,
            .personal_document = personal_document,
        };
    }

    fn deinit(self: *Fixture) void {
        _ = RegCloseKey(self.registry);
        _ = RegDeleteTreeW(windows.HKEY_CURRENT_USER, self.root_path_w.ptr);
        std.testing.allocator.free(self.root_path_w);
        std.testing.allocator.free(self.root_path);
        std.testing.allocator.free(self.personal_document);
        std.testing.allocator.free(self.helper_exe);
        std.testing.allocator.free(self.installed_exe);
        std.testing.allocator.free(self.install_dir);
        self.tmp.cleanup();
    }
};

test "uninstall removes owned executable and registration while preserving a personal document" {
    var fixture = try Fixture.init();
    defer fixture.deinit();
    try createKey(fixture.registry, "Software\\zmd\\PersonalSettings");

    try setup.applyUninstallAt(std.testing.allocator, fixture.registry, std.testing.io, fixture.install_dir, fixture.helper_exe);

    try std.testing.expectError(error.FileNotFound, std.Io.Dir.cwd().statFile(std.testing.io, fixture.installed_exe, .{}));
    const document = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, fixture.personal_document, std.testing.allocator, .limited(64));
    defer std.testing.allocator.free(document);
    try std.testing.expectEqualStrings("keep this document", document);
    try std.testing.expect(!(try keyExists(fixture.registry, file_assoc.uninstall_path)));
    try std.testing.expect(!(try keyExists(fixture.registry, "Software\\Classes\\zmd.Markdown")));
    try std.testing.expect(try keyExists(fixture.registry, "Software\\zmd\\PersonalSettings"));
}

test "installed registration writes a quoted visible uninstall command" {
    var fixture = try Fixture.init();
    defer fixture.deinit();

    const visible = try readStringValue(fixture.registry, file_assoc.uninstall_path, "UninstallString");
    defer std.testing.allocator.free(visible);
    const expected_visible = try std.fmt.allocPrint(std.testing.allocator, "\"{s}\" --uninstall", .{fixture.installed_exe});
    defer std.testing.allocator.free(expected_visible);

    try std.testing.expectEqualStrings(expected_visible, visible);
    try std.testing.expect(!(try valueExists(fixture.registry, file_assoc.uninstall_path, "QuietUninstallString")));
}

test "uninstall rejects a helper whose bytes differ and keeps the retry path" {
    var fixture = try Fixture.init();
    defer fixture.deinit();
    try std.Io.Dir.cwd().writeFile(std.testing.io, .{ .sub_path = fixture.helper_exe, .data = "different helper bytes" });

    try std.testing.expectError(
        error.UninstallHelperMismatch,
        setup.applyUninstallAt(std.testing.allocator, fixture.registry, std.testing.io, fixture.install_dir, fixture.helper_exe),
    );

    _ = try std.Io.Dir.cwd().statFile(std.testing.io, fixture.installed_exe, .{});
    try std.testing.expect(try keyExists(fixture.registry, file_assoc.uninstall_path));
}

test "uninstall keeps registration when another handle prevents moving the executable" {
    var fixture = try Fixture.init();
    defer fixture.deinit();
    const path_w = try std.unicode.wtf8ToWtf16LeAllocZ(std.testing.allocator, fixture.installed_exe);
    defer std.testing.allocator.free(path_w);
    const locked = CreateFileW(path_w.ptr, generic_read, 0, null, open_existing, 0, null);
    try std.testing.expect(locked != windows.INVALID_HANDLE_VALUE);

    try std.testing.expectError(
        error.UninstallFileBusy,
        setup.applyUninstallAt(std.testing.allocator, fixture.registry, std.testing.io, fixture.install_dir, fixture.helper_exe),
    );

    _ = CloseHandle(locked);
    _ = try std.Io.Dir.cwd().statFile(std.testing.io, fixture.installed_exe, .{});
    try std.testing.expect(try keyExists(fixture.registry, file_assoc.uninstall_path));
}

test "registry cleanup failure restores the executable and retry registration" {
    var fixture = try Fixture.init();
    defer fixture.deinit();
    const FailingCleanup = struct {
        pub fn uninstall(_: std.mem.Allocator, _: windows.HKEY) !void {
            return error.InjectedRegistryFailure;
        }
        pub fn install(allocator: std.mem.Allocator, root: windows.HKEY, exe: []const u8, dir: []const u8) !void {
            try file_assoc.installRegisteredExecutableAtRoot(allocator, root, exe, dir, "9.8.7", 123);
        }
    };

    try std.testing.expectError(
        error.InjectedRegistryFailure,
        setup.applyUninstallAtWithRegistry(FailingCleanup, std.testing.allocator, fixture.registry, std.testing.io, fixture.install_dir, fixture.helper_exe),
    );

    _ = try std.Io.Dir.cwd().statFile(std.testing.io, fixture.installed_exe, .{});
    try std.testing.expect(try keyExists(fixture.registry, file_assoc.uninstall_path));
}

fn keyExists(root: windows.HKEY, subkey: []const u8) !bool {
    const subkey_w = try std.unicode.utf8ToUtf16LeAllocZ(std.testing.allocator, subkey);
    defer std.testing.allocator.free(subkey_w);
    var key: windows.HKEY = undefined;
    const status = RegOpenKeyExW(root, subkey_w.ptr, 0, key_read, &key);
    if (status != error_success) return false;
    _ = RegCloseKey(key);
    return true;
}

fn createKey(root: windows.HKEY, subkey: []const u8) !void {
    const subkey_w = try std.unicode.utf8ToUtf16LeAllocZ(std.testing.allocator, subkey);
    defer std.testing.allocator.free(subkey_w);
    var key: windows.HKEY = undefined;
    try std.testing.expectEqual(error_success, RegCreateKeyExW(root, subkey_w.ptr, 0, null, 0, key_write, null, &key, null));
    _ = RegCloseKey(key);
}

fn readStringValue(root: windows.HKEY, subkey: []const u8, value_name: []const u8) ![]u8 {
    const subkey_w = try std.unicode.utf8ToUtf16LeAllocZ(std.testing.allocator, subkey);
    defer std.testing.allocator.free(subkey_w);
    const value_name_w = try std.unicode.utf8ToUtf16LeAllocZ(std.testing.allocator, value_name);
    defer std.testing.allocator.free(value_name_w);
    var key: windows.HKEY = undefined;
    try std.testing.expectEqual(error_success, RegOpenKeyExW(root, subkey_w.ptr, 0, key_read, &key));
    defer _ = RegCloseKey(key);
    var buffer: [1024]u16 = undefined;
    var bytes: DWORD = @sizeOf(@TypeOf(buffer));
    try std.testing.expectEqual(error_success, RegQueryValueExW(key, value_name_w.ptr, null, null, @ptrCast(&buffer), &bytes));
    const units = bytes / @sizeOf(u16);
    const text_len = if (units > 0 and buffer[units - 1] == 0) units - 1 else units;
    return std.unicode.wtf16LeToWtf8Alloc(std.testing.allocator, buffer[0..text_len]);
}

fn valueExists(root: windows.HKEY, subkey: []const u8, value_name: []const u8) !bool {
    const subkey_w = try std.unicode.utf8ToUtf16LeAllocZ(std.testing.allocator, subkey);
    defer std.testing.allocator.free(subkey_w);
    const value_name_w = try std.unicode.utf8ToUtf16LeAllocZ(std.testing.allocator, value_name);
    defer std.testing.allocator.free(value_name_w);
    var key: windows.HKEY = undefined;
    try std.testing.expectEqual(error_success, RegOpenKeyExW(root, subkey_w.ptr, 0, key_read, &key));
    defer _ = RegCloseKey(key);
    var bytes: DWORD = 0;
    const status = RegQueryValueExW(key, value_name_w.ptr, null, null, null, &bytes);
    if (status == error_file_not_found) return false;
    if (status != error_success) return error.RegistryQueryFailed;
    return true;
}
