const std = @import("std");
const close_windows = @import("uninstall_windows");

const BOOL = i32;
const DWORD = u32;
const HINSTANCE = ?*anyopaque;
const HWND = ?*anyopaque;
const LPARAM = isize;
const LRESULT = isize;
const UINT = u32;
const WPARAM = usize;

const POINT = extern struct { x: i32, y: i32 };
const MSG = extern struct { hwnd: HWND, message: UINT, wparam: WPARAM, lparam: LPARAM, time: DWORD, point: POINT, private: DWORD };
const WNDCLASSEXW = extern struct {
    size: UINT,
    style: UINT,
    window_proc: *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT,
    class_extra: c_int,
    window_extra: c_int,
    instance: HINSTANCE,
    icon: ?*anyopaque,
    cursor: ?*anyopaque,
    background: ?*anyopaque,
    menu_name: ?[*:0]const u16,
    class_name: [*:0]const u16,
    icon_small: ?*anyopaque,
};

extern "kernel32" fn GetModuleHandleW(name: ?[*:0]const u16) callconv(.winapi) HINSTANCE;
extern "user32" fn RegisterClassExW(window_class: *const WNDCLASSEXW) callconv(.winapi) u16;
extern "user32" fn CreateWindowExW(ex_style: DWORD, class_name: [*:0]const u16, window_name: [*:0]const u16, style: DWORD, x: c_int, y: c_int, width: c_int, height: c_int, parent: HWND, menu: ?*anyopaque, instance: HINSTANCE, parameter: ?*anyopaque) callconv(.winapi) HWND;
extern "user32" fn DefWindowProcW(hwnd: HWND, message: UINT, wparam: WPARAM, lparam: LPARAM) callconv(.winapi) LRESULT;
extern "user32" fn DestroyWindow(hwnd: HWND) callconv(.winapi) BOOL;
extern "user32" fn GetMessageW(message: *MSG, hwnd: HWND, minimum: UINT, maximum: UINT) callconv(.winapi) c_int;
extern "user32" fn TranslateMessage(message: *const MSG) callconv(.winapi) BOOL;
extern "user32" fn DispatchMessageW(message: *const MSG) callconv(.winapi) LRESULT;
extern "user32" fn PostQuitMessage(exit_code: c_int) callconv(.winapi) void;

const wm_destroy: UINT = 0x0002;
const overlapped: DWORD = 0x00000000;
const class_name = std.unicode.utf8ToUtf16LeStringLiteral("zmd_window");
const title = std.unicode.utf8ToUtf16LeStringLiteral("zmd uninstall window fixture");
var cooperative = false;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len >= 2 and std.mem.eql(u8, args[1], "close")) {
        if (args.len != 4) return error.InvalidArguments;
        const timeout = try std.fmt.parseInt(u32, args[3], 10);
        close_windows.closeInstalledWindows(init.arena.allocator(), args[2], timeout) catch std.process.exit(2);
        return;
    }
    if (args.len != 2) return error.InvalidArguments;
    cooperative = if (std.mem.eql(u8, args[1], "cooperative"))
        true
    else if (std.mem.eql(u8, args[1], "noncooperative"))
        false
    else
        return error.InvalidArguments;
    try runWindow();
}

fn runWindow() !void {
    const instance = GetModuleHandleW(null);
    const window_class = WNDCLASSEXW{
        .size = @sizeOf(WNDCLASSEXW),
        .style = 0,
        .window_proc = windowProc,
        .class_extra = 0,
        .window_extra = 0,
        .instance = instance,
        .icon = null,
        .cursor = null,
        .background = null,
        .menu_name = null,
        .class_name = class_name.ptr,
        .icon_small = null,
    };
    if (RegisterClassExW(&window_class) == 0) return error.WindowClassRegistrationFailed;
    const hwnd = CreateWindowExW(0, class_name.ptr, title.ptr, overlapped, 0, 0, 100, 100, null, null, instance, null);
    if (hwnd == null) return error.WindowCreationFailed;
    var message: MSG = undefined;
    while (true) {
        const result = GetMessageW(&message, null, 0, 0);
        if (result == 0) break;
        if (result < 0) return error.MessageLoopFailed;
        _ = TranslateMessage(&message);
        _ = DispatchMessageW(&message);
    }
}

fn windowProc(hwnd: HWND, message: UINT, wparam: WPARAM, lparam: LPARAM) callconv(.winapi) LRESULT {
    if (cooperative and message == close_windows.closeMessage()) {
        _ = DestroyWindow(hwnd);
        return 1;
    }
    if (message == wm_destroy) {
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, message, wparam, lparam);
}
