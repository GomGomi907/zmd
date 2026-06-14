const std = @import("std");

pub const version = "0.1.0";

const rtf_header =
    "{\\rtf1\\ansi\\ansicpg65001\\deff0" ++
    "{\\fonttbl{\\f0 Segoe UI;}{\\f1 Consolas;}}" ++
    "{\\colortbl;\\red0\\green0\\blue0;\\red96\\green96\\blue96;\\red0\\green102\\blue204;\\red245\\green245\\blue245;}" ++
    "\\viewkind4\\uc1\\pard\\f0\\fs22\\cf1\n";

const TaskItem = struct {
    checked: bool,
    text: []const u8,
};

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

pub fn renderRtf(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    try out.appendSlice(allocator, rtf_header);

    var in_code = false;
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        const trimmed = std.mem.trim(u8, line, " \t");

        if (std.mem.startsWith(u8, trimmed, "```")) {
            in_code = !in_code;
            if (in_code) {
                try out.appendSlice(allocator, "\\pard\\li360\\ri240\\sb80\\sa0\\f1\\fs20\\cf2 ");
            } else {
                try out.appendSlice(allocator, "\\pard\\f0\\fs22\\cf1\\sa120\\par\n");
            }
            continue;
        }

        if (in_code) {
            try out.appendSlice(allocator, "\\pard\\li360\\ri240\\sa0\\f1\\fs20\\cf2 ");
            if (line.len == 0) {
                try out.appendSlice(allocator, "\\~");
            } else {
                try appendRtfEscaped(&out, allocator, line);
            }
            try out.appendSlice(allocator, "\\par\n");
            continue;
        }

        if (trimmed.len == 0) {
            try out.appendSlice(allocator, "\\pard\\f0\\fs22\\cf1\\sa80\\par\n");
            continue;
        }

        if (isHorizontalRule(trimmed)) {
            try out.appendSlice(allocator, "\\pard\\brdrb\\brdrs\\brdrw10\\brsp20\\sa180\\par\n");
            continue;
        }

        if (headingLevel(trimmed)) |level| {
            const title = std.mem.trimStart(u8, trimmed[level..], " \t");
            const size = switch (level) {
                1 => "44",
                2 => "36",
                3 => "30",
                4 => "26",
                else => "24",
            };
            try out.appendSlice(allocator, "\\pard\\sb220\\sa120\\f0\\cf1\\b\\fs");
            try out.appendSlice(allocator, size);
            try out.append(allocator, ' ');
            try appendInlineRtf(&out, allocator, title);
            try out.appendSlice(allocator, "\\b0\\fs22\\par\n");
            continue;
        }

        if (std.mem.startsWith(u8, trimmed, ">")) {
            try out.appendSlice(allocator, "\\pard\\li360\\ri240\\sb60\\sa100\\i\\cf2 ");
            const quote = std.mem.trimStart(u8, trimmed[1..], " \t");
            try appendInlineRtf(&out, allocator, quote);
            try out.appendSlice(allocator, "\\i0\\cf1\\par\n");
            continue;
        }

        if (unorderedListText(trimmed)) |text| {
            try out.appendSlice(allocator, "\\pard\\li480\\fi-240\\sa70\\f0\\fs22\\cf1 ");
            if (taskItem(text)) |task| {
                try out.appendSlice(allocator, if (task.checked) "\\u9745?\\tab " else "\\u9744?\\tab ");
                try appendInlineRtf(&out, allocator, task.text);
            } else {
                try out.appendSlice(allocator, "\\bullet\\tab ");
                try appendInlineRtf(&out, allocator, text);
            }
            try out.appendSlice(allocator, "\\par\n");
            continue;
        }

        if (orderedListText(trimmed)) |text| {
            try out.appendSlice(allocator, "\\pard\\li520\\fi-300\\sa70\\f0\\fs22\\cf1 ");
            try appendRtfEscaped(&out, allocator, orderedMarker(trimmed));
            try out.appendSlice(allocator, "\\tab ");
            try appendInlineRtf(&out, allocator, text);
            try out.appendSlice(allocator, "\\par\n");
            continue;
        }

        if (std.mem.startsWith(u8, trimmed, "|")) {
            try out.appendSlice(allocator, "\\pard\\sa40\\f1\\fs20\\cf1 ");
            try appendRtfEscaped(&out, allocator, trimmed);
            try out.appendSlice(allocator, "\\par\n");
            continue;
        }

        try out.appendSlice(allocator, "\\pard\\sa110\\f0\\fs22\\cf1 ");
        try appendInlineRtf(&out, allocator, trimmed);
        try out.appendSlice(allocator, "\\par\n");
    }

    try out.appendSlice(allocator, "}\n");
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

