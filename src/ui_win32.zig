const std = @import("std");

const DWORD = u32;
const UINT = u32;
const BOOL = i32;
const ATOM = u16;
const WPARAM = usize;
const LPARAM = isize;
const LRESULT = isize;

const HWND = ?*anyopaque;
const HINSTANCE = ?*anyopaque;
const HICON = ?*anyopaque;
const HCURSOR = ?*anyopaque;
const HBRUSH = ?*anyopaque;
const HMENU = ?*anyopaque;
const HFONT = ?*anyopaque;
const HGDIOBJ = ?*anyopaque;

const LPCWSTR = [*:0]const u16;
const WNDPROC = ?*const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;

const WNDCLASSW = extern struct {
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: c_int,
    cbWndExtra: c_int,
    hInstance: HINSTANCE,
    hIcon: HICON,
    hCursor: HCURSOR,
    hbrBackground: HBRUSH,
    lpszMenuName: ?LPCWSTR,
    lpszClassName: LPCWSTR,
};

const POINT = extern struct {
    x: c_long,
    y: c_long,
};

const MSG = extern struct {
    hwnd: HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
};

const RECT = extern struct {
    left: c_long,
    top: c_long,
    right: c_long,
    bottom: c_long,
};

extern "kernel32" fn GetModuleHandleW(lpModuleName: ?LPCWSTR) callconv(.winapi) HINSTANCE;
extern "kernel32" fn LoadLibraryW(lpLibFileName: LPCWSTR) callconv(.winapi) HINSTANCE;
extern "user32" fn RegisterClassW(lpWndClass: *const WNDCLASSW) callconv(.winapi) ATOM;
extern "user32" fn CreateWindowExW(
    dwExStyle: DWORD,
    lpClassName: LPCWSTR,
    lpWindowName: ?LPCWSTR,
    dwStyle: DWORD,
    x: c_int,
    y: c_int,
    nWidth: c_int,
    nHeight: c_int,
    hWndParent: HWND,
    hMenu: HMENU,
    hInstance: HINSTANCE,
    lpParam: ?*anyopaque,
) callconv(.winapi) HWND;
extern "user32" fn DefWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: c_int) callconv(.winapi) BOOL;
extern "user32" fn UpdateWindow(hWnd: HWND) callconv(.winapi) BOOL;
extern "user32" fn GetMessageW(lpMsg: *MSG, hWnd: HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) callconv(.winapi) BOOL;
extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) BOOL;
extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) LRESULT;
extern "user32" fn PostQuitMessage(nExitCode: c_int) callconv(.winapi) void;
extern "user32" fn MoveWindow(hWnd: HWND, x: c_int, y: c_int, nWidth: c_int, nHeight: c_int, bRepaint: BOOL) callconv(.winapi) BOOL;
extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
extern "user32" fn SendMessageW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
extern "user32" fn MessageBoxW(hWnd: HWND, lpText: LPCWSTR, lpCaption: LPCWSTR, uType: UINT) callconv(.winapi) c_int;
extern "gdi32" fn GetStockObject(i: c_int) callconv(.winapi) HGDIOBJ;

const CS_VREDRAW: UINT = 0x0001;
const CS_HREDRAW: UINT = 0x0002;
const WS_OVERLAPPEDWINDOW: DWORD = 0x00cf0000;
const WS_VISIBLE: DWORD = 0x10000000;
const WS_CHILD: DWORD = 0x40000000;
const WS_VSCROLL: DWORD = 0x00200000;
const WS_EX_CLIENTEDGE: DWORD = 0x00000200;
const ES_MULTILINE: DWORD = 0x0004;
const ES_AUTOVSCROLL: DWORD = 0x0040;
const ES_NOHIDESEL: DWORD = 0x0100;
const ES_READONLY: DWORD = 0x0800;
const WM_CREATE: UINT = 0x0001;
const WM_DESTROY: UINT = 0x0002;
const WM_SIZE: UINT = 0x0005;
const WM_SETFONT: UINT = 0x0030;
const WM_USER: UINT = 0x0400;
const EM_SETTEXTEX: UINT = WM_USER + 97;
const SW_SHOW: c_int = 5;
const CW_USEDEFAULT: c_int = -2147483648;
const MB_OK: UINT = 0x00000000;
const MB_ICONINFORMATION: UINT = 0x00000040;
const DEFAULT_GUI_FONT: c_int = 17;
const ST_DEFAULT: DWORD = 0;
const CP_UTF8: UINT = 65001;

