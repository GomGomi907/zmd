const std = @import("std");
const Io = std.Io;
const build_options = @import("build_options");
const ui = @import("ui.zig");
const zmd = @import("zmd");

const max_file_bytes = 16 * 1024 * 1024;

const usage =
    \\zmd - tiny Zig-first Markdown viewer
    \\
    \\Usage:
    \\  zmd <file.md>          Open a read-only native viewer window
    \\  zmd --dump <file.md>   Render Markdown to stdout for tests/pipes
    \\  zmd --help             Show this help
    \\  zmd --version          Show version
    \\
    \\Status:
    \\  Native GUI slice: Win32 on Windows, runtime-loaded X11 on Linux.
    \\  Full CommonMark/GFM coverage and OS association installers remain
    \\  explicit follow-up milestones.
    \\
;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    if (args.len == 1 or (args.len == 2 and std.mem.eql(u8, args[1], "--help"))) {
        try showInfo(arena, stdout, "zmd help", usage);
        return;
    }

    if (args.len == 2 and std.mem.eql(u8, args[1], "--version")) {
        const version_text = try std.fmt.allocPrint(arena, "zmd {s}\n", .{zmd.version});
        try showInfo(arena, stdout, "zmd version", version_text);
        return;
    }

    var dump = false;
    var path_index: usize = 1;
    if (args.len >= 2 and std.mem.eql(u8, args[1], "--dump")) {
        dump = true;
        path_index = 2;
    }

    if (args.len != path_index + 1) {
        fatal(arena, "zmd", "Expected exactly one Markdown file path. Try `zmd --help`.", 2);
    }

    const path = args[path_index];
    const rendered = readAndRender(arena, io, path) catch |err| {
        const message = try std.fmt.allocPrint(arena, "Unable to open/read/render '{s}': {s}", .{ path, @errorName(err) });
        fatal(arena, "zmd error", message, 1);
    };

    if (dump) {
        try stdout.writeAll(rendered);
        return;
    }

    const title = try std.fmt.allocPrint(arena, "zmd - {s}", .{path});
    ui.show(arena, title, rendered) catch |err| {
        const message = try std.fmt.allocPrint(arena, "Unable to open native viewer: {s}\n\nUse `zmd --dump <file.md>` for terminal output.", .{@errorName(err)});
        fatal(arena, "zmd error", message, 1);
    };
}

fn showInfo(allocator: std.mem.Allocator, stdout: *Io.Writer, title: []const u8, text: []const u8) !void {
    if (build_options.windows_gui) {
        ui.alert(allocator, title, text);
    } else {
        try stdout.writeAll(text);
    }
}

fn fatal(allocator: std.mem.Allocator, title: []const u8, message: []const u8, code: u8) noreturn {
    if (build_options.windows_gui) {
        ui.alert(allocator, title, message);
    } else {
        std.debug.print("{s}: {s}\n", .{ title, message });
    }
    std.process.exit(code);
}

fn readAndRender(allocator: std.mem.Allocator, io: Io, path: []const u8) ![]u8 {
    var file = try Io.Dir.cwd().openFile(io, path, .{ .allow_directory = false });
    defer file.close(io);

    var file_buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &file_buffer);
    const input = try reader.interface.allocRemaining(allocator, .limited(max_file_bytes));
    return zmd.render(allocator, input);
}

test "version is set" {
    try std.testing.expect(zmd.version.len > 0);
}
