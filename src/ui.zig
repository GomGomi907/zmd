const std = @import("std");
const builtin = @import("builtin");

pub const Error = error{
    UnsupportedPlatform,
    WindowInitFailed,
    TextEncodingFailed,
};

pub fn show(allocator: std.mem.Allocator, title: []const u8, text: []const u8) !void {
    return switch (builtin.os.tag) {
        .windows => @import("ui_win32.zig").show(allocator, title, text),
        .linux => @import("ui_x11.zig").show(allocator, title, text),
        else => Error.UnsupportedPlatform,
    };
}

pub fn alert(allocator: std.mem.Allocator, title: []const u8, text: []const u8) void {
    switch (builtin.os.tag) {
        .windows => @import("ui_win32.zig").alert(allocator, title, text),
        else => std.debug.print("{s}: {s}\n", .{ title, text }),
    }
}
