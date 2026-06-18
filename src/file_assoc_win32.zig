const std = @import("std");
const windows = std.os.windows;
const Error = @import("file_assoc.zig").Error;

const DWORD = u32;
const UINT = u32;
const ULONG = u32;
const LPCWSTR = [*:0]const u16;
const LPWSTR = [*:0]u16;

extern "kernel32" fn GetModuleFileNameW(hModule: ?*anyopaque, lpFilename: LPWSTR, nSize: DWORD) callconv(.winapi) DWORD;
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
extern "advapi32" fn RegDeleteTreeW(hKey: windows.HKEY, lpSubKey: LPCWSTR) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegDeleteValueW(hKey: windows.HKEY, lpValueName: LPCWSTR) callconv(.winapi) windows.LSTATUS;
extern "advapi32" fn RegCloseKey(hKey: windows.HKEY) callconv(.winapi) windows.LSTATUS;
extern "shell32" fn SHChangeNotify(wEventId: c_long, uFlags: UINT, dwItem1: ?*const anyopaque, dwItem2: ?*const anyopaque) callconv(.winapi) void;

const reg_option_non_volatile: DWORD = 0;
const error_success: windows.LSTATUS = 0;
const error_file_not_found: windows.LSTATUS = 2;
const error_path_not_found: windows.LSTATUS = 3;
const key_write: windows.REGSAM = windows.ACCESS_MASK.Specific.Key.WRITE;
const shcne_assocchanged: c_long = 0x08000000;
const shcnf_idlist: UINT = 0x0000;

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
    const command = try quotedOpenCommand(allocator, exe_path);
    defer allocator.free(command);

    const icon = try executableIconValue(allocator, exe_path);
    defer allocator.free(icon);

    try setDefaultValue(allocator, "Software\\Classes\\zmd.Markdown", "zmd Markdown Document");
    try setStringValue(allocator, "Software\\Classes\\zmd.Markdown", "FriendlyTypeName", "zmd Markdown Document");
    try setStringValue(allocator, "Software\\Classes\\zmd.Markdown", "PerceivedType", "text");
    try setStringValue(allocator, "Software\\Classes\\zmd.Markdown", "Content Type", "text/markdown");
    try setDefaultValueW(allocator, "Software\\Classes\\zmd.Markdown\\DefaultIcon", icon);
    try setDefaultValue(allocator, "Software\\Classes\\zmd.Markdown\\shell\\open", "Open with zmd");
    try setDefaultValueW(allocator, "Software\\Classes\\zmd.Markdown\\shell\\open\\command", command);

    try setEmptyValue(allocator, "Software\\Classes\\.md\\OpenWithProgids", "zmd.Markdown", .NONE);

    try setStringValue(allocator, "Software\\Classes\\Applications\\zmd.exe", "FriendlyAppName", "zmd");
    try setDefaultValueW(allocator, "Software\\Classes\\Applications\\zmd.exe\\DefaultIcon", icon);
    try setDefaultValueW(allocator, "Software\\Classes\\Applications\\zmd.exe\\shell\\open\\command", command);
    try setEmptyValue(allocator, "Software\\Classes\\Applications\\zmd.exe\\SupportedTypes", ".md", .NONE);

    try setStringValue(allocator, "Software\\zmd\\Capabilities", "ApplicationName", "zmd");
    try setStringValue(allocator, "Software\\zmd\\Capabilities", "ApplicationDescription", "Tiny Markdown viewer");
    try setStringValue(allocator, "Software\\zmd\\Capabilities\\FileAssociations", ".md", "zmd.Markdown");
    try setStringValue(allocator, "Software\\RegisteredApplications", "zmd", "Software\\zmd\\Capabilities");

    notifyAssociationChanged();
}

pub fn uninstall(allocator: std.mem.Allocator) Error!void {
    try deleteValueIfPresent(allocator, "Software\\RegisteredApplications", "zmd");
    try deleteValueIfPresent(allocator, "Software\\Classes\\.md\\OpenWithProgids", "zmd.Markdown");
    try deleteTreeIfPresent(allocator, "Software\\Classes\\Applications\\zmd.exe");
    try deleteTreeIfPresent(allocator, "Software\\Classes\\zmd.Markdown");
    try deleteTreeIfPresent(allocator, "Software\\zmd");

    notifyAssociationChanged();
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
    const value_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, value) catch return error.RegistryWriteFailed;
    defer allocator.free(value_w);
    try setDefaultValueW(allocator, subkey, value_w);
}

fn setDefaultValueW(allocator: std.mem.Allocator, subkey: []const u8, value: [:0]const u16) Error!void {
    try setValueW(allocator, subkey, null, .SZ, @ptrCast(value.ptr), stringByteLen(value));
}

fn setStringValue(allocator: std.mem.Allocator, subkey: []const u8, name: []const u8, value: []const u8) Error!void {
    const value_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, value) catch return error.RegistryWriteFailed;
    defer allocator.free(value_w);
    try setStringValueW(allocator, subkey, name, value_w);
}

fn setStringValueW(allocator: std.mem.Allocator, subkey: []const u8, name: []const u8, value: [:0]const u16) Error!void {
    const name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, name) catch return error.RegistryWriteFailed;
    defer allocator.free(name_w);
    try setValueW(allocator, subkey, name_w.ptr, .SZ, @ptrCast(value.ptr), stringByteLen(value));
}

fn setEmptyValue(allocator: std.mem.Allocator, subkey: []const u8, name: []const u8, value_type: windows.REG.ValueType) Error!void {
    const name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, name) catch return error.RegistryWriteFailed;
    defer allocator.free(name_w);
    try setValueW(allocator, subkey, name_w.ptr, value_type, null, 0);
}

fn setValueW(
    allocator: std.mem.Allocator,
    subkey: []const u8,
    name: ?LPCWSTR,
    value_type: windows.REG.ValueType,
    data: ?[*]const u8,
    data_len: DWORD,
) Error!void {
    const key = try createKey(allocator, subkey);
    defer _ = RegCloseKey(key);

    if (RegSetValueExW(key, name, 0, value_type, data, data_len) != error_success) {
        return error.RegistryWriteFailed;
    }
}

fn createKey(allocator: std.mem.Allocator, subkey: []const u8) Error!windows.HKEY {
    const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, subkey) catch return error.RegistryOpenFailed;
    defer allocator.free(subkey_w);

    var key: windows.HKEY = undefined;
    const status = RegCreateKeyExW(
        windows.HKEY_CURRENT_USER,
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
    const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, subkey) catch return error.RegistryOpenFailed;
    defer allocator.free(subkey_w);

    var key: windows.HKEY = undefined;
    const status = RegOpenKeyExW(windows.HKEY_CURRENT_USER, subkey_w.ptr, 0, key_write, &key);
    return switch (status) {
        error_success => key,
        error_file_not_found, error_path_not_found => null,
        else => error.RegistryOpenFailed,
    };
}

fn deleteValueIfPresent(allocator: std.mem.Allocator, subkey: []const u8, name: []const u8) Error!void {
    const key = (try openKeyForWrite(allocator, subkey)) orelse return;
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
    const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, subkey) catch return error.RegistryDeleteFailed;
    defer allocator.free(subkey_w);

    const status = RegDeleteTreeW(windows.HKEY_CURRENT_USER, subkey_w.ptr);
    switch (status) {
        error_success, error_file_not_found, error_path_not_found => {},
        else => return error.RegistryDeleteFailed,
    }
}

fn stringByteLen(value: [:0]const u16) DWORD {
    return @intCast((value.len + 1) * @sizeOf(u16));
}

fn notifyAssociationChanged() void {
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
