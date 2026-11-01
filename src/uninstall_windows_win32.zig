const std = @import("std");
const windows = std.os.windows;

const BOOL = windows.BOOL;
const DWORD = u32;
const HANDLE = windows.HANDLE;
const HWND = ?*anyopaque;
const LPARAM = isize;
const LRESULT = isize;
const UINT = u32;
const UINT_PTR = usize;
const WPARAM = usize;

const EnumWindowsProc = *const fn (HWND, LPARAM) callconv(.winapi) BOOL;

extern "user32" fn EnumWindows(callback: EnumWindowsProc, param: LPARAM) callconv(.winapi) BOOL;
extern "user32" fn GetClassNameW(hwnd: HWND, class_name: [*]u16, maximum: c_int) callconv(.winapi) c_int;
extern "user32" fn GetWindowThreadProcessId(hwnd: HWND, process_id: *DWORD) callconv(.winapi) DWORD;
extern "user32" fn RegisterWindowMessageW(name: [*:0]const u16) callconv(.winapi) UINT;
extern "user32" fn SendMessageTimeoutW(hwnd: HWND, message: UINT, wparam: WPARAM, lparam: LPARAM, flags: UINT, timeout: UINT, result: *UINT_PTR) callconv(.winapi) LRESULT;
extern "kernel32" fn OpenProcess(access: DWORD, inherit: BOOL, process_id: DWORD) callconv(.winapi) ?HANDLE;
extern "kernel32" fn QueryFullProcessImageNameW(process: HANDLE, flags: DWORD, path: [*]u16, path_length: *DWORD) callconv(.winapi) BOOL;
extern "kernel32" fn WaitForSingleObject(handle: HANDLE, milliseconds: DWORD) callconv(.winapi) DWORD;
extern "kernel32" fn CloseHandle(handle: HANDLE) callconv(.winapi) BOOL;
extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;
extern "kernel32" fn GetLastError() callconv(.winapi) DWORD;
extern "kernel32" fn SetLastError(error_code: DWORD) callconv(.winapi) void;
extern "kernel32" fn CompareStringOrdinal(left: [*]const u16, left_length: c_int, right: [*]const u16, right_length: c_int, ignore_case: BOOL) callconv(.winapi) c_int;

const process_query_limited_information: DWORD = 0x1000;
const synchronize: DWORD = 0x00100000;
const smto_block: UINT = 0x0001;
const smto_abort_if_hung: UINT = 0x0002;
const wait_object_0: DWORD = 0;
const wait_timeout: DWORD = 258;
const cstr_equal: c_int = 2;
const zmd_class = std.unicode.utf8ToUtf16LeStringLiteral("zmd_window");
const close_message_name = std.unicode.utf8ToUtf16LeStringLiteral("zmd.uninstall.close.v1");

const TargetWindow = struct {
    hwnd: HWND,
    process_id: DWORD,
};

const TargetProcess = struct {
    process_id: DWORD,
    handle: HANDLE,
};

const Enumeration = struct {
    allocator: std.mem.Allocator,
    expected_path: []const u16,
    windows: std.ArrayList(TargetWindow) = .empty,
    processes: std.ArrayList(TargetProcess) = .empty,
    failure: ?anyerror = null,
    callback_called: bool = false,

    fn deinit(self: *Enumeration) void {
        for (self.processes.items) |process| _ = CloseHandle(process.handle);
        self.processes.deinit(self.allocator);
        self.windows.deinit(self.allocator);
    }
};

pub fn closeMessage() UINT {
    return RegisterWindowMessageW(close_message_name.ptr);
}

pub fn pathsEqual(allocator: std.mem.Allocator, left: []const u8, right: []const u8) !bool {
    const left_w = try std.unicode.wtf8ToWtf16LeAlloc(allocator, left);
    defer allocator.free(left_w);
    const right_w = try std.unicode.wtf8ToWtf16LeAlloc(allocator, right);
    defer allocator.free(right_w);
    return windowsPathEql(left_w, right_w);
}

/// Requests a normal exit from every zmd top-level window whose owning process
/// is the exact installed executable. Portable copies and unrelated windows are
/// ignored. Process handles stay open until exit so a recycled PID cannot be
/// mistaken for the original target.
pub fn closeInstalledWindows(allocator: std.mem.Allocator, installed_exe: []const u8, timeout_ms: u32) !void {
    const expected_path = try std.unicode.wtf8ToWtf16LeAlloc(allocator, installed_exe);
    defer allocator.free(expected_path);

    var enumeration = Enumeration{ .allocator = allocator, .expected_path = expected_path };
    defer enumeration.deinit();
    SetLastError(0);
    const enumerated = EnumWindows(enumerateWindow, @bitCast(@intFromPtr(&enumeration)));
    try checkEnumeration(enumerated, enumeration.failure, GetLastError(), enumeration.callback_called);
    if (enumeration.windows.items.len == 0) return;

    const message = closeMessage();
    if (message == 0) return error.CloseMessageUnavailable;
    const deadline = GetTickCount64() + timeout_ms;

    for (enumeration.windows.items) |target| {
        const remaining = remainingTimeout(deadline) orelse return error.WindowCloseTimeout;
        var current_process_id: DWORD = 0;
        if (!isZmdWindow(target.hwnd) or
            GetWindowThreadProcessId(target.hwnd, &current_process_id) == 0 or
            current_process_id != target.process_id)
        {
            if (processExited(enumeration.processes.items, target.process_id)) continue;
            return error.WindowIdentityChanged;
        }
        var ignored: UINT_PTR = 0;
        if (SendMessageTimeoutW(
            target.hwnd,
            message,
            0,
            0,
            smto_block | smto_abort_if_hung,
            remaining,
            &ignored,
        ) == 0) {
            if (processExited(enumeration.processes.items, target.process_id)) continue;
            return error.WindowCloseRequestFailed;
        }
    }

    for (enumeration.processes.items) |process| {
        const remaining = remainingTimeout(deadline) orelse return error.WindowCloseTimeout;
        switch (WaitForSingleObject(process.handle, remaining)) {
            wait_object_0 => {},
            wait_timeout => return error.WindowCloseTimeout,
            else => return error.WindowCloseWaitFailed,
        }
    }
}

