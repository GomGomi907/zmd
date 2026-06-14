const std = @import("std");
const Io = std.Io;
const zmd = @import("zmd");

const max_file_bytes = 16 * 1024 * 1024;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    if (args.len == 1 or (args.len == 2 and std.mem.eql(u8, args[1], "--help"))) {
        try printUsage(stdout);
        return;
    }

    if (args.len == 2 and std.mem.eql(u8, args[1], "--version")) {
        try stdout.print("zmd {s}\n", .{zmd.version});
        return;
    }

    if (args.len != 2) {
        std.debug.print("zmd: expected exactly one Markdown file path\n\n", .{});
        std.debug.print("Try `zmd --help`.\n", .{});
        std.process.exit(2);
    }

    var file = Io.Dir.cwd().openFile(io, args[1], .{ .allow_directory = false }) catch |err| {
        std.debug.print("zmd: unable to open '{s}': {s}\n", .{ args[1], @errorName(err) });
        std.process.exit(1);
    };
    defer file.close(io);

    var file_buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &file_buffer);
    const input = reader.interface.allocRemaining(arena, .limited(max_file_bytes)) catch |err| {
        std.debug.print("zmd: unable to read '{s}': {s}\n", .{ args[1], @errorName(err) });
        std.process.exit(1);
    };

    const rendered = zmd.render(arena, input) catch |err| {
        std.debug.print("zmd: unable to render '{s}': {s}\n", .{ args[1], @errorName(err) });
        std.process.exit(1);
    };

    try stdout.writeAll(rendered);
}

fn printUsage(stdout: *Io.Writer) !void {
    try stdout.writeAll(
        \\zmd - tiny Zig-first Markdown viewer
        \\
        \\Usage:
        \\  zmd <file.md>     Render a Markdown file in read-only terminal view
        \\  zmd --help        Show this help
        \\  zmd --version     Show version
        \\
        \\Status:
        \\  Initial terminal viewer MVP. Native GUI/file association and fuller
        \\  CommonMark/GFM coverage are explicit follow-up milestones.
        \\
    );
}

test "version is set" {
    try std.testing.expect(zmd.version.len > 0);
}
