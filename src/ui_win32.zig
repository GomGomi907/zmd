const std = @import("std");
const zmd = @import("zmd");

const DWORD = u32;
const UINT = u32;
const BOOL = i32;
const ATOM = u16;
const WPARAM = usize;
const LPARAM = isize;
const LRESULT = isize;
const UINT_PTR = usize;
const COLORREF = DWORD;

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
const TIMERPROC = ?*const fn (HWND, UINT, UINT_PTR, DWORD) callconv(.winapi) void;

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

const CHARRANGE = extern struct {
    cpMin: c_long,
    cpMax: c_long,
};

extern "kernel32" fn GetModuleHandleW(lpModuleName: ?LPCWSTR) callconv(.winapi) HINSTANCE;
extern "kernel32" fn LoadLibraryW(lpLibFileName: LPCWSTR) callconv(.winapi) HINSTANCE;
extern "user32" fn LoadIconW(hInstance: HINSTANCE, lpIconName: LPCWSTR) callconv(.winapi) HICON;
extern "user32" fn LoadCursorW(hInstance: HINSTANCE, lpCursorName: LPCWSTR) callconv(.winapi) HCURSOR;
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
extern "user32" fn DestroyWindow(hWnd: HWND) callconv(.winapi) BOOL;
extern "user32" fn MoveWindow(hWnd: HWND, x: c_int, y: c_int, nWidth: c_int, nHeight: c_int, bRepaint: BOOL) callconv(.winapi) BOOL;
extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
extern "user32" fn GetDpiForSystem() callconv(.winapi) UINT;
extern "user32" fn GetDpiForWindow(hWnd: HWND) callconv(.winapi) UINT;
extern "user32" fn GetFocus() callconv(.winapi) HWND;
extern "user32" fn GetKeyState(nVirtKey: c_int) callconv(.winapi) i16;
extern "user32" fn SendMessageW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
extern "user32" fn SetFocus(hWnd: HWND) callconv(.winapi) HWND;
extern "user32" fn SetWindowPos(hWnd: HWND, hWndInsertAfter: HWND, x: c_int, y: c_int, cx: c_int, cy: c_int, uFlags: UINT) callconv(.winapi) BOOL;
extern "user32" fn MessageBoxW(hWnd: HWND, lpText: LPCWSTR, lpCaption: LPCWSTR, uType: UINT) callconv(.winapi) c_int;
extern "user32" fn SetTimer(hWnd: HWND, nIDEvent: UINT_PTR, uElapse: UINT, lpTimerFunc: TIMERPROC) callconv(.winapi) UINT_PTR;
extern "user32" fn KillTimer(hWnd: HWND, uIDEvent: UINT_PTR) callconv(.winapi) BOOL;
extern "user32" fn InvalidateRect(hWnd: HWND, lpRect: ?*const RECT, bErase: BOOL) callconv(.winapi) BOOL;
extern "gdi32" fn GetStockObject(i: c_int) callconv(.winapi) HGDIOBJ;
extern "gdi32" fn CreateSolidBrush(color: COLORREF) callconv(.winapi) HBRUSH;
extern "dwmapi" fn DwmSetWindowAttribute(
    hwnd: HWND,
    dwAttribute: DWORD,
    pvAttribute: *const anyopaque,
    cbAttribute: DWORD,
) callconv(.winapi) c_long;

