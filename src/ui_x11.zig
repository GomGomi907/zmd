const std = @import("std");

const Display = opaque {};
const GC = ?*anyopaque;
const Window = c_ulong;
const Atom = c_ulong;

const XExposeEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    count: c_int,
};

const XButtonEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: c_ulong,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    state: c_uint,
    button: c_uint,
    same_screen: c_int,
};

const XConfigureEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    event: Window,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    border_width: c_int,
    above: Window,
    override_redirect: c_int,
};

const ClientMessageData = extern union {
    b: [20]u8,
    s: [10]c_short,
    l: [5]c_long,
};

const XClientMessageEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    message_type: Atom,
    format: c_int,
    data: ClientMessageData,
};

const XEvent = extern union {
    type: c_int,
    xexpose: XExposeEvent,
    xbutton: XButtonEvent,
    xconfigure: XConfigureEvent,
    xclient: XClientMessageEvent,
    pad: [24]c_long,
};

const Xlib = struct {
    lib: std.DynLib,
    open_display: *const fn (?[*:0]const u8) callconv(.c) ?*Display,
    default_screen: *const fn (*Display) callconv(.c) c_int,
    root_window: *const fn (*Display, c_int) callconv(.c) Window,
    black_pixel: *const fn (*Display, c_int) callconv(.c) c_ulong,
    white_pixel: *const fn (*Display, c_int) callconv(.c) c_ulong,
    create_simple_window: *const fn (*Display, Window, c_int, c_int, c_uint, c_uint, c_uint, c_ulong, c_ulong) callconv(.c) Window,
    store_name: *const fn (*Display, Window, [*:0]const u8) callconv(.c) c_int,
    select_input: *const fn (*Display, Window, c_long) callconv(.c) c_int,
    map_window: *const fn (*Display, Window) callconv(.c) c_int,
    create_gc: *const fn (*Display, Window, c_ulong, ?*anyopaque) callconv(.c) GC,
    set_foreground: *const fn (*Display, GC, c_ulong) callconv(.c) c_int,
    clear_window: *const fn (*Display, Window) callconv(.c) c_int,
    draw_string: *const fn (*Display, Window, GC, c_int, c_int, [*]const u8, c_int) callconv(.c) c_int,
    next_event: *const fn (*Display, *XEvent) callconv(.c) c_int,
    intern_atom: *const fn (*Display, [*:0]const u8, c_int) callconv(.c) Atom,
    set_wm_protocols: *const fn (*Display, Window, *Atom, c_int) callconv(.c) c_int,
    free_gc: *const fn (*Display, GC) callconv(.c) c_int,
    destroy_window: *const fn (*Display, Window) callconv(.c) c_int,
    close_display: *const fn (*Display) callconv(.c) c_int,
};

const Expose: c_int = 12;
const ButtonPress: c_int = 4;
const ConfigureNotify: c_int = 22;
const ClientMessage: c_int = 33;
const ExposureMask: c_long = 1 << 15;
const ButtonPressMask: c_long = 1 << 2;
const StructureNotifyMask: c_long = 1 << 17;

pub fn show(allocator: std.mem.Allocator, title: []const u8, text: []const u8) !void {
    var x = try loadXlib();
    defer x.lib.close();

    const display = x.open_display(null) orelse return error.WindowInitFailed;
    defer _ = x.close_display(display);

    const title_z = try allocator.dupeZ(u8, title);
    const screen = x.default_screen(display);
    const root = x.root_window(display, screen);
    const black = x.black_pixel(display, screen);
    const white = x.white_pixel(display, screen);

    const window = x.create_simple_window(display, root, 80, 80, 920, 720, 1, black, white);
    if (window == 0) return error.WindowInitFailed;
    defer _ = x.destroy_window(display, window);

    _ = x.store_name(display, window, title_z.ptr);
    _ = x.select_input(display, window, ExposureMask | ButtonPressMask | StructureNotifyMask);

    var wm_delete = x.intern_atom(display, "WM_DELETE_WINDOW", 0);
    _ = x.set_wm_protocols(display, window, &wm_delete, 1);

    const gc = x.create_gc(display, window, 0, null) orelse return error.WindowInitFailed;
    defer _ = x.free_gc(display, gc);
    _ = x.set_foreground(display, gc, black);
    _ = x.map_window(display, window);

    var height: c_int = 720;
    var scroll: usize = 0;
    const total_lines = countLines(text);

    while (true) {
        var event: XEvent = undefined;
        _ = x.next_event(display, &event);

        switch (event.type) {
            Expose => {
                if (event.xexpose.count == 0) draw(&x, display, window, gc, text, scroll, height);
            },
            ConfigureNotify => {
                height = event.xconfigure.height;
                draw(&x, display, window, gc, text, scroll, height);
            },
            ButtonPress => {
                if (event.xbutton.button == 4) {
                    scroll = if (scroll > 3) scroll - 3 else 0;
                } else if (event.xbutton.button == 5) {
                    const visible = visibleLines(height);
                    if (total_lines > visible) {
                        scroll = @min(scroll + 3, total_lines - visible);
                    }
                }
                draw(&x, display, window, gc, text, scroll, height);
            },
            ClientMessage => {
                if (@as(Atom, @intCast(event.xclient.data.l[0])) == wm_delete) break;
            },
            else => {},
        }
    }
}

