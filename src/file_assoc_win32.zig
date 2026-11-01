const std = @import("std");
const windows = std.os.windows;
const Error = @import("file_assoc.zig").Error;
const build_options = @import("build_options");

const DWORD = u32;
const UINT = u32;
const ULONG = u32;
const LPCWSTR = [*:0]const u16;
const LPWSTR = [*:0]u16;

extern "kernel32" fn GetModuleFileNameW(hModule: ?*anyopaque, lpFilename: LPWSTR, nSize: DWORD) callconv(.winapi) DWORD;
extern "kernel32" fn GetEnvironmentVariableW(name: LPCWSTR, buffer: ?LPWSTR, size: DWORD) callconv(.winapi) DWORD;
extern "advapi32" fn RegCreateKeyExW(
    hKey: windows.HKEY,
    lpSubKey: LPCWSTR,
    Reserved: DWORD,
    lpClass: ?LPCWSTR,
    dwOptions: DWORD,
    samDesired: windows.REGSAM,
    lpSecurityAttributes: ?*anyopaque,
    phkResult: *windows.HKEY,
    lpdwDisposition: ?*DWORD,
) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegOpenKeyExW(
    hKey: windows.HKEY,
    lpSubKey: LPCWSTR,
    ulOptions: DWORD,
    samDesired: windows.REGSAM,
    phkResult: *windows.HKEY,
) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegSetValueExW(
    hKey: windows.HKEY,
    lpValueName: ?LPCWSTR,
    Reserved: DWORD,
    dwType: windows.REG.ValueType,
    lpData: ?[*]const u8,
    cbData: DWORD,
) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegQueryValueExW(hKey: windows.HKEY, lpValueName: LPCWSTR, reserved: ?*DWORD, value_type: ?*DWORD, data: ?[*]u8, data_size: ?*DWORD) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegDeleteTreeW(hKey: windows.HKEY, lpSubKey: LPCWSTR) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegDeleteValueW(hKey: windows.HKEY, lpValueName: LPCWSTR) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegCloseKey(hKey: windows.HKEY) callconv(.winapi) windows.LSTATUS;
extern "shell32" fn SHChangeNotify(wEventId: c_long, uFlags: UINT, dwItem1: ?*const anyopaque, dwItem2: ?*const anyopaque) callconv(.winapi) void;

const reg_option_non_volatile: DWORD = 0;
const error_success: windows.LSTATUS = 0;
const error_file_not_found: windows.LSTATUS = 2;
const error_path_not_found: windows.LSTATUS = 3;
const key_write: windows.REGSAM = windows.ACCESS_MASK.Specific.Key.WRITE;
const key_read: windows.REGSAM = windows.ACCESS_MASK.Specific.Key.READ;
const shcne_assocchanged: c_long = 0x08000000;
const shcnf_idlist: UINT = 0x0000;
pub const capabilities_path = "Software\\Classes\\zmd.Markdown\\Capabilities";
pub const uninstall_path = "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\zmd";

pub fn install(allocator: std.mem.Allocator) Error!void {
    const exe_path = try currentExePathW(allocator);
    defer allocator.free(exe_path);

    try installExecutablePathW(allocator, exe_path);
}

pub fn installExecutablePath(allocator: std.mem.Allocator, exe_path: []const u8) Error!void {
    const exe_path_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, exe_path) catch return error.RegistryWriteFailed;
    defer allocator.free(exe_path_w);

    try installExecutablePathW(allocator, exe_path_w);
}

pub fn installExecutablePathW(allocator: std.mem.Allocator, exe_path: []const u16) Error!void {
    try installExecutablePathAtRoot(allocator, windows.HKEY_CURRENT_USER, exe_path);
    notifyAssociationChanged();
}