const CS_VREDRAW: UINT = 0x0001;
const CS_HREDRAW: UINT = 0x0002;
const WS_OVERLAPPEDWINDOW: DWORD = 0x00cf0000;
const WS_POPUP: DWORD = 0x80000000;
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
const WM_KEYDOWN: UINT = 0x0100;
const WM_MOUSEWHEEL: UINT = 0x020a;
const WM_DPICHANGED: UINT = 0x02e0;
const WM_GETTEXT: UINT = 0x000d;
const WM_GETTEXTLENGTH: UINT = 0x000e;
const WM_SETREDRAW: UINT = 0x000b;
const WM_SETFONT: UINT = 0x0030;
const WM_TIMER: UINT = 0x0113;
const WM_ENTERSIZEMOVE: UINT = 0x0231;
const WM_EXITSIZEMOVE: UINT = 0x0232;
const WM_USER: UINT = 0x0400;
const EM_SETMARGINS: UINT = 0x00d3;
const EM_SETBKGNDCOLOR: UINT = WM_USER + 67;
const EM_EXGETSEL: UINT = WM_USER + 52;
const EM_EXSETSEL: UINT = WM_USER + 55;
const EM_SETTEXTEX: UINT = WM_USER + 97;
const EM_GETSCROLLPOS: UINT = WM_USER + 221;
const EM_SETSCROLLPOS: UINT = WM_USER + 222;
const EM_GETZOOM: UINT = WM_USER + 224;
const EM_SETZOOM: UINT = WM_USER + 225;
const EC_LEFTMARGIN: WPARAM = 0x0001;
const EC_RIGHTMARGIN: WPARAM = 0x0002;
const SW_SHOWDEFAULT: c_int = 10;
const CW_USEDEFAULT: c_int = -2147483648;
const MB_OK: UINT = 0x00000000;
const MB_ICONINFORMATION: UINT = 0x00000040;
const DEFAULT_GUI_FONT: c_int = 17;
const ST_DEFAULT: DWORD = 0;
const CP_UTF8: UINT = 65001;
const SIZE_MINIMIZED: WPARAM = 1;
const SWP_NOZORDER: UINT = 0x0004;
const SWP_NOACTIVATE: UINT = 0x0010;
const VK_CONTROL: c_int = 0x11;
const VK_0: WPARAM = 0x30;
const VK_ADD: WPARAM = 0x6b;
const VK_SUBTRACT: WPARAM = 0x6d;
const VK_OEM_PLUS: WPARAM = 0xbb;
const VK_OEM_MINUS: WPARAM = 0xbd;
const IDC_ARROW: u16 = 32512;
const DWMWA_USE_IMMERSIVE_DARK_MODE: DWORD = 20;
const DWMWA_BORDER_COLOR: DWORD = 34;
const DWMWA_CAPTION_COLOR: DWORD = 35;
const DWMWA_TEXT_COLOR: DWORD = 36;
const window_background: COLORREF = rgb(9, 12, 16);
const document_background: COLORREF = rgb(13, 17, 23);
const window_border: COLORREF = rgb(48, 54, 61);
const document_text: COLORREF = rgb(230, 237, 243);
const reader_max_width: c_int = 920;
const reader_side_gutter: c_int = 18;
const reader_vertical_gutter: c_int = 16;
const reader_text_margin: u16 = 32;
const default_dpi: UINT = 96;
const default_zoom_percent: u32 = 100;
const minimum_zoom_percent: u32 = 50;
const maximum_zoom_percent: u32 = 300;
const zoom_step_percent: u32 = 10;
const app_icon_id: u16 = 1;
const resize_timer_id: UINT_PTR = 1;
const resize_debounce_ms: UINT = 180;
const initial_image_bounds = zmd.RtfImageBounds{ .max_width = 832, .max_height = 480 };

const SETTEXTEX = extern struct {
    flags: DWORD,
    codepage: UINT,
};

var instance: HINSTANCE = null;
var rtf_ptr: ?[*:0]const u8 = null;
var edit_hwnd: HWND = null;
var background_brush: HBRUSH = null;
var responsive_document: ?*const zmd.RtfDocument = null;
var responsive_images: []const zmd.RtfImage = &.{};
var last_image_bounds: zmd.RtfImageBounds = initial_image_bounds;
var in_size_move = false;
var current_dpi: UINT = default_dpi;
var zoom_percent: u32 = default_zoom_percent;

pub fn show(allocator: std.mem.Allocator, title: []const u8, text: []const u8) !void {
    const text_z = try allocator.dupeZ(u8, text);
    defer allocator.free(text_z);
    rtf_ptr = text_z.ptr;
    responsive_document = null;
    responsive_images = &.{};
    defer rtf_ptr = null;
    return showWindow(allocator, title);
}

pub fn showRtfDocument(
    allocator: std.mem.Allocator,
    title: []const u8,
    document: *const zmd.RtfDocument,
    images: []const zmd.RtfImage,
) !void {
    const initial_bounds = effectiveImageBounds(initial_image_bounds, images);
    const initial_rtf = try document.finishWithImageBoundsZ(allocator, images, initial_bounds);
    defer allocator.free(initial_rtf);

    rtf_ptr = initial_rtf.ptr;
    responsive_document = if (images.len > 0) document else null;
    responsive_images = images;
    last_image_bounds = initial_bounds;
    in_size_move = false;
    defer {
        rtf_ptr = null;
        responsive_document = null;
        responsive_images = &.{};
        in_size_move = false;
    }
    return showWindow(allocator, title);
}

