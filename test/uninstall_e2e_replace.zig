const std = @import("std");
const updater_win32 = @import("updater_win32");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedSourceAndTarget;
    try updater_win32.replacePreservingOld(init.arena.allocator(), init.io, args[1], args[2]);
}