pub fn installExecutablePathAtRoot(allocator: std.mem.Allocator, root: windows.HKEY, exe_path: []const u16) Error!void {
    const command = try quotedOpenCommand(allocator, exe_path);
    defer allocator.free(command);

    const icon = try executableIconValue(allocator, exe_path);
    defer allocator.free(icon);

    try setDefaultValueAt(root, allocator, "Software\\Classes\\zmd.Markdown", "zmd Markdown Document");
    try setStringValueAt(root, allocator, "Software\\Classes\\zmd.Markdown", "FriendlyTypeName", "zmd Markdown Document");
    try setStringValueAt(root, allocator, "Software\\Classes\\zmd.Markdown", "PerceivedType", "text");
    try setStringValueAt(root, allocator, "Software\\Classes\\zmd.Markdown", "Content Type", "text/markdown");
    try setDefaultValueWAt(root, allocator, "Software\\Classes\\zmd.Markdown\\DefaultIcon", icon);
    try setDefaultValueAt(root, allocator, "Software\\Classes\\zmd.Markdown\\shell\\open", "Open with zmd");
    try setDefaultValueWAt(root, allocator, "Software\\Classes\\zmd.Markdown\\shell\\open\\command", command);

    try setEmptyValueAt(root, allocator, "Software\\Classes\\.md\\OpenWithProgids", "zmd.Markdown", .NONE);

    try setStringValueAt(root, allocator, "Software\\Classes\\Applications\\zmd.exe", "FriendlyAppName", "zmd");
    try setDefaultValueWAt(root, allocator, "Software\\Classes\\Applications\\zmd.exe\\DefaultIcon", icon);
    try setDefaultValueWAt(root, allocator, "Software\\Classes\\Applications\\zmd.exe\\shell\\open\\command", command);
    try setEmptyValueAt(root, allocator, "Software\\Classes\\Applications\\zmd.exe\\SupportedTypes", ".md", .NONE);

    try setStringValueAt(root, allocator, capabilities_path, "ApplicationName", "zmd");
    try setStringValueAt(root, allocator, capabilities_path, "ApplicationDescription", "Tiny Markdown viewer");
    try setStringValueAt(root, allocator, capabilities_path ++ "\\FileAssociations", ".md", "zmd.Markdown");
    try setStringValueAt(root, allocator, "Software\\RegisteredApplications", "zmd", capabilities_path);
    try deleteTreeIfPresentAt(root, allocator, "Software\\zmd\\Capabilities");
}

pub fn installRegisteredExecutable(allocator: std.mem.Allocator, exe_path: []const u8, install_dir: []const u8, version: []const u8, estimated_size_kb: u32) Error!void {
    try installRegisteredExecutableAtRoot(allocator, windows.HKEY_CURRENT_USER, exe_path, install_dir, version, estimated_size_kb);
    notifyAssociationChanged();
}

pub fn installRegisteredExecutableAtRoot(allocator: std.mem.Allocator, root: windows.HKEY, exe_path: []const u8, install_dir: []const u8, version: []const u8, estimated_size_kb: u32) Error!void {
    try deleteValueIfPresentAt(root, allocator, uninstall_path, "RegistrationComplete");
    const exe_path_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, exe_path) catch return error.RegistryWriteFailed;
    defer allocator.free(exe_path_w);
    try installExecutablePathAtRoot(allocator, root, exe_path_w);
    const uninstall_command = std.fmt.allocPrint(allocator, "\"{s}\" --uninstall", .{exe_path}) catch return error.RegistryWriteFailed;
    defer allocator.free(uninstall_command);
    const display_icon = std.fmt.allocPrint(allocator, "\"{s}\",0", .{exe_path}) catch return error.RegistryWriteFailed;
    defer allocator.free(display_icon);
    try setStringValueAt(root, allocator, uninstall_path, "DisplayName", "zmd");
    try setStringValueAt(root, allocator, uninstall_path, "DisplayVersion", version);
    try setStringValueAt(root, allocator, uninstall_path, "Publisher", "GomGomi907");
    try setStringValueAt(root, allocator, uninstall_path, "InstallLocation", install_dir);
    try setStringValueAt(root, allocator, uninstall_path, "DisplayIcon", display_icon);
    try setStringValueAt(root, allocator, uninstall_path, "UninstallString", uninstall_command);
    try deleteValueIfPresentAt(root, allocator, uninstall_path, "QuietUninstallString");
    try setStringValueAt(root, allocator, uninstall_path, "URLInfoAbout", "https://github.com/GomGomi907/zmd");
    try setDwordValueAt(root, allocator, uninstall_path, "NoModify", 1);
    try setDwordValueAt(root, allocator, uninstall_path, "NoRepair", 1);
    try setDwordValueAt(root, allocator, uninstall_path, "EstimatedSize", estimated_size_kb);
    try setDwordValueAt(root, allocator, uninstall_path, "RegistrationComplete", 1);
}