fn showWindow(allocator: std.mem.Allocator, title: []const u8) !void {
    const rich_edit_dll = std.unicode.utf8ToUtf16LeStringLiteral("Msftedit.dll");
    if (LoadLibraryW(rich_edit_dll.ptr) == null) return error.WindowInitFailed;

    const title_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, title) catch return error.TextEncodingFailed;
    defer allocator.free(title_w);

    const class_name = std.unicode.utf8ToUtf16LeStringLiteral("zmd_window");
    instance = GetModuleHandleW(null);
    background_brush = CreateSolidBrush(window_background);
    current_dpi = nonzeroDpi(GetDpiForSystem());
    zoom_percent = default_zoom_percent;

    const wc = WNDCLASSW{
        .style = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = instance,
        .hIcon = LoadIconW(instance, makeIntResourceW(app_icon_id)),
        .hCursor = LoadCursorW(null, makeIntResourceW(IDC_ARROW)),
        .hbrBackground = background_brush,
        .lpszMenuName = null,
        .lpszClassName = class_name.ptr,
    };

    if (RegisterClassW(&wc) == 0) return error.WindowInitFailed;

    const hwnd = CreateWindowExW(
        0,
        class_name.ptr,
        title_w.ptr,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        scaleForDpi(1040, current_dpi),
        scaleForDpi(780, current_dpi),
        null,
        null,
        instance,
        null,
    ) orelse return error.WindowInitFailed;

    applyDarkWindowFrame(hwnd);
    _ = ShowWindow(hwnd, SW_SHOWDEFAULT);
    if (edit_hwnd) |edit| _ = SetFocus(edit);
    _ = UpdateWindow(hwnd);

    var msg: MSG = undefined;
    while (GetMessageW(&msg, null, 0, 0) > 0) {
        if (handleReaderShortcut(&msg, hwnd)) continue;
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
            current_dpi = nonzeroDpi(GetDpiForWindow(hwnd));
            const edit_class = std.unicode.utf8ToUtf16LeStringLiteral("RICHEDIT50W");
            edit_hwnd = CreateWindowExW(
                0,
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
                _ = SendMessageW(edit, EM_SETBKGNDCOLOR, 0, colorToLParam(document_background));
                applyReaderMargins(edit);
                if (GetStockObject(DEFAULT_GUI_FONT)) |font| {
                    _ = SendMessageW(edit, WM_SETFONT, @intFromPtr(font), 1);
                }
                if (rtf_ptr) |rtf| {
                    var set_text = SETTEXTEX{ .flags = ST_DEFAULT, .codepage = CP_UTF8 };
                    _ = SendMessageW(edit, EM_SETTEXTEX, @intFromPtr(&set_text), ptrToLParam(rtf));
                }
                _ = applyReaderZoom(edit, zoom_percent);
            }
            resizeEdit(hwnd);
            return 0;
        },
        WM_SIZE => {
            resizeEdit(hwnd);
            if (responsive_document != null and !in_size_move and wparam != SIZE_MINIMIZED) scheduleResponsiveLayout(hwnd);
            return 0;
        },
        WM_DPICHANGED => {
            current_dpi = nonzeroDpi(@truncate(wparam));
            if (lparam != 0) {
                const suggested: *const RECT = @ptrFromInt(@as(usize, @bitCast(lparam)));
                _ = SetWindowPos(
                    hwnd,
                    null,
                    @intCast(suggested.left),
                    @intCast(suggested.top),
                    @intCast(suggested.right - suggested.left),
                    @intCast(suggested.bottom - suggested.top),
                    SWP_NOZORDER | SWP_NOACTIVATE,
                );
            }
            if (edit_hwnd) |edit| applyReaderMargins(edit);
            resizeEdit(hwnd);
            applyResponsiveLayout(hwnd);
            return 0;
        },
        WM_ENTERSIZEMOVE => {
            in_size_move = true;
            _ = KillTimer(hwnd, resize_timer_id);
            return 0;
        },
        WM_EXITSIZEMOVE => {
            in_size_move = false;
            _ = KillTimer(hwnd, resize_timer_id);
            applyResponsiveLayout(hwnd);
            return 0;
        },
        WM_TIMER => {
            if (wparam == resize_timer_id) {
                _ = KillTimer(hwnd, resize_timer_id);
                if (!in_size_move) applyResponsiveLayout(hwnd);
                return 0;
            }
            return DefWindowProcW(hwnd, msg, wparam, lparam);
        },
        WM_DESTROY => {
            _ = KillTimer(hwnd, resize_timer_id);
            edit_hwnd = null;
            PostQuitMessage(0);
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}

