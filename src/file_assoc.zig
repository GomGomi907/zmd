const std = @import("std");
const builtin = @import("builtin");

pub const Error = error{
    UnsupportedPlatform,
    ExecutablePathUnavailable,
    ExecutablePathTooLong,
    RegistryOpenFailed,
    RegistryWriteFailed,
    RegistryDeleteFailed,
};

pub fn install(allocator: std.mem.Allocator) Error!void {
    return switch (builtin.os.tag) {
        .windows => @import("file_assoc_win32.zig").install(allocator),
        else => Error.UnsupportedPlatform,
    };
}

pub fn installExecutablePath(allocator: std.mem.Allocator, exe_path: []const u8) Error!void {
    return switch (builtin.os.tag) {
        .windows => @import("file_assoc_win32.zig").installExecutablePath(allocator, exe_path),
        else => Error.UnsupportedPlatform,
    };
}

pub fn uninstall(allocator: std.mem.Allocator) Error!void {
    return switch (builtin.os.tag) {
        .windows => @import("file_assoc_win32.zig").uninstall(allocator),
        else => Error.UnsupportedPlatform,
    };
}
