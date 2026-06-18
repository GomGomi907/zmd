const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const build_options = @import("build_options");
const file_assoc = @import("file_assoc.zig");
const setup = @import("setup.zig");
const ui = @import("ui.zig");
const zmd = @import("zmd");

const max_file_bytes = 16 * 1024 * 1024;

const usage =
    \\zmd - tiny Zig-first Markdown viewer
    \\
    \\Usage:
    \\  zmd <file.md>          Open a read-only native viewer window
    \\  zmd --dump <file.md>   Render Markdown to stdout for tests/pipes
    \\  zmd --install-file-association
    \\                         Register zmd as a Windows Markdown open-with app
    \\  zmd --uninstall-file-association
    \\                         Remove zmd's Windows Markdown open-with registry keys
    \\  zmd --help             Show this help
    \\  zmd --version          Show version
    \\
    \\Status:
    \\  Native GUI slice: Win32 on Windows, runtime-loaded X11 on Linux.
    \\  Full CommonMark/GFM coverage remains an explicit follow-up milestone.
    \\
;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;

    if (args.len > 0 and setup.isSetupExecutable(args[0])) {
        try setup.run(arena, io, init.environ_map, args);
        return;
    }

    if (args.len == 1 or (args.len == 2 and std.mem.eql(u8, args[1], "--help"))) {
        try showInfo(arena, io, "zmd help", usage);
        return;
    }

    if (args.len == 2 and std.mem.eql(u8, args[1], "--version")) {
        const version_text = try std.fmt.allocPrint(arena, "zmd {s}\n", .{zmd.version});
        try showInfo(arena, io, "zmd version", version_text);
        return;
    }

    if (args.len == 2 and std.mem.eql(u8, args[1], "--install-file-association")) {
        file_assoc.install(arena) catch |err| {
            const message = try std.fmt.allocPrint(arena, "Unable to register Windows Markdown file association: {s}", .{@errorName(err)});
            fatal(arena, "zmd error", message, 1);
        };
        try showInfo(arena, io, "zmd file association", "Registered zmd for Windows Markdown files.\n\nUse Open with > Choose another app > zmd, then select Always to make .md files open with zmd and show the zmd document icon.\n");
        return;
    }

    if (args.len == 2 and std.mem.eql(u8, args[1], "--uninstall-file-association")) {
        file_assoc.uninstall(arena) catch |err| {
            const message = try std.fmt.allocPrint(arena, "Unable to remove Windows Markdown file association: {s}", .{@errorName(err)});
            fatal(arena, "zmd error", message, 1);
        };
        try showInfo(arena, io, "zmd file association", "Removed zmd's Windows Markdown file association registration.\n");
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
    const input = readFile(arena, io, path) catch |err| {
        const message = try std.fmt.allocPrint(arena, "Unable to open/read '{s}': {s}", .{ path, @errorName(err) });
        fatal(arena, "zmd error", message, 1);
    };

    if (dump) {
        const rendered = zmd.render(arena, input) catch |err| {
            const message = try std.fmt.allocPrint(arena, "Unable to render '{s}': {s}", .{ path, @errorName(err) });
            fatal(arena, "zmd error", message, 1);
        };
        try writeStdout(io, rendered);
        return;
    }

    const rendered = switch (builtin.os.tag) {
        .windows => zmd.renderRtf(arena, input) catch |err| {
            const message = try std.fmt.allocPrint(arena, "Unable to render formatted Markdown '{s}': {s}", .{ path, @errorName(err) });
            fatal(arena, "zmd error", message, 1);
        },
        else => zmd.render(arena, input) catch |err| {
            const message = try std.fmt.allocPrint(arena, "Unable to render Markdown '{s}': {s}", .{ path, @errorName(err) });
            fatal(arena, "zmd error", message, 1);
        },
    };

    const title = try std.fmt.allocPrint(arena, "zmd - {s}", .{path});
    ui.show(arena, title, rendered) catch |err| {
        const message = try std.fmt.allocPrint(arena, "Unable to open native viewer: {s}\n\nUse `zmd --dump <file.md>` for terminal output.", .{@errorName(err)});
        fatal(arena, "zmd error", message, 1);
    };
}

fn showInfo(allocator: std.mem.Allocator, io: Io, title: []const u8, text: []const u8) !void {
    if (build_options.windows_gui) {
        ui.alert(allocator, title, text);
    } else {
        try writeStdout(io, text);
    }
}

fn writeStdout(io: Io, text: []const u8) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};
    try stdout.writeAll(text);
}

fn fatal(allocator: std.mem.Allocator, title: []const u8, message: []const u8, code: u8) noreturn {
    if (build_options.windows_gui) {
        ui.alert(allocator, title, message);
    } else {
        std.debug.print("{s}: {s}\n", .{ title, message });
    }
    std.process.exit(code);
}

fn readFile(allocator: std.mem.Allocator, io: Io, path: []const u8) ![]u8 {
    var file = try Io.Dir.cwd().openFile(io, path, .{ .allow_directory = false });
    defer file.close(io);

    var file_buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &file_buffer);
    return reader.interface.allocRemaining(allocator, .limited(max_file_bytes));
}

test "version is set" {
    try std.testing.expect(zmd.version.len > 0);
}