fn ptrToLParam(ptr: anytype) LPARAM {
    return @bitCast(@intFromPtr(ptr));
}

fn makeIntResourceW(id: u16) LPCWSTR {
    return @ptrFromInt(id);
}

fn colorToLParam(color: COLORREF) LPARAM {
    return @intCast(color);
}

fn makeMargins(left: u16, right: u16) LPARAM {
    return @intCast(@as(u32, left) | (@as(u32, right) << 16));
}

fn nonzeroDpi(dpi: UINT) UINT {
    return if (dpi == 0) default_dpi else dpi;
}

fn scaleForDpi(value: c_int, dpi: UINT) c_int {
    const scaled = @divTrunc(@as(i64, value) * nonzeroDpi(dpi) + default_dpi / 2, default_dpi);
    return @intCast(scaled);
}

fn unscaleForDpi(value: c_int, dpi: UINT) i64 {
    return @divTrunc(@as(i64, value) * default_dpi + nonzeroDpi(dpi) / 2, nonzeroDpi(dpi));
}

fn applyReaderMargins(edit: HWND) void {
    const margin: u16 = @intCast(scaleForDpi(reader_text_margin, current_dpi));
    _ = SendMessageW(edit, EM_SETMARGINS, EC_LEFTMARGIN | EC_RIGHTMARGIN, makeMargins(margin, margin));
}

fn rgb(r: u8, g: u8, b: u8) COLORREF {
    return @as(COLORREF, r) | (@as(COLORREF, g) << 8) | (@as(COLORREF, b) << 16);
}

fn applyDarkWindowFrame(hwnd: HWND) void {
    var dark_mode: BOOL = 1;
    var caption = window_background;
    var border = window_border;
    var text = document_text;
    _ = DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark_mode, @sizeOf(BOOL));
    _ = DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, &caption, @sizeOf(COLORREF));
    _ = DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &border, @sizeOf(COLORREF));
    _ = DwmSetWindowAttribute(hwnd, DWMWA_TEXT_COLOR, &text, @sizeOf(COLORREF));
}

const ReaderLayout = struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};

pub fn readerLayoutForClientSize(width: c_int, height: c_int) ReaderLayout {
    return readerLayoutForClientSizeAtDpi(width, height, default_dpi);
}

pub fn readerLayoutForClientSizeAtDpi(width: c_int, height: c_int, dpi: UINT) ReaderLayout {
    const safe_width: c_int = @max(1, width);
    const safe_height: c_int = @max(1, height);
    const side_gutter = scaleForDpi(reader_side_gutter, dpi);
    const available_width: c_int = @max(1, safe_width - side_gutter * 2);
    const reader_width: c_int = @min(scaleForDpi(reader_max_width, dpi), available_width);
    const maximum_vertical_gutter: c_int = @divTrunc(safe_height - 1, 2);
    const vertical_gutter: c_int = @min(scaleForDpi(reader_vertical_gutter, dpi), maximum_vertical_gutter);
    return .{
        .x = @divTrunc(safe_width - reader_width, 2),
        .y = vertical_gutter,
        .width = reader_width,
        .height = @max(1, safe_height - vertical_gutter * 2),
    };
}

fn resizeEdit(hwnd: HWND) void {
    if (edit_hwnd) |edit| {
        var rect: RECT = undefined;
        if (GetClientRect(hwnd, &rect) != 0) {
            const width: c_int = @intCast(rect.right - rect.left);
            const height: c_int = @intCast(rect.bottom - rect.top);
            const layout = readerLayoutForClientSizeAtDpi(width, height, current_dpi);
            _ = MoveWindow(edit, layout.x, layout.y, layout.width, layout.height, 1);
        }
    }
}

fn scheduleResponsiveLayout(hwnd: HWND) void {
    _ = SetTimer(hwnd, resize_timer_id, resize_debounce_ms, null);
}

