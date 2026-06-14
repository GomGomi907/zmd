const std = @import("std");

pub const version = "0.1.0";

pub fn render(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    var in_code = false;
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        const trimmed = std.mem.trim(u8, line, " \t");

        if (std.mem.startsWith(u8, trimmed, "```")) {
            in_code = !in_code;
            try appendLine(&out, allocator, if (in_code) "---- code ----" else "--------------");
            continue;
        }

        if (in_code) {
            try out.appendSlice(allocator, "    ");
            try out.appendSlice(allocator, line);
            try out.append(allocator, '\n');
            continue;
        }

        if (trimmed.len == 0) {
            try out.append(allocator, '\n');
            continue;
        }

        if (headingLevel(trimmed)) |level| {
            const title = std.mem.trimStart(u8, trimmed[level..], " \t");
            if (level == 1) {
                try out.appendSlice(allocator, "\n== ");
                try appendInline(&out, allocator, title);
                try out.appendSlice(allocator, " ==\n");
            } else if (level == 2) {
                try out.appendSlice(allocator, "\n-- ");
                try appendInline(&out, allocator, title);
                try out.appendSlice(allocator, " --\n");
            } else {
                try appendInline(&out, allocator, title);
                try out.append(allocator, '\n');
            }
            continue;
        }

        if (std.mem.startsWith(u8, trimmed, ">")) {
            try out.appendSlice(allocator, "| ");
            const quote = std.mem.trimStart(u8, trimmed[1..], " \t");
            try appendInline(&out, allocator, quote);
            try out.append(allocator, '\n');
            continue;
        }

        if (unorderedListText(trimmed)) |text| {
            try out.appendSlice(allocator, "* ");
            try appendInline(&out, allocator, text);
            try out.append(allocator, '\n');
            continue;
        }

        if (orderedListText(trimmed)) |text| {
            try out.appendSlice(allocator, "1. ");
            try appendInline(&out, allocator, text);
            try out.append(allocator, '\n');
            continue;
        }

        try appendInline(&out, allocator, trimmed);
        try out.append(allocator, '\n');
    }

    return out.toOwnedSlice(allocator);
}

fn appendLine(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    try out.appendSlice(allocator, text);
    try out.append(allocator, '\n');
}

fn headingLevel(line: []const u8) ?usize {
    var i: usize = 0;
    while (i < line.len and line[i] == '#') : (i += 1) {}
    if (i == 0 or i > 6) return null;
    if (i < line.len and (line[i] == ' ' or line[i] == '\t')) return i;
    return null;
}

fn unorderedListText(line: []const u8) ?[]const u8 {
    if (line.len >= 2 and (line[0] == '-' or line[0] == '*' or line[0] == '+') and (line[1] == ' ' or line[1] == '\t')) {
        return std.mem.trimStart(u8, line[2..], " \t");
    }
    return null;
}

fn orderedListText(line: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i < line.len and std.ascii.isDigit(line[i])) : (i += 1) {}
    if (i == 0 or i + 1 >= line.len) return null;
    if (line[i] != '.') return null;
    if (line[i + 1] != ' ' and line[i + 1] != '\t') return null;
    return std.mem.trimStart(u8, line[i + 2 ..], " \t");
}

fn appendInline(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '[') {
            if (findByteFrom(text, i + 1, ']')) |close_bracket| {
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (findByteFrom(text, close_bracket + 2, ')')) |close_paren| {
                        try out.appendSlice(allocator, text[i + 1 .. close_bracket]);
                        try out.appendSlice(allocator, " <");
                        try out.appendSlice(allocator, text[close_bracket + 2 .. close_paren]);
                        try out.append(allocator, '>');
                        i = close_paren + 1;
                        continue;
                    }
                }
            }
        }

        switch (text[i]) {
            '*', '_', '`' => i += 1,
            else => {
                try out.append(allocator, text[i]);
                i += 1;
            },
        }
    }
}

fn findByteFrom(haystack: []const u8, start: usize, needle: u8) ?usize {
    var i = start;
    while (i < haystack.len) : (i += 1) {
        if (haystack[i] == needle) return i;
    }
    return null;
}

test "renders common markdown blocks" {
    const input =
        \\# Title
        \\
        \\Paragraph with **bold**, *emphasis*, `code`, and [link](https://example.com).
        \\
        \\- item one
        \\1. item two
        \\> quoted
        \\```zig
        \\const x = 1;
        \\```
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "# Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "== Title ==") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "bold") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "link <https://example.com>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* item one") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "1. item two") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| quoted") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "const x = 1;") != null);
}

test "preserves table text" {
    const input =
        \\| A | B |
        \\|---|---|
        \\| 1 | 2 |
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| A | B |") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| 1 | 2 |") != null);
}