fn orderedMarker(line: []const u8) []const u8 {
    var i: usize = 0;
    while (i < line.len and std.ascii.isDigit(line[i])) : (i += 1) {}
    return line[0 .. i + 1];
}

fn taskItem(text: []const u8) ?TaskItem {
    if (text.len >= 4 and text[0] == '[' and text[2] == ']' and (text[3] == ' ' or text[3] == '\t')) {
        if (text[1] == ' ') return .{ .checked = false, .text = text[4..] };
        if (text[1] == 'x' or text[1] == 'X') return .{ .checked = true, .text = text[4..] };
    }
    return null;
}

fn isHorizontalRule(line: []const u8) bool {
    if (line.len < 3) return false;
    const marker = line[0];
    if (marker != '-' and marker != '*' and marker != '_') return false;
    for (line) |ch| {
        if (ch != marker and ch != ' ' and ch != '\t') return false;
    }
    return true;
}

fn appendInline(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    var i: usize = 0;
    while (i < text.len) {
        if (std.mem.startsWith(u8, text[i..], "![")) {
            if (findByteFrom(text, i + 2, ']')) |close_bracket| {
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (findByteFrom(text, close_bracket + 2, ')')) |close_paren| {
                        try out.appendSlice(allocator, "[image: ");
                        try out.appendSlice(allocator, text[i + 2 .. close_bracket]);
                        try out.appendSlice(allocator, "] <");
                        try out.appendSlice(allocator, text[close_bracket + 2 .. close_paren]);
                        try out.append(allocator, '>');
                        i = close_paren + 1;
                        continue;
                    }
                }
            }
        }

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

        if (std.mem.startsWith(u8, text[i..], "~~")) {
            if (findSliceFrom(text, i + 2, "~~")) |end| {
                try appendInline(out, allocator, text[i + 2 .. end]);
                i = end + 2;
                continue;
            }
        }

        switch (text[i]) {
            '*', '_', '`', '~' => i += 1,
            else => {
                try out.append(allocator, text[i]);
                i += 1;
            },
        }
    }
}

fn appendInlineRtf(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    var i: usize = 0;
    while (i < text.len) {
        if (std.mem.startsWith(u8, text[i..], "![")) {
            if (findByteFrom(text, i + 2, ']')) |close_bracket| {
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (findByteFrom(text, close_bracket + 2, ')')) |close_paren| {
                        try out.appendSlice(allocator, "\\cf2 [image: ");
                        try appendRtfEscaped(out, allocator, text[i + 2 .. close_bracket]);
                        try out.appendSlice(allocator, "] ");
                        try appendRtfEscaped(out, allocator, text[close_bracket + 2 .. close_paren]);
                        try out.appendSlice(allocator, "\\cf1 ");
                        i = close_paren + 1;
                        continue;
                    }
                }
            }
        }

        if (text[i] == '[') {
            if (findByteFrom(text, i + 1, ']')) |close_bracket| {
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (findByteFrom(text, close_bracket + 2, ')')) |close_paren| {
                        try out.appendSlice(allocator, "\\cf3\\ul ");
                        try appendRtfEscaped(out, allocator, text[i + 1 .. close_bracket]);
                        try out.appendSlice(allocator, "\\ulnone\\cf1 ");
                        try out.appendSlice(allocator, "\\cf2 <");
                        try appendRtfEscaped(out, allocator, text[close_bracket + 2 .. close_paren]);
                        try out.appendSlice(allocator, ">\\cf1 ");
                        i = close_paren + 1;
                        continue;
                    }
                }
            }
        }

        if (std.mem.startsWith(u8, text[i..], "**")) {
            if (findSliceFrom(text, i + 2, "**")) |end| {
                try out.appendSlice(allocator, "\\b ");
                try appendInlineRtf(out, allocator, text[i + 2 .. end]);
                try out.appendSlice(allocator, "\\b0 ");
                i = end + 2;
                continue;
            }
        }

        if (std.mem.startsWith(u8, text[i..], "__")) {
            if (findSliceFrom(text, i + 2, "__")) |end| {
                try out.appendSlice(allocator, "\\b ");
                try appendInlineRtf(out, allocator, text[i + 2 .. end]);
                try out.appendSlice(allocator, "\\b0 ");
                i = end + 2;
                continue;
            }
        }

        if (text[i] == '*') {
            if (findByteFrom(text, i + 1, '*')) |end| {
                try out.appendSlice(allocator, "\\i ");
                try appendInlineRtf(out, allocator, text[i + 1 .. end]);
                try out.appendSlice(allocator, "\\i0 ");
                i = end + 1;
                continue;
            }
        }

        if (text[i] == '_') {
            if (findByteFrom(text, i + 1, '_')) |end| {
                try out.appendSlice(allocator, "\\i ");
                try appendInlineRtf(out, allocator, text[i + 1 .. end]);
                try out.appendSlice(allocator, "\\i0 ");
                i = end + 1;
                continue;
            }
        }

        if (text[i] == '`') {
            if (findByteFrom(text, i + 1, '`')) |end| {
                try out.appendSlice(allocator, "\\f1\\fs20\\highlight4 ");
                try appendRtfEscaped(out, allocator, text[i + 1 .. end]);
                try out.appendSlice(allocator, "\\highlight0\\f0\\fs22 ");
                i = end + 1;
                continue;
            }
        }

        if (std.mem.startsWith(u8, text[i..], "~~")) {
            if (findSliceFrom(text, i + 2, "~~")) |end| {
                try out.appendSlice(allocator, "\\strike ");
                try appendInlineRtf(out, allocator, text[i + 2 .. end]);
                try out.appendSlice(allocator, "\\strike0 ");
                i = end + 2;
                continue;
            }
        }

        try appendRtfEscapedByte(out, allocator, text[i]);
        i += 1;
    }
}

