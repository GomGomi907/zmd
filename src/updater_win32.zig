const std = @import("std");
const Io = std.Io;
const updater = @import("updater.zig");

const DWORD = u32;
const BOOL = i32;
const HANDLE = *anyopaque;
const HINTERNET = *anyopaque;
const HKEY = *anyopaque;
const LPCWSTR = [*:0]const u16;
const LPWSTR = [*:0]u16;

extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) DWORD;
extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;
extern "kernel32" fn GetModuleFileNameW(module: ?HANDLE, filename: [*:0]u16, size: DWORD) callconv(.winapi) DWORD;
extern "kernel32" fn OpenProcess(access: DWORD, inherit: BOOL, process_id: DWORD) callconv(.winapi) ?HANDLE;
extern "kernel32" fn CreateMutexW(attributes: ?*anyopaque, initial_owner: BOOL, name: LPCWSTR) callconv(.winapi) ?HANDLE;
extern "kernel32" fn WaitForSingleObject(handle: HANDLE, milliseconds: DWORD) callconv(.winapi) DWORD;
extern "kernel32" fn CloseHandle(handle: HANDLE) callconv(.winapi) BOOL;
extern "kernel32" fn ReleaseMutex(handle: HANDLE) callconv(.winapi) BOOL;
extern "kernel32" fn GetLastError() callconv(.winapi) DWORD;
extern "kernel32" fn MoveFileExW(existing: LPCWSTR, new: ?LPCWSTR, flags: DWORD) callconv(.winapi) BOOL;
extern "kernel32" fn ReplaceFileW(replaced: LPCWSTR, replacement: LPCWSTR, backup: ?LPCWSTR, flags: DWORD, exclude: ?*anyopaque, reserved: ?*anyopaque) callconv(.winapi) BOOL;
extern "kernel32" fn DeleteFileW(filename: LPCWSTR) callconv(.winapi) BOOL;
extern "kernel32" fn Sleep(milliseconds: DWORD) callconv(.winapi) void;
extern "winhttp" fn WinHttpOpen(user_agent: ?LPCWSTR, access_type: DWORD, proxy: ?LPCWSTR, proxy_bypass: ?LPCWSTR, flags: DWORD) callconv(.winapi) ?HINTERNET;
extern "winhttp" fn WinHttpConnect(session: HINTERNET, server_name: LPCWSTR, server_port: u16, reserved: DWORD) callconv(.winapi) ?HINTERNET;
extern "winhttp" fn WinHttpOpenRequest(connect: HINTERNET, verb: ?LPCWSTR, object_name: ?LPCWSTR, version: ?LPCWSTR, referrer: ?LPCWSTR, accept_types: ?[*:null]const ?LPCWSTR, flags: DWORD) callconv(.winapi) ?HINTERNET;
extern "winhttp" fn WinHttpSetTimeouts(handle: HINTERNET, resolve: c_int, connect: c_int, send: c_int, receive: c_int) callconv(.winapi) BOOL;
extern "winhttp" fn WinHttpSendRequest(request: HINTERNET, headers: ?LPCWSTR, headers_length: DWORD, optional: ?*anyopaque, optional_length: DWORD, total_length: DWORD, context: usize) callconv(.winapi) BOOL;
extern "winhttp" fn WinHttpReceiveResponse(request: HINTERNET, reserved: ?*anyopaque) callconv(.winapi) BOOL;
extern "winhttp" fn WinHttpQueryHeaders(request: HINTERNET, info_level: DWORD, name: ?LPCWSTR, buffer: ?*anyopaque, buffer_length: *DWORD, index: ?*DWORD) callconv(.winapi) BOOL;
extern "winhttp" fn WinHttpReadData(request: HINTERNET, buffer: [*]u8, bytes_to_read: DWORD, bytes_read: *DWORD) callconv(.winapi) BOOL;
extern "winhttp" fn WinHttpCloseHandle(handle: HINTERNET) callconv(.winapi) BOOL;
extern "winhttp" fn WinHttpCrackUrl(url: LPCWSTR, url_length: DWORD, flags: DWORD, components: *URL_COMPONENTS) callconv(.winapi) BOOL;
extern "advapi32" fn RegCreateKeyExW(key: HKEY, sub_key: LPCWSTR, reserved: DWORD, class: ?LPWSTR, options: DWORD, access: DWORD, security: ?*anyopaque, result: *HKEY, disposition: ?*DWORD) callconv(.winapi) c_long;
extern "advapi32" fn RegQueryValueExW(key: HKEY, value_name: LPCWSTR, reserved: ?*DWORD, value_type: ?*DWORD, data: ?[*]u8, data_size: ?*DWORD) callconv(.winapi) c_long;
extern "advapi32" fn RegSetValueExW(key: HKEY, value_name: LPCWSTR, reserved: DWORD, value_type: DWORD, data: [*]const u8, data_size: DWORD) callconv(.winapi) c_long;
extern "advapi32" fn RegDeleteValueW(key: HKEY, value_name: LPCWSTR) callconv(.winapi) c_long;
extern "advapi32" fn RegCloseKey(key: HKEY) callconv(.winapi) c_long;