fn applyResponsiveLayout(hwnd: HWND) void {
    const document = responsive_document orelse return;
    const edit = edit_hwnd orelse return;
    const viewport_bounds = responsiveImageBounds(hwnd) orelse return;
    const bounds = effectiveImageBounds(viewport_bounds, responsive_images);
    if (sameImageBounds(bounds, last_image_bounds)) return;

    const allocator = std.heap.page_allocator;
    const rtf = document.finishWithImageBoundsZ(allocator, responsive_images, bounds) catch return;
    defer allocator.free(rtf);

    var selection = CHARRANGE{ .cpMin = 0, .cpMax = 0 };
    var scroll = POINT{ .x = 0, .y = 0 };
    _ = SendMessageW(edit, EM_EXGETSEL, 0, ptrToLParam(&selection));
    _ = SendMessageW(edit, EM_GETSCROLLPOS, 0, ptrToLParam(&scroll));

    _ = SendMessageW(edit, WM_SETREDRAW, 0, 0);
    var set_text = SETTEXTEX{ .flags = ST_DEFAULT, .codepage = CP_UTF8 };
    _ = SendMessageW(edit, EM_SETTEXTEX, @intFromPtr(&set_text), ptrToLParam(rtf.ptr));
    _ = applyReaderZoom(edit, zoom_percent);
    _ = SendMessageW(edit, EM_EXSETSEL, 0, ptrToLParam(&selection));
    _ = SendMessageW(edit, EM_SETSCROLLPOS, 0, ptrToLParam(&scroll));
    _ = SendMessageW(edit, WM_SETREDRAW, 1, 0);
    _ = InvalidateRect(edit, null, 1);
    last_image_bounds = bounds;
}

fn responsiveImageBounds(hwnd: HWND) ?zmd.RtfImageBounds {
    _ = hwnd;
    const edit = edit_hwnd orelse return null;
    var rect: RECT = undefined;
    if (GetClientRect(edit, &rect) == 0) return null;
    const width: c_int = @intCast(rect.right - rect.left);
    const height: c_int = @intCast(rect.bottom - rect.top);
    return imageBoundsForClientSizeAtScale(width, height, current_dpi, zoom_percent);
}

pub fn imageBoundsForClientSize(width: c_int, height: c_int) zmd.RtfImageBounds {
    return imageBoundsForClientSizeAtScale(width, height, default_dpi, default_zoom_percent);
}

pub fn imageBoundsForClientSizeAtScale(width: c_int, height: c_int, dpi: UINT, zoom: u32) zmd.RtfImageBounds {
    const safe_zoom = std.math.clamp(zoom, minimum_zoom_percent, maximum_zoom_percent);
    const logical_width = unscaleForDpi(width, dpi);
    const logical_height = unscaleForDpi(height, dpi);
    const zoomed_width = @divTrunc((logical_width - reader_text_margin * 2 - 16) * default_zoom_percent, safe_zoom);
    const zoomed_height = @divTrunc(logical_height * 3 * default_zoom_percent, 4 * safe_zoom);
    const usable_width = cappedPositiveDimension(zoomed_width, 840);
    const usable_height = cappedPositiveDimension(zoomed_height, 800);
    return .{
        .max_width = quantizeDimension(usable_width),
        .max_height = quantizeDimension(usable_height),
    };
}

const ZoomCommand = enum { zoom_in, zoom_out, reset };

fn handleReaderShortcut(msg: *const MSG, window: HWND) bool {
    if (msg.hwnd != edit_hwnd) return false;
    const control_down = GetKeyState(VK_CONTROL) < 0;
    const command = switch (msg.message) {
        WM_KEYDOWN => zoomCommandForKey(msg.wParam, control_down),
        WM_MOUSEWHEEL => zoomCommandForWheel(msg.wParam, control_down),
        else => null,
    } orelse return false;
    setReaderZoom(window, command);
    return true;
}

fn zoomCommandForKey(key: WPARAM, control_down: bool) ?ZoomCommand {
    if (!control_down) return null;
    return switch (key) {
        VK_ADD, VK_OEM_PLUS => .zoom_in,
        VK_SUBTRACT, VK_OEM_MINUS => .zoom_out,
        VK_0 => .reset,
        else => null,
    };
}

fn zoomCommandForWheel(wparam: WPARAM, control_down: bool) ?ZoomCommand {
    if (!control_down) return null;
    const delta: i16 = @bitCast(@as(u16, @truncate(wparam >> 16)));
    if (delta > 0) return .zoom_in;
    if (delta < 0) return .zoom_out;
    return null;
}

