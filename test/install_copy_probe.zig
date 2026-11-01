const std = @import("std");
const setup = @import("setup");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedSourceAndTarget;
    try setup.copyInstallation(init.arena.allocator(), init.io, args[1], args[2]);
}
