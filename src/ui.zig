const std = @import("std");
const builtin = @import("builtin");
const zmd = @import("zmd");

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

pub fn showRtfDocument(
    allocator: std.mem.Allocator,
    io: std.Io,
    title: []const u8,
    document: *const zmd.RtfDocument,
    images: []const zmd.RtfImage,
    temp_dir: ?[]const u8,
    local_app_data: ?[]const u8,
) !void {
    return switch (builtin.os.tag) {
        .windows => @import("ui_win32.zig").showRtfDocument(allocator, io, title, document, images, temp_dir, local_app_data),
        else => Error.UnsupportedPlatform,
    };
}

pub fn alert(allocator: std.mem.Allocator, title: []const u8, text: []const u8) void {
    switch (builtin.os.tag) {
        .windows => @import("ui_win32.zig").alert(allocator, title, text),
        else => std.debug.print("{s}: {s}\n", .{ title, text }),
    }
}