fn zoomPercentAfter(command: ZoomCommand, current: u32) u32 {
    return switch (command) {
        .zoom_in => @min(maximum_zoom_percent, current +| zoom_step_percent),
        .zoom_out => if (current <= minimum_zoom_percent + zoom_step_percent) minimum_zoom_percent else current - zoom_step_percent,
        .reset => default_zoom_percent,
    };
}

fn setReaderZoom(window: HWND, command: ZoomCommand) void {
    const edit = edit_hwnd orelse return;
    const previous = zoom_percent;
    zoom_percent = zoomPercentAfter(command, zoom_percent);
    if (!applyReaderZoom(edit, zoom_percent)) {
        zoom_percent = previous;
        return;
    }
    applyResponsiveLayout(window);
}

fn applyReaderZoom(edit: HWND, percent: u32) bool {
    return SendMessageW(edit, EM_SETZOOM, percent, default_zoom_percent) != 0;
}

fn cappedPositiveDimension(value: i64, maximum: u32) u32 {
    if (value <= 1) return 1;
    return @intCast(@min(value, maximum));
}

fn quantizeDimension(value: u32) u32 {
    const bucket: u32 = 32;
    if (value < bucket) return value;
    return @max(bucket, value / bucket * bucket);
}

fn sameImageBounds(a: zmd.RtfImageBounds, b: zmd.RtfImageBounds) bool {
    return a.max_width == b.max_width and a.max_height == b.max_height;
}

fn effectiveImageBounds(bounds: zmd.RtfImageBounds, images: []const zmd.RtfImage) zmd.RtfImageBounds {
    var widest: u32 = 1;
    var tallest: u32 = 1;
    for (images) |image| {
        widest = @max(widest, image.width);
        tallest = @max(tallest, image.height);
    }
    return .{
        .max_width = @min(bounds.max_width, widest),
        .max_height = @min(bounds.max_height, tallest),
    };
}

test "responsive image bounds fit and avoid noisy resize updates" {
    const initial = imageBoundsForClientSize(920, 681);
    try std.testing.expectEqual(@as(u32, 832), initial.max_width);
    try std.testing.expectEqual(@as(u32, 480), initial.max_height);

    const nearby = imageBoundsForClientSize(916, 682);
    try std.testing.expect(sameImageBounds(initial, nearby));

    const large = imageBoundsForClientSize(3840, 2160);
    try std.testing.expectEqual(@as(u32, 832), large.max_width);
    try std.testing.expectEqual(@as(u32, 800), large.max_height);

    const small_image = [_]zmd.RtfImage{.{
        .source = "small.png",
        .data = &.{},
        .width = 100,
        .height = 80,
        .format = .png,
    }};
    const small_bounds = effectiveImageBounds(large, &small_image);
    try std.testing.expectEqual(@as(u32, 100), small_bounds.max_width);
    try std.testing.expectEqual(@as(u32, 80), small_bounds.max_height);
}

test "reader layout centers a bounded document surface" {
    const default = readerLayoutForClientSize(1024, 741);
    try std.testing.expectEqual(@as(c_int, 52), default.x);
    try std.testing.expectEqual(@as(c_int, 16), default.y);
    try std.testing.expectEqual(@as(c_int, 920), default.width);
    try std.testing.expectEqual(@as(c_int, 709), default.height);

    const narrow = readerLayoutForClientSize(320, 200);
    try std.testing.expectEqual(@as(c_int, 18), narrow.x);
    try std.testing.expectEqual(@as(c_int, 284), narrow.width);
    try std.testing.expectEqual(@as(c_int, 168), narrow.height);

    const tiny = readerLayoutForClientSize(1, 1);
    try std.testing.expectEqual(@as(c_int, 1), tiny.width);
    try std.testing.expectEqual(@as(c_int, 1), tiny.height);
}

test "reader layout and image bounds remain stable in device-independent units" {
    const at_96 = readerLayoutForClientSizeAtDpi(1024, 741, 96);
    const at_144 = readerLayoutForClientSizeAtDpi(1536, 1112, 144);
    try std.testing.expectEqual(at_96.width * 3, at_144.width * 2);
    try std.testing.expectEqual(at_96.x * 3, at_144.x * 2);

    const image_96 = imageBoundsForClientSizeAtScale(920, 681, 96, 100);
    const image_144 = imageBoundsForClientSizeAtScale(1380, 1022, 144, 100);
    try std.testing.expect(sameImageBounds(image_96, image_144));

    const image_zoomed = imageBoundsForClientSizeAtScale(920, 681, 96, 200);
    try std.testing.expect(image_zoomed.max_width < image_96.max_width);
    try std.testing.expect(image_zoomed.max_height < image_96.max_height);
}