pub fn registeredExecutableIsCurrent(allocator: std.mem.Allocator, root: windows.HKEY, exe_path: []const u8, version: []const u8) Error!bool {
    const expected_command = std.fmt.allocPrint(allocator, "\"{s}\" --uninstall", .{exe_path}) catch return error.RegistryOpenFailed;
    defer allocator.free(expected_command);
    const stored_version = (try readStringValueAt(root, allocator, uninstall_path, "DisplayVersion")) orelse return false;
    defer allocator.free(stored_version);
    const stored_command = (try readStringValueAt(root, allocator, uninstall_path, "UninstallString")) orelse return false;
    defer allocator.free(stored_command);
    const quiet_command = try readStringValueAt(root, allocator, uninstall_path, "QuietUninstallString");
    if (quiet_command) |value| allocator.free(value);
    const complete = (try readDwordValueAt(root, allocator, uninstall_path, "RegistrationComplete")) orelse return false;
    return complete == 1 and quiet_command == null and std.mem.eql(u8, stored_version, version) and std.mem.eql(u8, stored_command, expected_command);
}

pub fn uninstall(allocator: std.mem.Allocator) Error!void {
    try uninstallAtRoot(allocator, windows.HKEY_CURRENT_USER);

    notifyAssociationChanged();
}

pub fn uninstallAtRoot(allocator: std.mem.Allocator, root: windows.HKEY) Error!void {
    try deleteValueIfPresentAt(root, allocator, "Software\\RegisteredApplications", "zmd");
    try deleteValueIfPresentAt(root, allocator, "Software\\Classes\\.md\\OpenWithProgids", "zmd.Markdown");
    try deleteTreeIfPresentAt(root, allocator, "Software\\Classes\\Applications\\zmd.exe");
    try deleteTreeIfPresentAt(root, allocator, "Software\\Classes\\zmd.Markdown");
    try deleteTreeIfPresentAt(root, allocator, "Software\\zmd\\Capabilities");
}

pub fn uninstallApplicationAtRoot(allocator: std.mem.Allocator, root: windows.HKEY) Error!void {
    try uninstallAtRoot(allocator, root);
    try deleteTreeIfPresentAt(root, allocator, uninstall_path);
}

fn currentExePathW(allocator: std.mem.Allocator) Error![:0]u16 {
    var capacity: DWORD = 260;
    while (capacity <= 32768) : (capacity *= 2) {
        const buffer = allocator.allocSentinel(u16, capacity, 0) catch return error.RegistryWriteFailed;
        const len = GetModuleFileNameW(null, buffer.ptr, capacity);
        if (len == 0) {
            allocator.free(buffer);
            return error.ExecutablePathUnavailable;
        }
        if (len < capacity - 1) {
            return buffer[0..len :0];
        }
        allocator.free(buffer);
    }
    return error.ExecutablePathTooLong;
}

fn quotedOpenCommand(allocator: std.mem.Allocator, exe_path: []const u16) Error![:0]u16 {
    var out: std.ArrayList(u16) = .empty;
    errdefer out.deinit(allocator);

    out.append(allocator, '"') catch return error.RegistryWriteFailed;
    out.appendSlice(allocator, exe_path) catch return error.RegistryWriteFailed;
    appendUtf8Literal(&out, allocator, "\" \"%1\"") catch return error.RegistryWriteFailed;

    return out.toOwnedSliceSentinel(allocator, 0) catch return error.RegistryWriteFailed;
}

fn executableIconValue(allocator: std.mem.Allocator, exe_path: []const u16) Error![:0]u16 {
    var out: std.ArrayList(u16) = .empty;
    errdefer out.deinit(allocator);

    out.append(allocator, '"') catch return error.RegistryWriteFailed;
    out.appendSlice(allocator, exe_path) catch return error.RegistryWriteFailed;
    appendUtf8Literal(&out, allocator, "\",0") catch return error.RegistryWriteFailed;

    return out.toOwnedSliceSentinel(allocator, 0) catch return error.RegistryWriteFailed;
}

fn appendUtf8Literal(out: *std.ArrayList(u16), allocator: std.mem.Allocator, comptime text: []const u8) std.mem.Allocator.Error!void {
    const wide = std.unicode.utf8ToUtf16LeStringLiteral(text);
    try out.appendSlice(allocator, wide[0..wide.len]);
}