const URL_COMPONENTS = extern struct {
    struct_size: DWORD,
    scheme: ?LPWSTR,
    scheme_length: DWORD,
    scheme_id: c_int,
    host: ?LPWSTR,
    host_length: DWORD,
    port: u16,
    user_name: ?LPWSTR,
    user_name_length: DWORD,
    password: ?LPWSTR,
    password_length: DWORD,
    url_path: ?LPWSTR,
    url_path_length: DWORD,
    extra_info: ?LPWSTR,
    extra_info_length: DWORD,
};

const synchronize: DWORD = 0x00100000;
const infinite: DWORD = 0xffffffff;
const wait_object_0: DWORD = 0;
const wait_abandoned: DWORD = 128;
const wait_timeout: DWORD = 258;
const parent_exit_timeout_ms: DWORD = 10_000;
const move_delay_until_reboot: DWORD = 0x00000004;
const network_timeout_ms: DWORD = 30_000;
const error_invalid_parameter: DWORD = 87;
var network_finished = std.atomic.Value(bool).init(false);
var watchdog_version_buffer: [128]u8 = undefined;
var watchdog_version_length: usize = 0;
const winhttp_access_type_automatic_proxy: DWORD = 4;
const winhttp_flag_secure: DWORD = 0x00800000;
const winhttp_query_status_code: DWORD = 19;
const winhttp_query_flag_number: DWORD = 0x20000000;
const internet_scheme_https: c_int = 2;
const winhttp_timeout_ms: c_int = 8_000;
const error_success: c_long = 0;
const error_file_not_found: c_long = 2;
const reg_option_volatile: DWORD = 1;
const key_query_value: DWORD = 1;
const key_set_value: DWORD = 2;
const reg_dword: DWORD = 4;

pub const apply_argument = "--apply-update";

