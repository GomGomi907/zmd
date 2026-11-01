const std = @import("std");
const windows = std.os.windows;
const setup = @import("setup");
const file_assoc = setup.file_assoc_win32;

const DWORD = u32;
const LPCWSTR = [*:0]const u16;

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
extern "advapi32" fn RegDeleteTreeW(key: windows.HKEY, sub_key: LPCWSTR) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegCloseKey(key: windows.HKEY) callconv(.winapi) windows.LSTATUS;

const error_success: windows.LSTATUS = 0;
const error_file_not_found: windows.LSTATUS = 2;
const key_read: windows.REGSAM = windows.ACCESS_MASK.Specific.Key.READ;
const key_write: windows.REGSAM = windows.ACCESS_MASK.Specific.Key.WRITE;
const key_read_write: windows.REGSAM = @bitCast(@as(u32, @bitCast(key_read)) | @as(u32, @bitCast(key_write)));
const allowed_root_prefix = "Software\\zmd-uninstall-e2e-";

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len < 3 or !std.mem.startsWith(u8, args[2], allowed_root_prefix)) return error.InvalidIsolatedRegistryRoot;

    if (std.mem.eql(u8, args[1], "seed")) {
        if (args.len != 5) return error.InvalidArguments;
        const root = try createRoot(allocator, args[2]);
        defer _ = RegCloseKey(root);
        const installed_exe = try std.fs.path.join(allocator, &.{ args[3], "zmd.exe" });
        try file_assoc.installRegisteredExecutableAtRoot(allocator, root, installed_exe, args[3], args[4], 123);
        return;
    }
    if (std.mem.eql(u8, args[1], "apply")) {
        if (args.len != 6) return error.InvalidArguments;
        const parent_pid = try std.fmt.parseInt(DWORD, args[3], 10);
        const root = try openRoot(allocator, args[2]);
        defer _ = RegCloseKey(root);
        try setup.waitForParent(parent_pid);
        try setup.applyUninstallAt(allocator, root, init.io, args[4], args[5]);
        return;
    }
    if (std.mem.eql(u8, args[1], "verify-absent")) {
        if (args.len != 3) return error.InvalidArguments;
        const root = try openRoot(allocator, args[2]);
        defer _ = RegCloseKey(root);
        if (try keyExists(allocator, root, file_assoc.uninstall_path)) return error.UninstallRegistrationStillPresent;
        if (try keyExists(allocator, root, "Software\\Classes\\zmd.Markdown")) return error.FileAssociationStillPresent;
        return;
    }
    if (std.mem.eql(u8, args[1], "cleanup")) {
        if (args.len != 3) return error.InvalidArguments;
        const root_w = try std.unicode.utf8ToUtf16LeAllocZ(allocator, args[2]);
        const status = RegDeleteTreeW(windows.HKEY_CURRENT_USER, root_w.ptr);
        if (status != error_success and status != error_file_not_found) return error.RegistryCleanupFailed;
        return;
    }
    return error.InvalidArguments;
}

fn createRoot(allocator: std.mem.Allocator, path: []const u8) !windows.HKEY {
    const path_w = try std.unicode.utf8ToUtf16LeAllocZ(allocator, path);
    var root: windows.HKEY = undefined;
    if (RegCreateKeyExW(windows.HKEY_CURRENT_USER, path_w.ptr, 0, null, 0, key_read_write, null, &root, null) != error_success) {
        return error.RegistryCreateFailed;
    }
    return root;
}

fn openRoot(allocator: std.mem.Allocator, path: []const u8) !windows.HKEY {
    const path_w = try std.unicode.utf8ToUtf16LeAllocZ(allocator, path);
    var root: windows.HKEY = undefined;
    if (RegOpenKeyExW(windows.HKEY_CURRENT_USER, path_w.ptr, 0, key_read_write, &root) != error_success) {
        return error.RegistryOpenFailed;
    }
    return root;
}

fn keyExists(allocator: std.mem.Allocator, root: windows.HKEY, subkey: []const u8) !bool {
    const subkey_w = try std.unicode.utf8ToUtf16LeAllocZ(allocator, subkey);
    var key: windows.HKEY = undefined;
    const status = RegOpenKeyExW(root, subkey_w.ptr, 0, key_read, &key);
    if (status == error_file_not_found) return false;
    if (status != error_success) return error.RegistryQueryFailed;
    _ = RegCloseKey(key);
    return true;
}