fn setDefaultValue(allocator: std.mem.Allocator, subkey: []const u8, value: []const u8) Error!void {
    return setDefaultValueAt(windows.HKEY_CURRENT_USER, allocator, subkey, value);
}

fn setDefaultValueAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8, value: []const u8) Error!void {
    const value_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, value) catch return error.RegistryWriteFailed;
    defer allocator.free(value_w);
    try setDefaultValueWAt(root, allocator, subkey, value_w);
}

fn setDefaultValueW(allocator: std.mem.Allocator, subkey: []const u8, value: [:0]const u16) Error!void {
    try setDefaultValueWAt(windows.HKEY_CURRENT_USER, allocator, subkey, value);
}

fn setDefaultValueWAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8, value: [:0]const u16) Error!void {
    try setValueWAt(root, allocator, subkey, null, .SZ, @ptrCast(value.ptr), stringByteLen(value));
}

fn setStringValue(allocator: std.mem.Allocator, subkey: []const u8, name: []const u8, value: []const u8) Error!void {
    return setStringValueAt(windows.HKEY_CURRENT_USER, allocator, subkey, name, value);
}

fn setStringValueAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8, name: []const u8, value: []const u8) Error!void {
    const value_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, value) catch return error.RegistryWriteFailed;
    defer allocator.free(value_w);
    try setStringValueWAt(root, allocator, subkey, name, value_w);
}

fn setStringValueW(allocator: std.mem.Allocator, subkey: []const u8, name: []const u8, value: [:0]const u16) Error!void {
    return setStringValueWAt(windows.HKEY_CURRENT_USER, allocator, subkey, name, value);
}

fn setStringValueWAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8, name: []const u8, value: [:0]const u16) Error!void {
    const name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, name) catch return error.RegistryWriteFailed;
    defer allocator.free(name_w);
    try setValueWAt(root, allocator, subkey, name_w.ptr, .SZ, @ptrCast(value.ptr), stringByteLen(value));
}

fn setEmptyValue(allocator: std.mem.Allocator, subkey: []const u8, name: []const u8, value_type: windows.REG.ValueType) Error!void {
    return setEmptyValueAt(windows.HKEY_CURRENT_USER, allocator, subkey, name, value_type);
}

fn setEmptyValueAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8, name: []const u8, value_type: windows.REG.ValueType) Error!void {
    const name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, name) catch return error.RegistryWriteFailed;
    defer allocator.free(name_w);
    try setValueWAt(root, allocator, subkey, name_w.ptr, value_type, null, 0);
}

fn setDwordValueAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8, name: []const u8, value: DWORD) Error!void {
    const name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, name) catch return error.RegistryWriteFailed;
    defer allocator.free(name_w);
    var stored = value;
    try setValueWAt(root, allocator, subkey, name_w.ptr, .DWORD, @ptrCast(&stored), @sizeOf(DWORD));
}

fn setValueW(
    allocator: std.mem.Allocator,
    subkey: []const u8,
    name: ?LPCWSTR,
    value_type: windows.REG.ValueType,
    data: ?[*]const u8,
    data_len: DWORD,
) Error!void {
    return setValueWAt(windows.HKEY_CURRENT_USER, allocator, subkey, name, value_type, data, data_len);
}

fn setValueWAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8, name: ?LPCWSTR, value_type: windows.REG.ValueType, data: ?[*]const u8, data_len: DWORD) Error!void {
    const key = try createKeyAt(root, allocator, subkey);
    defer _ = RegCloseKey(key);

    if (RegSetValueExW(key, name, 0, value_type, data, data_len) != error_success) {
        return error.RegistryWriteFailed;
    }
}

fn createKey(allocator: std.mem.Allocator, subkey: []const u8) Error!windows.HKEY {
    return createKeyAt(windows.HKEY_CURRENT_USER, allocator, subkey);
}

fn createKeyAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8) Error!windows.HKEY {
    const scoped = try testScopedSubkey(allocator, root, subkey);
    defer if (scoped) |value| allocator.free(value);
    const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, scoped orelse subkey) catch return error.RegistryOpenFailed;
    defer allocator.free(subkey_w);

    var key: windows.HKEY = undefined;
    const status = RegCreateKeyExW(
        root,
        subkey_w.ptr,
        0,
        null,
        reg_option_non_volatile,
        key_write,
        null,
        &key,
        null,
    );
    if (status != error_success) return error.RegistryOpenFailed;
    return key;
}