pub fn claimUpdateOffer(allocator: std.mem.Allocator, version: []const u8) !bool {
    const version_hash = std.hash.Wyhash.hash(0, version);
    const name = try std.fmt.allocPrint(allocator, "Local\\zmd-update-offer-{x}", .{version_hash});
    defer allocator.free(name);
    const name_w = try std.unicode.utf8ToUtf16LeAllocZ(allocator, name);
    defer allocator.free(name_w);
    const handle = CreateMutexW(null, 0, name_w.ptr) orelse return error.UpdateOfferLockUnavailable;
    defer _ = CloseHandle(handle);
    switch (WaitForSingleObject(handle, 0)) {
        wait_object_0, wait_abandoned => {},
        wait_timeout => return false,
        else => return error.UpdateOfferLockFailed,
    }
    defer _ = ReleaseMutex(handle);

    const sub_key = std.unicode.utf8ToUtf16LeStringLiteral("Software\\GomGomi907\\zmd\\SessionUpdateOffers");
    const value_name = try std.unicode.utf8ToUtf16LeAllocZ(allocator, version);
    defer allocator.free(value_name);
    var key: HKEY = undefined;
    if (RegCreateKeyExW(hkeyCurrentUser(), sub_key.ptr, 0, null, reg_option_volatile, key_query_value | key_set_value, null, &key, null) != error_success) return error.UpdateOfferRegistryUnavailable;
    defer _ = RegCloseKey(key);
    var value_type: DWORD = 0;
    var value_size: DWORD = 0;
    const query_result = RegQueryValueExW(key, value_name.ptr, null, &value_type, null, &value_size);
    if (query_result == error_success) return false;
    if (query_result != error_file_not_found) return error.UpdateOfferRegistryUnavailable;
    var marker: DWORD = 1;
    if (RegSetValueExW(key, value_name.ptr, 0, reg_dword, @ptrCast(&marker), @sizeOf(DWORD)) != error_success) return error.UpdateOfferRegistryUnavailable;
    return true;
}

pub fn clearUpdateOfferClaim(allocator: std.mem.Allocator, version: []const u8) void {
    const sub_key = std.unicode.utf8ToUtf16LeStringLiteral("Software\\GomGomi907\\zmd\\SessionUpdateOffers");
    const value_name = std.unicode.utf8ToUtf16LeAllocZ(allocator, version) catch return;
    defer allocator.free(value_name);
    var key: HKEY = undefined;
    if (RegCreateKeyExW(hkeyCurrentUser(), sub_key.ptr, 0, null, reg_option_volatile, key_set_value, null, &key, null) != error_success) return;
    defer _ = RegCloseKey(key);
    _ = RegDeleteValueW(key, value_name.ptr);
}

fn hkeyCurrentUser() HKEY {
    const signed: i32 = @bitCast(@as(u32, 0x80000001));
    return @ptrFromInt(@as(usize, @bitCast(@as(isize, signed))));
}

pub fn checkLatest(allocator: std.mem.Allocator, current_version: []const u8) !?updater.AvailableUpdate {
    const metadata = try fetchWinHttp(allocator, updater.releases_url, 1024 * 1024);
    defer allocator.free(metadata);
    return updater.parseLatestRelease(allocator, metadata, current_version);
}

pub fn launchPreparedUpdate(
    allocator: std.mem.Allocator,
    io: Io,
    temp_dir: []const u8,
    target_executable: []const u8,
    kind: updater.InstallKind,
    update: updater.AvailableUpdate,
) !void {
    const process_id = GetCurrentProcessId();
    const pid = try std.fmt.allocPrint(allocator, "{}", .{process_id});
    defer allocator.free(pid);
    const helper_name = try std.fmt.allocPrint(allocator, "zmd-update-helper-{}.exe", .{process_id});
    defer allocator.free(helper_name);
    const helper_path = try std.fs.path.join(allocator, &.{ temp_dir, helper_name });
    defer allocator.free(helper_path);
    try Io.Dir.copyFileAbsolute(target_executable, helper_path, io, .{ .replace = true, .make_path = true });
    const kind_arg = @tagName(kind);
    _ = try std.process.spawn(io, .{
        .argv = &.{ helper_path, apply_argument, pid, target_executable, kind_arg, update.version, update.installer_url, update.checksum_url },
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
        .create_no_window = true,
    });
}