const SETTEXTEX = extern struct {
    flags: DWORD,
    codepage: UINT,
};

var instance: HINSTANCE = null;
var rtf_ptr: ?[*:0]const u8 = null;
var edit_hwnd: HWND = null;

pub fn show(allocator: std.mem.Allocator, title: []const u8, text: []const u8) !void {
    const rich_edit_dll = std.unicode.utf8ToUtf16LeStringLiteral("Msftedit.dll");
    if (LoadLibraryW(rich_edit_dll.ptr) == null) return error.WindowInitFailed;

    const title_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, title) catch return error.TextEncodingFailed;
    const text_z = try allocator.dupeZ(u8, text);
    rtf_ptr = text_z.ptr;

    const class_name = std.unicode.utf8ToUtf16LeStringLiteral("zmd_window");
    instance = GetModuleHandleW(null);

    const wc = WNDCLASSW{
        .style = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = instance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = class_name.ptr,
    };

    if (RegisterClassW(&wc) == 0) return error.WindowInitFailed;

    const hwnd = CreateWindowExW(
        0,
        class_name.ptr,
        title_w.ptr,
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        920,
        720,
        null,
        null,
        instance,
        null,
    ) orelse return error.WindowInitFailed;

    _ = ShowWindow(hwnd, SW_SHOW);
    _ = UpdateWindow(hwnd);

    var msg: MSG = undefined;
    while (GetMessageW(&msg, null, 0, 0) > 0) {
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }
}

pub fn alert(allocator: std.mem.Allocator, title: []const u8, text: []const u8) void {
    const fallback_title = std.unicode.utf8ToUtf16LeStringLiteral("zmd");
    const fallback_text = std.unicode.utf8ToUtf16LeStringLiteral("zmd message");
    const title_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, title) catch null;
    const text_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, text) catch null;
    _ = MessageBoxW(
        null,
        if (text_w) |slice| slice.ptr else fallback_text.ptr,
        if (title_w) |slice| slice.ptr else fallback_title.ptr,
        MB_OK | MB_ICONINFORMATION,
    );
}

fn windowProc(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM) callconv(.winapi) LRESULT {
    switch (msg) {
        WM_CREATE => {
            const edit_class = std.unicode.utf8ToUtf16LeStringLiteral("RICHEDIT50W");
            edit_hwnd = CreateWindowExW(
                WS_EX_CLIENTEDGE,
                edit_class.ptr,
                null,
                WS_CHILD | WS_VISIBLE | WS_VSCROLL | ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL | ES_NOHIDESEL,
                0,
                0,
                0,
                0,
                hwnd,
                null,
                instance,
                null,
            );
            if (edit_hwnd) |edit| {
                if (GetStockObject(DEFAULT_GUI_FONT)) |font| {
                    _ = SendMessageW(edit, WM_SETFONT, @intFromPtr(font), 1);
                }
                if (rtf_ptr) |rtf| {
                    var set_text = SETTEXTEX{ .flags = ST_DEFAULT, .codepage = CP_UTF8 };
                    _ = SendMessageW(edit, EM_SETTEXTEX, @intFromPtr(&set_text), ptrToLParam(rtf));
                }
            }
            resizeEdit(hwnd);
            return 0;
        },
        WM_SIZE => {
            resizeEdit(hwnd);
            return 0;
        },
        WM_DESTROY => {
            PostQuitMessage(0);
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}

fn ptrToLParam(ptr: anytype) LPARAM {
    return @bitCast(@intFromPtr(ptr));
}

fn resizeEdit(hwnd: HWND) void {
    if (edit_hwnd) |edit| {
        var rect: RECT = undefined;
        if (GetClientRect(hwnd, &rect) != 0) {
            const width: c_int = @intCast(rect.right - rect.left);
            const height: c_int = @intCast(rect.bottom - rect.top);
            _ = MoveWindow(edit, 0, 0, width, height, 1);
        }
    }
}