fn openKeyForWrite(allocator: std.mem.Allocator, subkey: []const u8) Error!?windows.HKEY {
    return openKeyForWriteAt(windows.HKEY_CURRENT_USER, allocator, subkey);
}

fn openKeyForWriteAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8) Error!?windows.HKEY {
    const scoped = try testScopedSubkey(allocator, root, subkey);
    defer if (scoped) |value| allocator.free(value);
    const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, scoped orelse subkey) catch return error.RegistryOpenFailed;
    defer allocator.free(subkey_w);

    var key: windows.HKEY = undefined;
    const status = RegOpenKeyExW(root, subkey_w.ptr, 0, key_write, &key);
    return switch (status) {
        error_success => key,
        error_file_not_found, error_path_not_found => null,
        else => error.RegistryOpenFailed,
    };
}

fn readStringValueAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8, name: []const u8) Error!?[]u8 {
    const scoped = try testScopedSubkey(allocator, root, subkey);
    defer if (scoped) |value| allocator.free(value);
    const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, scoped orelse subkey) catch return error.RegistryOpenFailed;
    defer allocator.free(subkey_w);
    var key: windows.HKEY = undefined;
    const open_status = RegOpenKeyExW(root, subkey_w.ptr, 0, key_read, &key);
    if (open_status == error_file_not_found or open_status == error_path_not_found) return null;
    if (open_status != error_success) return error.RegistryOpenFailed;
    defer _ = RegCloseKey(key);
    const name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, name) catch return error.RegistryOpenFailed;
    defer allocator.free(name_w);
    var value_type: DWORD = 0;
    var byte_count: DWORD = 0;
    const size_status = RegQueryValueExW(key, name_w.ptr, null, &value_type, null, &byte_count);
    if (size_status == error_file_not_found or size_status == error_path_not_found) return null;
    if (size_status != error_success or value_type != @intFromEnum(windows.REG.ValueType.SZ) or byte_count < 2 or byte_count % 2 != 0) return error.RegistryOpenFailed;
    const wide = allocator.alloc(u16, byte_count / 2) catch return error.RegistryOpenFailed;
    defer allocator.free(wide);
    var loaded = byte_count;
    if (RegQueryValueExW(key, name_w.ptr, null, &value_type, @ptrCast(wide.ptr), &loaded) != error_success) return error.RegistryOpenFailed;
    const units = std.mem.sliceTo(wide, 0);
    return std.unicode.wtf16LeToWtf8Alloc(allocator, units) catch return error.RegistryOpenFailed;
}

fn readDwordValueAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8, name: []const u8) Error!?DWORD {
    const scoped = try testScopedSubkey(allocator, root, subkey);
    defer if (scoped) |value| allocator.free(value);
    const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, scoped orelse subkey) catch return error.RegistryOpenFailed;
    defer allocator.free(subkey_w);
    var key: windows.HKEY = undefined;
    const open_status = RegOpenKeyExW(root, subkey_w.ptr, 0, key_read, &key);
    if (open_status == error_file_not_found or open_status == error_path_not_found) return null;
    if (open_status != error_success) return error.RegistryOpenFailed;
    defer _ = RegCloseKey(key);
    const name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, name) catch return error.RegistryOpenFailed;
    defer allocator.free(name_w);
    var value_type: DWORD = 0;
    var value: DWORD = 0;
    var byte_count: DWORD = @sizeOf(DWORD);
    const status = RegQueryValueExW(key, name_w.ptr, null, &value_type, @ptrCast(&value), &byte_count);
    if (status == error_file_not_found or status == error_path_not_found) return null;
    if (status != error_success or value_type != @intFromEnum(windows.REG.ValueType.DWORD) or byte_count != @sizeOf(DWORD)) return error.RegistryOpenFailed;
    return value;
}

fn deleteValueIfPresent(allocator: std.mem.Allocator, subkey: []const u8, name: []const u8) Error!void {
    return deleteValueIfPresentAt(windows.HKEY_CURRENT_USER, allocator, subkey, name);
}