pub fn applyFromArguments(allocator: std.mem.Allocator, io: Io, args: []const []const u8) !bool {
    if (args.len != 8 or !std.mem.eql(u8, args[1], apply_argument)) return false;
    errdefer clearUpdateOfferClaim(allocator, args[5]);
    const parent_pid = try std.fmt.parseInt(DWORD, args[2], 10);
    _ = std.meta.stringToEnum(updater.InstallKind, args[4]) orelse return error.InvalidInstallKind;
    if (args[5].len > watchdog_version_buffer.len) return error.InvalidReleaseVersion;
    @memcpy(watchdog_version_buffer[0..args[5].len], args[5]);
    watchdog_version_length = args[5].len;
    network_finished.store(false, .release);
    errdefer network_finished.store(true, .release);
    const watchdog = try std.Thread.spawn(.{}, networkWatchdog, .{});
    watchdog.detach();
    const installer = try downloadVerified(allocator, args[6], args[7]);
    defer allocator.free(installer);
    network_finished.store(true, .release);
    try waitForProcess(parent_pid);
    const update_mutex_name = std.unicode.utf8ToUtf16LeStringLiteral("Local\\zmd-update-replace");
    const update_mutex = CreateMutexW(null, 0, update_mutex_name.ptr) orelse return error.UpdateLockUnavailable;
    defer _ = CloseHandle(update_mutex);
    switch (WaitForSingleObject(update_mutex, parent_exit_timeout_ms)) {
        wait_object_0, wait_abandoned => {},
        wait_timeout => return error.UpdateLockTimeout,
        else => return error.UpdateLockFailed,
    }
    defer _ = ReleaseMutex(update_mutex);
    try replaceBytesPreservingOld(allocator, io, installer, args[3]);
    scheduleSelfDelete(allocator);
    return true;
}

fn downloadVerified(allocator: std.mem.Allocator, installer_url: []const u8, checksum_url: []const u8) ![]u8 {
    const installer = try fetchWinHttp(allocator, installer_url, 16 * 1024 * 1024);
    errdefer allocator.free(installer);
    const checksum = try fetchWinHttp(allocator, checksum_url, 4096);
    defer allocator.free(checksum);
    try updater.verifyChecksum(installer, checksum);
    return installer;
}

fn fetchWinHttp(allocator: std.mem.Allocator, url: []const u8, maximum: usize) ![]u8 {
    const agent = std.unicode.utf8ToUtf16LeStringLiteral("zmd-updater/1");
    const get = std.unicode.utf8ToUtf16LeStringLiteral("GET");
    const session = WinHttpOpen(agent.ptr, winhttp_access_type_automatic_proxy, null, null, 0) orelse return error.UpdateNetworkUnavailable;
    defer _ = WinHttpCloseHandle(session);

    const url_w = try std.unicode.utf8ToUtf16LeAllocZ(allocator, url);
    defer allocator.free(url_w);
    var components = URL_COMPONENTS{
        .struct_size = @sizeOf(URL_COMPONENTS),
        .scheme = null,
        .scheme_length = std.math.maxInt(DWORD),
        .scheme_id = 0,
        .host = null,
        .host_length = std.math.maxInt(DWORD),
        .port = 0,
        .user_name = null,
        .user_name_length = 0,
        .password = null,
        .password_length = 0,
        .url_path = null,
        .url_path_length = std.math.maxInt(DWORD),
        .extra_info = null,
        .extra_info_length = std.math.maxInt(DWORD),
    };
    if (WinHttpCrackUrl(url_w.ptr, @intCast(url_w.len), 0, &components) == 0) return error.InvalidUpdateUrl;
    if (components.scheme_id != internet_scheme_https) return error.InsecureUpdateUrl;
    const host = components.host orelse return error.InvalidUpdateUrl;
    const host_z = try allocator.allocSentinel(u16, components.host_length, 0);
    defer allocator.free(host_z);
    @memcpy(host_z, host[0..components.host_length]);

    const path = components.url_path orelse return error.InvalidUpdateUrl;
    const object_length: usize = @as(usize, components.url_path_length) + components.extra_info_length;
    const object_z = try allocator.allocSentinel(u16, object_length, 0);
    defer allocator.free(object_z);
    @memcpy(object_z, path[0..object_length]);

    const connection = WinHttpConnect(session, host_z.ptr, components.port, 0) orelse return error.UpdateNetworkUnavailable;
    defer _ = WinHttpCloseHandle(connection);
    const request = WinHttpOpenRequest(
        connection,
        get.ptr,
        object_z.ptr,
        null,
        null,
        null,
        winhttp_flag_secure,
    ) orelse return error.UpdateNetworkUnavailable;
    defer _ = WinHttpCloseHandle(request);
    if (WinHttpSetTimeouts(request, winhttp_timeout_ms, winhttp_timeout_ms, winhttp_timeout_ms, winhttp_timeout_ms) == 0) return error.UpdateNetworkUnavailable;
    if (WinHttpSendRequest(request, null, 0, null, 0, 0, 0) == 0) return error.UpdateNetworkUnavailable;
    if (WinHttpReceiveResponse(request, null) == 0) return error.UpdateNetworkUnavailable;
    var status: DWORD = 0;
    var status_size: DWORD = @sizeOf(DWORD);
    if (WinHttpQueryHeaders(request, winhttp_query_status_code | winhttp_query_flag_number, null, &status, &status_size, null) == 0) return error.UpdateNetworkUnavailable;
    if (status != 200) return error.UpdateServerRejectedRequest;

    const buffer = try allocator.alloc(u8, maximum);
    errdefer allocator.free(buffer);
    var used: usize = 0;
    while (used < buffer.len) {
        var read: DWORD = 0;
        if (WinHttpReadData(request, buffer.ptr + used, @intCast(@min(buffer.len - used, std.math.maxInt(DWORD))), &read) == 0) return error.UpdateNetworkUnavailable;
        if (read == 0) return allocator.realloc(buffer, used);
        used += read;
    }
    return error.UpdateResponseTooLarge;
}