fn checkEnumeration(result: BOOL, callback_failure: ?anyerror, last_error: DWORD, callback_called: bool) !void {
    if (result.toBool()) return;
    if (callback_failure) |failure| return failure;
    if (last_error == 0 and !callback_called) return;
    return error.WindowEnumerationFailed;
}

fn enumerateWindow(hwnd: HWND, param: LPARAM) callconv(.winapi) BOOL {
    const enumeration: *Enumeration = @ptrFromInt(@as(usize, @bitCast(param)));
    enumeration.callback_called = true;
    if (!isZmdWindow(hwnd)) return .TRUE;

    var process_id: DWORD = 0;
    if (GetWindowThreadProcessId(hwnd, &process_id) == 0 or process_id == 0) return .TRUE;
    const process = OpenProcess(process_query_limited_information | synchronize, .FALSE, process_id) orelse return .TRUE;

    var path_buffer: [32768]u16 = undefined;
    var path_length: DWORD = path_buffer.len;
    if (!QueryFullProcessImageNameW(process, 0, &path_buffer, &path_length).toBool()) {
        _ = CloseHandle(process);
        return .TRUE;
    }
    if (!windowsPathEql(path_buffer[0..path_length], enumeration.expected_path)) {
        _ = CloseHandle(process);
        return .TRUE;
    }

    const process_index = findProcess(enumeration.processes.items, process_id);
    if (process_index == null) {
        enumeration.processes.append(enumeration.allocator, .{ .process_id = process_id, .handle = process }) catch {
            _ = CloseHandle(process);
            enumeration.failure = error.OutOfMemory;
            return .FALSE;
        };
    } else {
        _ = CloseHandle(process);
    }
    enumeration.windows.append(enumeration.allocator, .{ .hwnd = hwnd, .process_id = process_id }) catch {
        enumeration.failure = error.OutOfMemory;
        return .FALSE;
    };
    return .TRUE;
}

fn isZmdWindow(hwnd: HWND) bool {
    var class_name: [64]u16 = undefined;
    const length = GetClassNameW(hwnd, &class_name, class_name.len);
    return length == zmd_class.len and std.mem.eql(u16, class_name[0..@intCast(length)], zmd_class);
}

fn findProcess(processes: []const TargetProcess, process_id: DWORD) ?usize {
    for (processes, 0..) |process, index| if (process.process_id == process_id) return index;
    return null;
}

fn processExited(processes: []const TargetProcess, process_id: DWORD) bool {
    const index = findProcess(processes, process_id) orelse return false;
    return WaitForSingleObject(processes[index].handle, 0) == wait_object_0;
}

fn windowsPathEql(left: []const u16, right: []const u16) bool {
    var left_start: usize = 0;
    var right_start: usize = 0;
    while (true) {
        const left_end = nextSeparator(left, left_start);
        const right_end = nextSeparator(right, right_start);
        const left_segment = left[left_start..left_end];
        const right_segment = right[right_start..right_end];
        if (left_segment.len > std.math.maxInt(c_int) or right_segment.len > std.math.maxInt(c_int)) return false;
        if (CompareStringOrdinal(
            left_segment.ptr,
            @intCast(left_segment.len),
            right_segment.ptr,
            @intCast(right_segment.len),
            .TRUE,
        ) != cstr_equal) return false;
        const left_finished = left_end == left.len;
        const right_finished = right_end == right.len;
        if (left_finished or right_finished) return left_finished and right_finished;
        left_start = left_end + 1;
        right_start = right_end + 1;
    }
}

fn nextSeparator(path: []const u16, start: usize) usize {
    var index = start;
    while (index < path.len and path[index] != '/' and path[index] != '\\') : (index += 1) {}
    return index;
}

fn remainingTimeout(deadline: u64) ?DWORD {
    const now = GetTickCount64();
    if (now >= deadline) return null;
    return @intCast(@min(deadline - now, std.math.maxInt(DWORD)));
}

test "Windows path comparison ignores case and separator spelling" {
    const left = std.unicode.utf8ToUtf16LeStringLiteral("C:\\Users\\한글\\zmd.exe");
    const right = std.unicode.utf8ToUtf16LeStringLiteral("c:/users/한글/ZMD.EXE");
    try std.testing.expect(windowsPathEql(left, right));
    const portable = std.unicode.utf8ToUtf16LeStringLiteral("D:\\Tools\\zmd.exe");
    try std.testing.expect(!windowsPathEql(left, portable));
    try std.testing.expect(try pathsEqual(std.testing.allocator, "C:\\Users\\Änne\\zmd.exe", "c:/users/änne/ZMD.EXE"));
}

test "empty desktop enumeration is success but callback and API failures are preserved" {
    try checkEnumeration(.FALSE, null, 0, false);
    try std.testing.expectError(error.WindowIdentityUnavailable, checkEnumeration(.FALSE, error.WindowIdentityUnavailable, 0, true));
    try std.testing.expectError(error.WindowEnumerationFailed, checkEnumeration(.FALSE, null, 5, false));
    try std.testing.expectError(error.WindowEnumerationFailed, checkEnumeration(.FALSE, null, 0, true));
}