fn deleteValueIfPresentAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8, name: []const u8) Error!void {
    const key = (try openKeyForWriteAt(root, allocator, subkey)) orelse return;
    defer _ = RegCloseKey(key);

    const name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, name) catch return error.RegistryDeleteFailed;
    defer allocator.free(name_w);

    const status = RegDeleteValueW(key, name_w.ptr);
    switch (status) {
        error_success, error_file_not_found, error_path_not_found => {},
        else => return error.RegistryDeleteFailed,
    }
}

fn deleteTreeIfPresent(allocator: std.mem.Allocator, subkey: []const u8) Error!void {
    return deleteTreeIfPresentAt(windows.HKEY_CURRENT_USER, allocator, subkey);
}

fn deleteTreeIfPresentAt(root: windows.HKEY, allocator: std.mem.Allocator, subkey: []const u8) Error!void {
    const scoped = testScopedSubkey(allocator, root, subkey) catch return error.RegistryDeleteFailed;
    defer if (scoped) |value| allocator.free(value);
    const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, scoped orelse subkey) catch return error.RegistryDeleteFailed;
    defer allocator.free(subkey_w);

    const status = RegDeleteTreeW(root, subkey_w.ptr);
    switch (status) {
        error_success, error_file_not_found, error_path_not_found => {},
        else => return error.RegistryDeleteFailed,
    }
}

fn testScopedSubkey(allocator: std.mem.Allocator, root: windows.HKEY, subkey: []const u8) Error!?[]u8 {
    const allowed_prefix = build_options.test_registry_prefix orelse return null;
    if (root != windows.HKEY_CURRENT_USER) return null;
    const env_name = std.unicode.utf8ToUtf16LeStringLiteral("ZMD_TEST_REGISTRY_PREFIX");
    const needed = GetEnvironmentVariableW(env_name.ptr, null, 0);
    if (needed <= 1 or needed > 32768) return error.RegistryOpenFailed;
    const prefix_w = allocator.allocSentinel(u16, needed, 0) catch return error.RegistryOpenFailed;
    defer allocator.free(prefix_w);
    const loaded = GetEnvironmentVariableW(env_name.ptr, prefix_w.ptr, needed);
    if (loaded == 0 or loaded >= needed) return error.RegistryOpenFailed;
    const prefix = std.unicode.wtf16LeToWtf8Alloc(allocator, prefix_w[0..loaded]) catch return error.RegistryOpenFailed;
    defer allocator.free(prefix);
    if (!std.mem.startsWith(u8, allowed_prefix, "Software\\zmd-uninstall-e2e-") or
        prefix.len <= allowed_prefix.len + 1 or
        !std.mem.startsWith(u8, prefix, allowed_prefix) or
        prefix[allowed_prefix.len] != '-') return error.RegistryOpenFailed;
    return std.fmt.allocPrint(allocator, "{s}\\{s}", .{ prefix, subkey }) catch return error.RegistryOpenFailed;
}

fn stringByteLen(value: [:0]const u16) DWORD {
    return @intCast((value.len + 1) * @sizeOf(u16));
}

pub fn notifyAssociationChanged() void {
    SHChangeNotify(shcne_assocchanged, shcnf_idlist, null, null);
}

test "builds quoted open command" {
    const exe_path = std.unicode.utf8ToUtf16LeStringLiteral("C:\\Tools\\zmd.exe");
    const command = try quotedOpenCommand(std.testing.allocator, exe_path[0..exe_path.len]);
    defer std.testing.allocator.free(command);

    const expected = std.unicode.utf8ToUtf16LeStringLiteral("\"C:\\Tools\\zmd.exe\" \"%1\"");
    try std.testing.expectEqualSlices(u16, expected[0..expected.len], command[0..command.len]);
}

test "builds executable icon value" {
    const exe_path = std.unicode.utf8ToUtf16LeStringLiteral("C:\\Tools\\zmd.exe");
    const icon = try executableIconValue(std.testing.allocator, exe_path[0..exe_path.len]);
    defer std.testing.allocator.free(icon);

    const expected = std.unicode.utf8ToUtf16LeStringLiteral("\"C:\\Tools\\zmd.exe\",0");
    try std.testing.expectEqualSlices(u16, expected[0..expected.len], icon[0..icon.len]);
}