fn networkWatchdog() void {
    Sleep(network_timeout_ms);
    if (!network_finished.load(.acquire)) {
        clearUpdateOfferClaim(std.heap.page_allocator, watchdog_version_buffer[0..watchdog_version_length]);
        std.process.exit(2);
    }
}

pub fn currentExePath(allocator: std.mem.Allocator) ![]u8 {
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

pub fn waitForProcess(process_id: DWORD) !void {
    const process = OpenProcess(synchronize, 0, process_id) orelse {
        if (GetLastError() == error_invalid_parameter) return;
        return error.ParentProcessUnavailable;
    };
    defer _ = CloseHandle(process);
    switch (WaitForSingleObject(process, parent_exit_timeout_ms)) {
        wait_object_0 => {},
        wait_timeout => return error.ParentProcessStillRunning,
        else => return error.ParentProcessWaitFailed,
    }
}

pub fn replacePreservingOld(allocator: std.mem.Allocator, io: Io, source: []const u8, target: []const u8) !void {
    const data = try Io.Dir.cwd().readFileAlloc(io, source, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(data);
    try replaceBytesPreservingOld(allocator, io, data, target);
}

fn replaceBytesPreservingOld(allocator: std.mem.Allocator, io: Io, data: []const u8, target: []const u8) !void {
    const process_id = GetCurrentProcessId();
    const pending = try std.fmt.allocPrint(allocator, "{s}.update-new-{}", .{ target, process_id });
    defer allocator.free(pending);
    const backup = try std.fmt.allocPrint(allocator, "{s}.update-backup-{}", .{ target, process_id });
    defer allocator.free(backup);

    try Io.Dir.cwd().writeFile(io, .{ .sub_path = pending, .data = data });
    errdefer deleteFile(pending);

    const written = try Io.Dir.cwd().readFileAlloc(io, pending, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(written);
    if (!std.mem.eql(u8, data, written)) return error.StagedUpdateChanged;
    try atomicReplace(allocator, target, pending, backup);
    deleteFile(backup);
}

fn scheduleSelfDelete(allocator: std.mem.Allocator) void {
    const path = currentExePath(allocator) catch return;
    defer allocator.free(path);
    const path_w = std.unicode.wtf8ToWtf16LeAllocZ(allocator, path) catch return;
    defer allocator.free(path_w);
    _ = MoveFileExW(path_w.ptr, null, move_delay_until_reboot);
}

fn atomicReplace(allocator: std.mem.Allocator, target: []const u8, replacement: []const u8, backup: []const u8) !void {
    const target_w = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, target);
    defer allocator.free(target_w);
    const replacement_w = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, replacement);
    defer allocator.free(replacement_w);
    const backup_w = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, backup);
    defer allocator.free(backup_w);
    if (ReplaceFileW(target_w.ptr, replacement_w.ptr, backup_w.ptr, 0, null, null) == 0) return error.UpdateReplaceFailed;
}