fn draw(x: *const Xlib, display: *Display, window: Window, gc: GC, text: []const u8, scroll: usize, height: c_int) void {
    _ = x.clear_window(display, window);

    var line_no: usize = 0;
    var y: c_int = 24;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        if (line_no < scroll) {
            line_no += 1;
            continue;
        }
        if (y > height - 8) break;
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        const len: c_int = @intCast(@min(line.len, 4096));
        if (len > 0) _ = x.draw_string(display, window, gc, 12, y, line.ptr, len);
        y += 16;
        line_no += 1;
    }
}

fn visibleLines(height: c_int) usize {
    if (height <= 32) return 1;
    return @intCast(@divTrunc(height - 16, 16));
}

fn countLines(text: []const u8) usize {
    var count: usize = 1;
    for (text) |ch| {
        if (ch == '\n') count += 1;
    }
    return count;
}

fn loadXlib() !Xlib {
    var lib = std.DynLib.open("libX11.so.6") catch std.DynLib.open("libX11.so") catch return error.WindowInitFailed;
    errdefer lib.close();

    return .{
        .lib = lib,
        .open_display = try lookup(&lib, *const fn (?[*:0]const u8) callconv(.c) ?*Display, "XOpenDisplay"),
        .default_screen = try lookup(&lib, *const fn (*Display) callconv(.c) c_int, "XDefaultScreen"),
        .root_window = try lookup(&lib, *const fn (*Display, c_int) callconv(.c) Window, "XRootWindow"),
        .black_pixel = try lookup(&lib, *const fn (*Display, c_int) callconv(.c) c_ulong, "XBlackPixel"),
        .white_pixel = try lookup(&lib, *const fn (*Display, c_int) callconv(.c) c_ulong, "XWhitePixel"),
        .create_simple_window = try lookup(&lib, *const fn (*Display, Window, c_int, c_int, c_uint, c_uint, c_uint, c_ulong, c_ulong) callconv(.c) Window, "XCreateSimpleWindow"),
        .store_name = try lookup(&lib, *const fn (*Display, Window, [*:0]const u8) callconv(.c) c_int, "XStoreName"),
        .select_input = try lookup(&lib, *const fn (*Display, Window, c_long) callconv(.c) c_int, "XSelectInput"),
        .map_window = try lookup(&lib, *const fn (*Display, Window) callconv(.c) c_int, "XMapWindow"),
        .create_gc = try lookup(&lib, *const fn (*Display, Window, c_ulong, ?*anyopaque) callconv(.c) GC, "XCreateGC"),
        .set_foreground = try lookup(&lib, *const fn (*Display, GC, c_ulong) callconv(.c) c_int, "XSetForeground"),
        .clear_window = try lookup(&lib, *const fn (*Display, Window) callconv(.c) c_int, "XClearWindow"),
        .draw_string = try lookup(&lib, *const fn (*Display, Window, GC, c_int, c_int, [*]const u8, c_int) callconv(.c) c_int, "XDrawString"),
        .next_event = try lookup(&lib, *const fn (*Display, *XEvent) callconv(.c) c_int, "XNextEvent"),
        .intern_atom = try lookup(&lib, *const fn (*Display, [*:0]const u8, c_int) callconv(.c) Atom, "XInternAtom"),
        .set_wm_protocols = try lookup(&lib, *const fn (*Display, Window, *Atom, c_int) callconv(.c) c_int, "XSetWMProtocols"),
        .free_gc = try lookup(&lib, *const fn (*Display, GC) callconv(.c) c_int, "XFreeGC"),
        .destroy_window = try lookup(&lib, *const fn (*Display, Window) callconv(.c) c_int, "XDestroyWindow"),
        .close_display = try lookup(&lib, *const fn (*Display) callconv(.c) c_int, "XCloseDisplay"),
    };
}

fn lookup(lib: *std.DynLib, comptime T: type, name: [:0]const u8) !T {
    return lib.lookup(T, name) orelse error.WindowInitFailed;
}