fn appendRtfEscaped(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    for (text) |ch| {
        try appendRtfEscapedByte(out, allocator, ch);
    }
}

fn appendRtfEscapedByte(out: *std.ArrayList(u8), allocator: std.mem.Allocator, ch: u8) !void {
    switch (ch) {
        '\\' => try out.appendSlice(allocator, "\\\\"),
        '{' => try out.appendSlice(allocator, "\\{"),
        '}' => try out.appendSlice(allocator, "\\}"),
        '\t' => try out.appendSlice(allocator, "\\tab "),
        '\r' => {},
        '\n' => try out.appendSlice(allocator, "\\line "),
        else => try out.append(allocator, ch),
    }
}

fn findByteFrom(haystack: []const u8, start: usize, needle: u8) ?usize {
    var i = start;
    while (i < haystack.len) : (i += 1) {
        if (haystack[i] == needle) return i;
    }
    return null;
}

fn findSliceFrom(haystack: []const u8, start: usize, needle: []const u8) ?usize {
    if (needle.len == 0 or start >= haystack.len) return null;
    var i = start;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) return i;
    }
    return null;
}

test "renders common markdown blocks" {
    const input =
        \\# Title
        \\
        \\Paragraph with **bold**, *emphasis*, `code`, ~~strike~~, [link](https://example.com), and ![alt](image.png).
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
    try std.testing.expect(std.mem.indexOf(u8, rendered, "strike") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "~~strike~~") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "link <https://example.com>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: alt] <image.png>") != null);
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

test "renders rich text formatting for GUI" {
    const input =
        \\# Title
        \\
        \\Paragraph with **bold**, *emphasis*, `code`, and [link](https://example.com).
        \\- [x] task
    ;
    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.startsWith(u8, rtf, "{\\rtf1"));
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs44 Title") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\i emphasis\\i0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\highlight4 code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul link") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u9745?\\tab task") != null);
}

test "renders ultraqa fixture rich text signals" {
    const input =
        \\# zmd UltraQA Rendering Fixture
        \\
        \\This paragraph checks **bold text**, *italic text*, `inline code`, ~~strike text~~, and [a visible link](https://example.com/zmd).
        \\
        \\## Lists
        \\
        \\- plain bullet item
        \\- [x] completed task item
        \\1. ordered first item
        \\> Blockquote should be indented, gray, and italic enough to differ from normal paragraphs.
        \\```zig
        \\const std = @import("std");
        \\```
        \\| Feature | Expected visual signal |
        \\![Alt text for image](./missing-image.png)
    ;
    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs44 zmd UltraQA Rendering Fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b bold text\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\i italic text\\i0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\highlight4 inline code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\strike strike text\\strike0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul a visible link") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u9745?\\tab completed task item") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "1.\\tab ordered first item") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\i\\cf2 Blockquote") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 const std") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "| Feature | Expected visual signal |") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: Alt text for image] ./missing-image.png") != null);
}