fn deleteFile(path: []const u8) void {
    var buffer: [std.fs.max_path_bytes + 1]u16 = undefined;
    const path_w_len = std.unicode.wtf8ToWtf16Le(&buffer, path) catch return;
    buffer[path_w_len] = 0;
    _ = DeleteFileW(@ptrCast(&buffer));
}

test "apply mode is opt-in and validates its shape" {
    const normal = [_][]const u8{ "zmd.exe", "document.md" };
    try std.testing.expect(!(try applyFromArguments(std.testing.allocator, std.testing.io, &normal)));
    const malformed = [_][]const u8{ "zmd-update.exe", apply_argument, "12", "target.exe", "unknown", "0.3.0", "https://example.test/x", "https://example.test/y" };
    try std.testing.expectError(error.InvalidInstallKind, applyFromArguments(std.testing.allocator, std.testing.io, &malformed));
}

test "claims an update offer once per logon session and version" {
    const version = try std.fmt.allocPrint(std.testing.allocator, "test-{}-{}", .{ GetCurrentProcessId(), GetTickCount64() });
    defer std.testing.allocator.free(version);
    defer clearUpdateOfferClaim(std.testing.allocator, version);
    try std.testing.expect(try claimUpdateOffer(std.testing.allocator, version));
    try std.testing.expect(!(try claimUpdateOffer(std.testing.allocator, version)));
}

test "failed update permits the same version to be offered again" {
    const version = try std.fmt.allocPrint(std.testing.allocator, "failure-test-{}-{}", .{ GetCurrentProcessId(), GetTickCount64() });
    defer std.testing.allocator.free(version);
    defer clearUpdateOfferClaim(std.testing.allocator, version);
    try std.testing.expect(try claimUpdateOffer(std.testing.allocator, version));
    const args = [_][]const u8{ "helper.exe", apply_argument, "1", "unused.exe", "portable", version, "http://example.invalid/file", "https://example.invalid/hash" };
    try std.testing.expectError(error.InsecureUpdateUrl, applyFromArguments(std.testing.allocator, std.testing.io, &args));
    try std.testing.expect(try claimUpdateOffer(std.testing.allocator, version));
}

test "replacement keeps a byte-identical new target" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const source = try tmp.dir.realPathFileAlloc(std.testing.io, ".", std.testing.allocator);
    defer std.testing.allocator.free(source);
    const source_path = try std.fs.path.join(std.testing.allocator, &.{ source, "source.exe" });
    defer std.testing.allocator.free(source_path);
    const target_path = try std.fs.path.join(std.testing.allocator, &.{ source, "target.exe" });
    defer std.testing.allocator.free(target_path);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "source.exe", .data = "new executable" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "target.exe", .data = "old executable" });

    try replacePreservingOld(std.testing.allocator, std.testing.io, source_path, target_path);
    const contents = try Io.Dir.cwd().readFileAlloc(std.testing.io, target_path, std.testing.allocator, .limited(1024));
    defer std.testing.allocator.free(contents);
    try std.testing.expectEqualStrings("new executable", contents);
}