test "reader zoom shortcuts clamp and reset predictably" {
    try std.testing.expectEqual(ZoomCommand.zoom_in, zoomCommandForKey(VK_OEM_PLUS, true).?);
    try std.testing.expectEqual(ZoomCommand.zoom_out, zoomCommandForKey(VK_SUBTRACT, true).?);
    try std.testing.expectEqual(ZoomCommand.reset, zoomCommandForKey(VK_0, true).?);
    try std.testing.expect(zoomCommandForKey(VK_OEM_PLUS, false) == null);
    try std.testing.expectEqual(ZoomCommand.zoom_in, zoomCommandForWheel(@as(WPARAM, 120) << 16, true).?);
    try std.testing.expectEqual(ZoomCommand.zoom_out, zoomCommandForWheel(@as(WPARAM, @as(u16, @bitCast(@as(i16, -120)))) << 16, true).?);
    try std.testing.expect(zoomCommandForWheel(@as(WPARAM, 120) << 16, false) == null);
    try std.testing.expectEqual(maximum_zoom_percent, zoomPercentAfter(.zoom_in, maximum_zoom_percent));
    try std.testing.expectEqual(minimum_zoom_percent, zoomPercentAfter(.zoom_out, minimum_zoom_percent));
    try std.testing.expectEqual(default_zoom_percent, zoomPercentAfter(.reset, 170));
}

test "headless RichEdit accepts and exposes rendered table content" {
    const rich_edit_dll = std.unicode.utf8ToUtf16LeStringLiteral("Msftedit.dll");
    try std.testing.expect(LoadLibraryW(rich_edit_dll.ptr) != null);

    const edit_class = std.unicode.utf8ToUtf16LeStringLiteral("RICHEDIT50W");
    const edit = CreateWindowExW(
        0,
        edit_class.ptr,
        null,
        WS_POPUP | ES_MULTILINE | ES_READONLY,
        0,
        0,
        800,
        600,
        null,
        null,
        GetModuleHandleW(null),
        null,
    ) orelse return error.WindowInitFailed;
    defer _ = DestroyWindow(edit);
    _ = SetFocus(edit);
    try std.testing.expectEqual(edit, GetFocus());

    const markdown =
        \\| Feature | Value |
        \\| --- | ---: |
        \\| Table | **rendered** |
    ;
    const rtf = try zmd.renderRtf(std.testing.allocator, markdown);
    defer std.testing.allocator.free(rtf);
    const rtf_z = try std.testing.allocator.dupeZ(u8, rtf);
    defer std.testing.allocator.free(rtf_z);

    var set_text = SETTEXTEX{ .flags = ST_DEFAULT, .codepage = CP_UTF8 };
    try std.testing.expect(SendMessageW(edit, EM_SETTEXTEX, @intFromPtr(&set_text), ptrToLParam(rtf_z.ptr)) > 0);

    const text_length: usize = @intCast(SendMessageW(edit, WM_GETTEXTLENGTH, 0, 0));
    try std.testing.expect(text_length > 0);
    const buffer = try std.testing.allocator.allocSentinel(u16, text_length, 0);
    defer std.testing.allocator.free(buffer);
    const copied: usize = @intCast(SendMessageW(edit, WM_GETTEXT, buffer.len + 1, ptrToLParam(buffer.ptr)));
    const plain = try std.unicode.wtf16LeToWtf8Alloc(std.testing.allocator, buffer[0..copied]);
    defer std.testing.allocator.free(plain);

    try std.testing.expect(std.mem.indexOf(u8, plain, "Feature") != null);
    try std.testing.expect(std.mem.indexOf(u8, plain, "rendered") != null);

    try std.testing.expect(applyReaderZoom(edit, 125));
    var zoom_numerator: c_int = 0;
    var zoom_denominator: c_int = 0;
    try std.testing.expect(SendMessageW(edit, EM_GETZOOM, @intFromPtr(&zoom_numerator), ptrToLParam(&zoom_denominator)) != 0);
    try std.testing.expectEqual(
        @as(i64, 125) * zoom_denominator,
        @as(i64, 100) * zoom_numerator,
    );
}
