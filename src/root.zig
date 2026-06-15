const std = @import("std");

pub const version = "0.1.0";

const rtf_header =
    "{\\rtf1\\ansi\\ansicpg65001\\deff0" ++
    "{\\fonttbl{\\f0 Segoe UI;}{\\f1 Consolas;}}" ++
    "{\\colortbl;\\red229\\green231\\blue235;\\red156\\green163\\blue175;\\red96\\green165\\blue250;\\red31\\green41\\blue55;}" ++
    "\\viewkind4\\uc1\\pard\\f0\\fs22\\cf1\n";

const TaskItem = struct {
    checked: bool,
    text: []const u8,
};

const ReferenceDef = struct {
    label: []const u8,
    destination: []const u8,
};

const ReferenceDefStart = struct {
    label: []const u8,
};

const ReferenceDefParse = struct {
    def: ReferenceDef,
    allow_following_title: bool,
};

const LinkDestinationParse = struct {
    destination: []const u8,
    has_title: bool,
};

const ReferenceScan = struct {
    defs: []ReferenceDef,
    hidden_lines: []bool,
    owned_labels: [][]u8,
};

fn freeReferenceScan(allocator: std.mem.Allocator, scan: ReferenceScan) void {
    for (scan.owned_labels) |label| allocator.free(label);
    allocator.free(scan.owned_labels);
    allocator.free(scan.defs);
    allocator.free(scan.hidden_lines);
}

const max_reference_label_bytes = 999;

const BlockquoteLine = struct {
    level: usize,
    content: []const u8,
};

const CodeSpan = struct {
    content: []const u8,
    end: usize,
};

const CodeFence = struct {
    marker: u8,
    len: usize,
    indent: usize,
};

const NamedEntity = struct {
    name: []const u8,
    value: []const u8,
};

const named_entities = [_]NamedEntity{
    .{ .name = "AElig", .value = "\u{00c6}" },
    .{ .name = "ClockwiseContourIntegral", .value = "\u{2232}" },
    .{ .name = "CounterClockwiseContourIntegral", .value = "\u{2233}" },
    .{ .name = "Dcaron", .value = "\u{010e}" },
    .{ .name = "Delta", .value = "\u{0394}" },
    .{ .name = "DiacriticalGrave", .value = "`" },
    .{ .name = "DifferentialD", .value = "\u{2146}" },
    .{ .name = "DownBreve", .value = "\u{0311}" },
    .{ .name = "DoubleLongLeftRightArrow", .value = "\u{27fa}" },
    .{ .name = "Gamma", .value = "\u{0393}" },
    .{ .name = "Hacek", .value = "\u{02c7}" },
    .{ .name = "HilbertSpace", .value = "\u{210b}" },
    .{ .name = "Lambda", .value = "\u{039b}" },
    .{ .name = "LeftArrowBar", .value = "\u{21e4}" },
    .{ .name = "NotEqualTilde", .value = "\u{2242}\u{0338}" },
    .{ .name = "NotGreaterLess", .value = "\u{2279}" },
    .{ .name = "NotLessLess", .value = "\u{226a}\u{0338}" },
    .{ .name = "NotNestedGreaterGreater", .value = "\u{2aa2}\u{0338}" },
    .{ .name = "NotRightTriangleBar", .value = "\u{29d0}\u{0338}" },
    .{ .name = "NotSubsetEqual", .value = "\u{2288}" },
    .{ .name = "Omega", .value = "\u{03a9}" },
    .{ .name = "RightTeeArrow", .value = "\u{21a6}" },
    .{ .name = "Theta", .value = "\u{0398}" },
    .{ .name = "TildeFullEqual", .value = "\u{2245}" },
    .{ .name = "UnderBar", .value = "_" },
    .{ .name = "VerticalSeparator", .value = "\u{2758}" },
    .{ .name = "acE", .value = "\u{223e}\u{0333}" },
    .{ .name = "alpha", .value = "\u{03b1}" },
    .{ .name = "amp", .value = "&" },
    .{ .name = "angmsd", .value = "\u{2221}" },
    .{ .name = "approx", .value = "\u{2248}" },
    .{ .name = "apos", .value = "'" },
    .{ .name = "beta", .value = "\u{03b2}" },
    .{ .name = "bull", .value = "\u{2022}" },
    .{ .name = "cent", .value = "\u{00a2}" },
    .{ .name = "copy", .value = "\u{00a9}" },
    .{ .name = "Dagger", .value = "\u{2021}" },
    .{ .name = "dagger", .value = "\u{2020}" },
    .{ .name = "deg", .value = "\u{00b0}" },
    .{ .name = "divide", .value = "\u{00f7}" },
    .{ .name = "empty", .value = "\u{2205}" },
    .{ .name = "equiv", .value = "\u{2261}" },
    .{ .name = "euro", .value = "\u{20ac}" },
    .{ .name = "exist", .value = "\u{2203}" },
    .{ .name = "fjlig", .value = "fj" },
    .{ .name = "forall", .value = "\u{2200}" },
    .{ .name = "frac12", .value = "\u{00bd}" },
    .{ .name = "frac14", .value = "\u{00bc}" },
    .{ .name = "frac34", .value = "\u{00be}" },
    .{ .name = "gamma", .value = "\u{03b3}" },
    .{ .name = "ge", .value = "\u{2265}" },
    .{ .name = "gt", .value = ">" },
    .{ .name = "harr", .value = "\u{2194}" },
    .{ .name = "hellip", .value = "\u{2026}" },
    .{ .name = "infin", .value = "\u{221e}" },
    .{ .name = "int", .value = "\u{222b}" },
    .{ .name = "isin", .value = "\u{2208}" },
    .{ .name = "laquo", .value = "\u{00ab}" },
    .{ .name = "larr", .value = "\u{2190}" },
    .{ .name = "le", .value = "\u{2264}" },
    .{ .name = "ldquo", .value = "\u{201c}" },
    .{ .name = "lt", .value = "<" },
    .{ .name = "mapsto", .value = "\u{21a6}" },
    .{ .name = "mdash", .value = "\u{2014}" },
    .{ .name = "middot", .value = "\u{00b7}" },
    .{ .name = "micro", .value = "\u{00b5}" },
    .{ .name = "nabla", .value = "\u{2207}" },
    .{ .name = "ndash", .value = "\u{2013}" },
    .{ .name = "ne", .value = "\u{2260}" },
    .{ .name = "ngE", .value = "\u{2267}\u{0338}" },
    .{ .name = "nGg", .value = "\u{22d9}\u{0338}" },
    .{ .name = "nsube", .value = "\u{2288}" },
    .{ .name = "notin", .value = "\u{2209}" },
    .{ .name = "nbsp", .value = "\u{00a0}" },
    .{ .name = "nvlt", .value = "<\u{20d2}" },
    .{ .name = "omega", .value = "\u{03c9}" },
    .{ .name = "ouml", .value = "\u{00f6}" },
    .{ .name = "para", .value = "\u{00b6}" },
    .{ .name = "part", .value = "\u{2202}" },
    .{ .name = "pi", .value = "\u{03c0}" },
    .{ .name = "plusmn", .value = "\u{00b1}" },
    .{ .name = "pound", .value = "\u{00a3}" },
    .{ .name = "prod", .value = "\u{220f}" },
    .{ .name = "quot", .value = "\"" },
    .{ .name = "radic", .value = "\u{221a}" },
    .{ .name = "raquo", .value = "\u{00bb}" },
    .{ .name = "rarr", .value = "\u{2192}" },
    .{ .name = "reg", .value = "\u{00ae}" },
    .{ .name = "rdquo", .value = "\u{201d}" },
    .{ .name = "rsquo", .value = "\u{2019}" },
    .{ .name = "sect", .value = "\u{00a7}" },
    .{ .name = "sup1", .value = "\u{00b9}" },
    .{ .name = "sup2", .value = "\u{00b2}" },
    .{ .name = "sup3", .value = "\u{00b3}" },
    .{ .name = "sum", .value = "\u{2211}" },
    .{ .name = "there4", .value = "\u{2234}" },
    .{ .name = "times", .value = "\u{00d7}" },
    .{ .name = "trade", .value = "\u{2122}" },
    .{ .name = "yen", .value = "\u{00a5}" },
};

const HtmlBlock = struct {
    end_tag: []const u8,
    end_on_blank: bool,
    interrupts_paragraph: bool = true,
};

const html_block_level_tags = [_][]const u8{
    "address",
    "article",
    "aside",
    "base",
    "basefont",
    "blockquote",
    "body",
    "caption",
    "center",
    "col",
    "colgroup",
    "dd",
    "details",
    "dialog",
    "dir",
    "div",
    "dl",
    "dt",
    "fieldset",
    "figcaption",
    "figure",
    "footer",
    "form",
    "frame",
    "frameset",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "head",
    "header",
    "hr",
    "html",
    "iframe",
    "legend",
    "li",
    "link",
    "main",
    "menu",
    "menuitem",
    "nav",
    "noframes",
    "ol",
    "optgroup",
    "option",
    "p",
    "param",
    "search",
    "section",
    "summary",
    "table",
    "tbody",
    "td",
    "tfoot",
    "th",
    "thead",
    "title",
    "tr",
    "track",
    "ul",
};

const ParagraphLine = struct {
    text: []const u8,
    heading_text: []const u8,
    hard_break: bool,
};

const PendingContainerKind = enum {
    list,
    blockquote,
};

const PendingContainer = struct {
    kind: PendingContainerKind,
    quote_level: usize,
    prefix: []u8,
    suffix: []const u8,
    text: []u8,
    heading_text: []u8,
    hard_break: bool,
    coalesce_continuations: bool,
    ordered_start_guard: bool = false,
    ordered_start_guard_requires_indent: bool = false,
    list_marker_level: ?usize = null,
    fallback: ?[]u8 = null,
};

const HiddenListPrefix = struct {
    prefix: []u8,
    in_blockquote: bool = false,
    quote_level: usize = 0,
    list_marker_level: ?usize = null,
};

const ActiveContainerHtml = struct {
    block: HtmlBlock,
    kind: PendingContainerKind,
    quote_level: usize,
    indent_level: usize,
};

const ActiveContainerHtmlOpen = struct {
    container: ActiveContainerHtml,
    content: []const u8,
};

const ActiveContainerFence = struct {
    fence: CodeFence,
    kind: PendingContainerKind,
    quote_level: usize,
    indent_level: usize,
};

fn stripUtf8Bom(input: []const u8) []const u8 {
    if (std.mem.startsWith(u8, input, "\xEF\xBB\xBF")) return input[3..];
    return input;
}

const NormalizedInput = struct {
    text: []const u8,
    owned: ?[]u8 = null,
};

const max_visual_indent_level = 32;

fn normalizeInput(allocator: std.mem.Allocator, input: []const u8) !NormalizedInput {
    const bomless = stripUtf8Bom(input);
    if (!hasUnsafeAsciiControl(bomless) and std.unicode.utf8ValidateSlice(bomless)) return .{ .text = bomless };

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < bomless.len) {
        const byte = bomless[i];
        if (byte == 0) {
            try out.appendSlice(allocator, "\u{fffd}");
            i += 1;
            continue;
        }
        if (isUnsafeAsciiControl(byte)) {
            try out.appendSlice(allocator, "\u{fffd}");
            i += 1;
            continue;
        }

        const width = std.unicode.utf8ByteSequenceLength(byte) catch {
            try out.appendSlice(allocator, "\u{fffd}");
            i += 1;
            continue;
        };
        if (i + width > bomless.len) {
            try out.appendSlice(allocator, "\u{fffd}");
            i += 1;
            continue;
        }
        _ = std.unicode.utf8Decode(bomless[i .. i + width]) catch {
            try out.appendSlice(allocator, "\u{fffd}");
            i += 1;
            continue;
        };

        if (width == 1) {
            try out.append(allocator, byte);
        } else {
            try out.appendSlice(allocator, bomless[i .. i + width]);
        }
        i += width;
    }
    const owned = try out.toOwnedSlice(allocator);
    return .{ .text = owned, .owned = owned };
}

fn hasUnsafeAsciiControl(text: []const u8) bool {
    for (text) |byte| {
        if (isUnsafeAsciiControl(byte)) return true;
    }
    return false;
}

fn isUnsafeAsciiControl(byte: u8) bool {
    return (byte < 0x20 and byte != '\n' and byte != '\r' and byte != '\t') or byte == 0x7f;
}

const SourceLine = struct {
    text: []const u8,
    start: usize,
};

const LineIterator = struct {
    input: []const u8,
    index: usize = 0,

    fn next(self: *LineIterator) ?SourceLine {
        if (self.index > self.input.len) return null;

        const start = self.index;
        var end = start;
        while (end < self.input.len and self.input[end] != '\n' and self.input[end] != '\r') : (end += 1) {}

        if (end == self.input.len) {
            self.index = self.input.len + 1;
            return .{ .text = self.input[start..end], .start = start };
        }

        var next_index = end + 1;
        if (self.input[end] == '\r' and next_index < self.input.len and self.input[next_index] == '\n') {
            next_index += 1;
        }
        self.index = next_index;
        return .{ .text = self.input[start..end], .start = start };
    }
};

fn lineIterator(input: []const u8) LineIterator {
    return .{ .input = input };
}

pub fn render(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const normalized = try normalizeInput(allocator, input);
    defer if (normalized.owned) |owned| allocator.free(owned);
    const source = normalized.text;
    const reference_scan = try scanReferences(allocator, source);
    defer freeReferenceScan(allocator, reference_scan);
    const refs = reference_scan.defs;

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    var active_fence: ?CodeFence = null;
    var active_html_comment = false;
    var active_html_cdata = false;
    var active_html_block: ?HtmlBlock = null;
    var active_container_html: ?ActiveContainerHtml = null;
    var active_container_fence: ?ActiveContainerFence = null;
    var list_context = false;
    var lazy_blockquote_level: usize = 0;
    var lazy_list_level: usize = 0;
    var pending_plain: ?[]const u8 = null;
    var pending_heading_plain: ?[]const u8 = null;
    var pending_owned: ?[]u8 = null;
    var pending_heading_owned: ?[]u8 = null;
    defer if (pending_owned) |owned| allocator.free(owned);
    defer if (pending_heading_owned) |owned| allocator.free(owned);
    var pending_hard_break = false;
    var pending_container: ?PendingContainer = null;
    defer freePendingContainer(allocator, &pending_container);
    var hidden_list_prefix: ?HiddenListPrefix = null;
    defer if (hidden_list_prefix) |hidden| allocator.free(hidden.prefix);
    var line_index: usize = 0;
    var lines = lineIterator(source);
    while (lines.next()) |source_line| {
        const current_line_index = line_index;
        line_index += 1;
        const line = source_line.text;
        const trimmed = std.mem.trim(u8, line, " \t");

        if (active_container_fence) |container| {
            if (containerFenceContent(container, line, trimmed)) |content| {
                if (isClosingCodeFence(content, container.fence)) {
                    try appendPlainContainerFenceClose(&out, allocator, container);
                    active_container_fence = null;
                    list_context = container.kind == .list;
                    lazy_blockquote_level = 0;
                    lazy_list_level = if (container.kind == .list) container.indent_level else 0;
                    continue;
                }
                const code_line = try stripCodeFenceContentIndent(allocator, content, container.fence.indent);
                defer allocator.free(code_line);
                try appendPlainContainerFenceContent(&out, allocator, container, code_line);
                list_context = container.kind == .list;
                lazy_blockquote_level = 0;
                lazy_list_level = if (container.kind == .list) container.indent_level else 0;
                continue;
            }
            active_container_fence = null;
        }

        if (active_container_html) |container| {
            if (container.block.end_on_blank and trimmed.len == 0) {
                active_container_html = null;
                try out.append(allocator, '\n');
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            if (containerHtmlContent(container, line, trimmed)) |content| {
                if (container.block.end_on_blank and std.mem.trim(u8, content, " \t").len == 0) {
                    active_container_html = null;
                    try appendPlainContainerHtmlRaw(&out, allocator, container, content);
                    list_context = container.kind == .list;
                    lazy_blockquote_level = 0;
                    lazy_list_level = if (container.kind == .list) container.indent_level else 0;
                    continue;
                }
                try appendPlainContainerHtmlRaw(&out, allocator, container, content);
                if (htmlBlockEndsOnLine(std.mem.trim(u8, content, " \t"), container.block)) active_container_html = null;
                list_context = container.kind == .list;
                lazy_blockquote_level = 0;
                lazy_list_level = if (container.kind == .list) container.indent_level else 0;
                continue;
            }
            active_container_html = null;
        }

        if (pending_container) |current| {
            if (pendingContainerSetextLevel(current, line, trimmed)) |level| {
                try flushPendingPlainContainerHeading(&out, allocator, &pending_container, level, refs);
                list_context = current.kind == .list;
                lazy_blockquote_level = 0;
                lazy_list_level = if (current.kind == .list) 1 else 0;
                continue;
            }
        }
        if (try consumePendingPlainContainerContinuation(allocator, &pending_container, line, trimmed, refs)) {
            continue;
        }
        if (pending_container != null) {
            try flushPendingPlainContainer(&out, allocator, &pending_container, refs);
        }

        if (active_fence == null) {
            if (pending_plain) |pending| {
                if (setextHeadingLevel(line)) |level| {
                    try appendPlainHeading(&out, allocator, pending_heading_plain orelse pending, level, refs);
                    if (pending_owned) |owned| {
                        allocator.free(owned);
                        pending_owned = null;
                    }
                    if (pending_heading_owned) |owned| {
                        allocator.free(owned);
                        pending_heading_owned = null;
                    }
                    pending_plain = null;
                    pending_heading_plain = null;
                    pending_hard_break = false;
                    list_context = false;
                    continue;
                }
                if (isPlainParagraphContinuationLine(line, trimmed, list_context)) {
                    const current = paragraphContinuationLine(pending, line, trimmed);
                    const separator = if (pending_hard_break) "\n" else " ";
                    const combined = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ pending, separator, current.text });
                    const heading_base = if (pending_hard_break) pending else pending_heading_plain orelse pending;
                    const heading_separator = if (pending_hard_break) "\n" else " ";
                    const heading_combined = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ heading_base, heading_separator, current.heading_text });
                    if (pending_owned) |owned| allocator.free(owned);
                    if (pending_heading_owned) |owned| allocator.free(owned);
                    pending_owned = combined;
                    pending_heading_owned = heading_combined;
                    pending_plain = combined;
                    pending_heading_plain = heading_combined;
                    pending_hard_break = current.hard_break;
                    continue;
                }
                try appendInline(&out, allocator, pending, refs);
                try out.append(allocator, '\n');
                if (pending_owned) |owned| {
                    allocator.free(owned);
                    pending_owned = null;
                }
                if (pending_heading_owned) |owned| {
                    allocator.free(owned);
                    pending_heading_owned = null;
                }
                pending_plain = null;
                pending_heading_plain = null;
                pending_hard_break = false;
                list_context = false;
            }
        }

        if (current_line_index < reference_scan.hidden_lines.len and reference_scan.hidden_lines[current_line_index]) {
            if (try hiddenPlainListReferencePrefix(allocator, line, trimmed, list_context)) |hidden| {
                if (hidden_list_prefix) |old| allocator.free(old.prefix);
                hidden_list_prefix = hidden;
                list_context = true;
            } else if (hidden_list_prefix != null and listIndentLevel(line) == 0 and parseBlockquote(trimmed) == null) {
                if (hidden_list_prefix) |old| allocator.free(old.prefix);
                hidden_list_prefix = null;
                list_context = false;
            } else {
                list_context = hidden_list_prefix != null;
            }
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }
        if (hidden_list_prefix) |hidden| {
            if (!hidden.in_blockquote and trimmed.len != 0 and listIndentLevel(line) == 0) {
                allocator.free(hidden.prefix);
                hidden_list_prefix = null;
            } else if (hidden.in_blockquote) {
                const quote_line = parseBlockquote(trimmed);
                if (quote_line == null or quote_line.?.level != hidden.quote_level) {
                    allocator.free(hidden.prefix);
                    hidden_list_prefix = null;
                }
            }
        }
        if (hidden_list_prefix) |hidden| {
            if (!hidden.in_blockquote and listIndentLevel(line) > 0) {
                defer {
                    allocator.free(hidden.prefix);
                    hidden_list_prefix = null;
                }
                const indent = listIndentLevel(line);
                if (parseOpeningCodeFence(trimmed)) |fence| {
                    const container = ActiveContainerFence{
                        .fence = fence,
                        .kind = .list,
                        .quote_level = 0,
                        .indent_level = indent,
                    };
                    try appendPlainContainerFenceOpenWithPrefix(&out, allocator, hidden.prefix);
                    active_container_fence = container;
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                if (headingLevel(trimmed)) |level| {
                    try appendPlainContainerHeading(&out, allocator, hidden.prefix, atxHeadingTitle(trimmed, level), level, refs);
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                if (isHorizontalRule(trimmed)) {
                    try appendPlainContainerThematicBreak(&out, allocator, hidden.prefix);
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                if (isHtmlBlockLine(trimmed)) {
                    const container = ActiveContainerHtml{
                        .block = containerHtmlBlockStart(trimmed) orelse .{ .end_tag = "", .end_on_blank = false },
                        .kind = .list,
                        .quote_level = 0,
                        .indent_level = indent,
                    };
                    try out.appendSlice(allocator, hidden.prefix);
                    try out.appendSlice(allocator, trimmed);
                    try out.append(allocator, '\n');
                    if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(trimmed, container.block)) active_container_html = container;
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .list, 0, hidden.list_marker_level, hidden.prefix, trimmed, refs);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
        }

        if (active_html_comment) {
            try out.appendSlice(allocator, line);
            try out.append(allocator, '\n');
            if (isHtmlCommentEnd(trimmed)) active_html_comment = false;
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (active_html_cdata) {
            try out.appendSlice(allocator, line);
            try out.append(allocator, '\n');
            if (isHtmlCdataEnd(trimmed)) active_html_cdata = false;
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (active_html_block) |block| {
            if (block.end_on_blank and trimmed.len == 0) {
                active_html_block = null;
                try out.append(allocator, '\n');
                list_context = false;
                lazy_list_level = 0;
                continue;
            }
            try out.appendSlice(allocator, line);
            try out.append(allocator, '\n');
            if (htmlBlockEndsOnLine(trimmed, block)) active_html_block = null;
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (active_fence == null and lazy_blockquote_level > 0 and isPlainParagraphLine(line, trimmed, false)) {
            const prefix = try buildPlainBlockquotePrefix(allocator, lazy_blockquote_level, 0, "");
            defer allocator.free(prefix);
            _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .blockquote, lazy_blockquote_level, null, prefix, trimmed, refs);
            markPendingOrderedStartGuard(&pending_container, false);
            list_context = false;
            lazy_list_level = 0;
            continue;
        }

        if (active_fence == null and lazy_list_level > 0 and isLazyListParagraphContinuation(line, trimmed)) {
            const prefix = try buildPlainListPrefix(allocator, lazy_list_level, "");
            defer allocator.free(prefix);
            _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .list, 0, null, prefix, trimmed, refs);
            list_context = true;
            lazy_blockquote_level = 0;
            continue;
        }

        if (active_fence == null and !list_context) {
            if (indentedCodeText(line)) |code_text| {
                try out.appendSlice(allocator, "    ");
                try out.appendSlice(allocator, code_text);
                try out.append(allocator, '\n');
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
        }

        if (active_fence) |fence| {
            if (isClosingCodeFence(line, fence)) {
                active_fence = null;
                try appendLine(&out, allocator, "--------------");
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            const code_line = try stripCodeFenceContentIndent(allocator, line, fence.indent);
            defer allocator.free(code_line);
            try out.appendSlice(allocator, "    ");
            try out.appendSlice(allocator, code_line);
            try out.append(allocator, '\n');
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (parseOpeningCodeFence(line)) |fence| {
            if (listContinuationBlockStart(line, list_context)) {
                const indent = listIndentLevel(line);
                const list_fence = parseOpeningCodeFence(trimmed) orelse fence;
                const container = ActiveContainerFence{
                    .fence = list_fence,
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = indent,
                };
                const prefix = try buildPlainListPrefix(allocator, indent, "");
                defer allocator.free(prefix);
                try appendPlainContainerFenceOpenWithPrefix(&out, allocator, prefix);
                active_container_fence = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            active_fence = fence;
            try appendLine(&out, allocator, "---- code ----");
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (isHtmlCommentStart(trimmed)) {
            try out.appendSlice(allocator, line);
            try out.append(allocator, '\n');
            active_html_comment = !isHtmlCommentEnd(trimmed);
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (isHtmlCdataStart(trimmed)) {
            try out.appendSlice(allocator, line);
            try out.append(allocator, '\n');
            active_html_cdata = !isHtmlCdataEnd(trimmed);
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (trimmed.len == 0) {
            const keep_list_context = list_context;
            try out.append(allocator, '\n');
            list_context = keep_list_context;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (isHorizontalRule(trimmed)) {
            if (listContinuationBlockStart(line, list_context)) {
                const indent = listIndentLevel(line);
                const prefix = try buildPlainListPrefix(allocator, indent, "");
                defer allocator.free(prefix);
                try appendPlainContainerThematicBreak(&out, allocator, prefix);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            try out.appendSlice(allocator, "---\n");
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (headingLevel(trimmed)) |level| {
            if (listContinuationBlockStart(line, list_context)) {
                const indent = listIndentLevel(line);
                const prefix = try buildPlainListPrefix(allocator, indent, "");
                defer allocator.free(prefix);
                try appendPlainContainerHeading(&out, allocator, prefix, atxHeadingTitle(trimmed, level), level, refs);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            const title = atxHeadingTitle(trimmed, level);
            if (level == 1) {
                try out.appendSlice(allocator, "\n== ");
                try appendInline(&out, allocator, title, refs);
                try out.appendSlice(allocator, " ==\n");
            } else if (level == 2) {
                try out.appendSlice(allocator, "\n-- ");
                try appendInline(&out, allocator, title, refs);
                try out.appendSlice(allocator, " --\n");
            } else {
                try appendInline(&out, allocator, title, refs);
                try out.append(allocator, '\n');
            }
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        const top_level_html_continues_list_paragraph = if (containerHtmlBlockStart(trimmed)) |block|
            lazy_list_level > 0 and listIndentLevel(line) > 0 and !block.interrupts_paragraph
        else
            false;
        if (isHtmlBlockLine(trimmed) and !top_level_html_continues_list_paragraph) {
            if (listContinuationBlockStart(line, list_context)) {
                const indent = listIndentLevel(line);
                const container = ActiveContainerHtml{
                    .block = containerHtmlBlockStart(trimmed) orelse .{ .end_tag = "", .end_on_blank = false },
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = indent,
                };
                const prefix = try buildPlainListPrefix(allocator, indent, "");
                defer allocator.free(prefix);
                try out.appendSlice(allocator, prefix);
                try out.appendSlice(allocator, trimmed);
                try out.append(allocator, '\n');
                if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(trimmed, container.block)) active_container_html = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            try out.appendSlice(allocator, trimmed);
            try out.append(allocator, '\n');
            if (htmlBlockStart(trimmed)) |block| {
                if (!htmlBlockEndsOnLine(trimmed, block)) active_html_block = block;
            }
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (hidden_list_prefix) |hidden| {
            if (hidden.in_blockquote) {
                const quote_line = parseBlockquote(trimmed).?;
                const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
                if (quote_trimmed.len == 0) {
                    try appendPlainBlockquotePrefix(&out, allocator, quote_line.level);
                    try out.append(allocator, '\n');
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                defer {
                    allocator.free(hidden.prefix);
                    hidden_list_prefix = null;
                }
                if (parseOpeningCodeFence(quote_trimmed)) |fence| {
                    const container = ActiveContainerFence{
                        .fence = fence,
                        .kind = .blockquote,
                        .quote_level = hidden.quote_level,
                        .indent_level = 1,
                    };
                    try appendPlainContainerFenceOpenWithPrefix(&out, allocator, hidden.prefix);
                    active_container_fence = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (headingLevel(quote_trimmed)) |level| {
                    try appendPlainContainerHeading(&out, allocator, hidden.prefix, atxHeadingTitle(quote_trimmed, level), level, refs);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHorizontalRule(quote_trimmed)) {
                    try appendPlainContainerThematicBreak(&out, allocator, hidden.prefix);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHtmlBlockLine(quote_trimmed)) {
                    const container = ActiveContainerHtml{
                        .block = containerHtmlBlockStart(quote_trimmed) orelse .{ .end_tag = "", .end_on_blank = false },
                        .kind = .blockquote,
                        .quote_level = hidden.quote_level,
                        .indent_level = 1,
                    };
                    try out.appendSlice(allocator, hidden.prefix);
                    try out.appendSlice(allocator, quote_trimmed);
                    try out.append(allocator, '\n');
                    if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(quote_trimmed, container.block)) active_container_html = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .blockquote, hidden.quote_level, hidden.list_marker_level, hidden.prefix, quote_trimmed, refs);
                list_context = false;
                lazy_blockquote_level = quote_line.level;
                lazy_list_level = 0;
                continue;
            }
        }

        const line_trimmed_start = std.mem.trimStart(u8, line, " \t");
        if (parseBlockquote(line_trimmed_start)) |quote_line| {
            const quote = quote_line.content;
            const quote_trimmed = std.mem.trim(u8, quote, " \t");
            const quote_text = std.mem.trimStart(u8, quote, " \t");
            const quote_display_indent = blockquoteDisplayIndent(quote);
            if (listContinuationBlockStart(line, list_context)) {
                const indent = listIndentLevel(line);
                var prefix: std.ArrayList(u8) = .empty;
                defer prefix.deinit(allocator);
                try appendPlainListIndent(&prefix, allocator, indent);
                try appendPlainBlockquotePrefix(&prefix, allocator, quote_line.level);
                try out.appendSlice(allocator, prefix.items);
                if (quote_trimmed.len != 0) try appendInline(&out, allocator, quote_trimmed, refs);
                try out.append(allocator, '\n');
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            if (quote_trimmed.len == 0) {
                try appendPlainBlockquotePrefix(&out, allocator, quote_line.level);
                try out.append(allocator, '\n');
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            if (parseOpeningCodeFence(quote_trimmed)) |fence| {
                const container = ActiveContainerFence{
                    .fence = fence,
                    .kind = .blockquote,
                    .quote_level = quote_line.level,
                    .indent_level = quote_display_indent,
                };
                try appendPlainContainerFenceOpen(&out, allocator, container);
                active_container_fence = container;
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            if (headingLevel(quote_trimmed)) |level| {
                const prefix = try buildPlainBlockquotePrefix(allocator, quote_line.level, quote_display_indent, "");
                defer allocator.free(prefix);
                try appendPlainContainerHeading(&out, allocator, prefix, atxHeadingTitle(quote_trimmed, level), level, refs);
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            if (isHorizontalRule(quote_trimmed)) {
                const prefix = try buildPlainBlockquotePrefix(allocator, quote_line.level, quote_display_indent, "");
                defer allocator.free(prefix);
                try appendPlainContainerThematicBreak(&out, allocator, prefix);
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            const quote_html_continues_paragraph = if (containerHtmlBlockStart(quote_trimmed)) |block|
                !block.interrupts_paragraph and (lazy_blockquote_level == quote_line.level or quote_display_indent > 0)
            else
                false;
            if (isHtmlBlockLine(quote_trimmed) and !quote_html_continues_paragraph) {
                const container = ActiveContainerHtml{
                    .block = containerHtmlBlockStart(quote_trimmed) orelse .{ .end_tag = "", .end_on_blank = false },
                    .kind = .blockquote,
                    .quote_level = quote_line.level,
                    .indent_level = 0,
                };
                try appendPlainContainerHtmlRaw(&out, allocator, container, quote_trimmed);
                if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(quote_trimmed, container.block)) active_container_html = container;
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            if (unorderedListText(quote_text)) |quote_item| {
                const prefix = try buildPlainBlockquotePrefix(allocator, quote_line.level, quote_display_indent, "* ");
                defer allocator.free(prefix);
                if (parseOpeningCodeFence(quote_item)) |fence| {
                    const container = ActiveContainerFence{
                        .fence = fence,
                        .kind = .blockquote,
                        .quote_level = quote_line.level,
                        .indent_level = quote_display_indent + 1,
                    };
                    try appendPlainContainerFenceOpenWithPrefix(&out, allocator, prefix);
                    active_container_fence = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (headingLevel(quote_item)) |level| {
                    try appendPlainContainerHeading(&out, allocator, prefix, atxHeadingTitle(quote_item, level), level, refs);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHorizontalRule(quote_item)) {
                    try appendPlainContainerThematicBreak(&out, allocator, prefix);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHtmlBlockLine(quote_item)) {
                    const container = ActiveContainerHtml{
                        .block = containerHtmlBlockStart(quote_item) orelse .{ .end_tag = "", .end_on_blank = false },
                        .kind = .blockquote,
                        .quote_level = quote_line.level,
                        .indent_level = quote_display_indent + 1,
                    };
                    try out.appendSlice(allocator, prefix);
                    try out.appendSlice(allocator, quote_item);
                    try out.append(allocator, '\n');
                    if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(quote_item, container.block)) active_container_html = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .blockquote, quote_line.level, listMarkerDisplayLevel(quote, true), prefix, quote_item, refs);
                markPendingOrderedStartGuard(&pending_container, true);
            } else if (orderedListText(quote_text)) |quote_item| {
                const marker = try std.fmt.allocPrint(allocator, "{s} ", .{orderedMarker(quote_text)});
                defer allocator.free(marker);
                const prefix = try buildPlainBlockquotePrefix(allocator, quote_line.level, quote_display_indent, marker);
                defer allocator.free(prefix);
                if (parseOpeningCodeFence(quote_item)) |fence| {
                    const container = ActiveContainerFence{
                        .fence = fence,
                        .kind = .blockquote,
                        .quote_level = quote_line.level,
                        .indent_level = quote_display_indent + 1,
                    };
                    try appendPlainContainerFenceOpenWithPrefix(&out, allocator, prefix);
                    active_container_fence = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (headingLevel(quote_item)) |level| {
                    try appendPlainContainerHeading(&out, allocator, prefix, atxHeadingTitle(quote_item, level), level, refs);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHorizontalRule(quote_item)) {
                    try appendPlainContainerThematicBreak(&out, allocator, prefix);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHtmlBlockLine(quote_item)) {
                    const container = ActiveContainerHtml{
                        .block = containerHtmlBlockStart(quote_item) orelse .{ .end_tag = "", .end_on_blank = false },
                        .kind = .blockquote,
                        .quote_level = quote_line.level,
                        .indent_level = quote_display_indent + 1,
                    };
                    try out.appendSlice(allocator, prefix);
                    try out.appendSlice(allocator, quote_item);
                    try out.append(allocator, '\n');
                    if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(quote_item, container.block)) active_container_html = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .blockquote, quote_line.level, listMarkerDisplayLevel(quote, true), prefix, quote_item, refs);
                markPendingOrderedStartGuard(&pending_container, true);
            } else {
                const prefix = try buildPlainBlockquotePrefix(allocator, quote_line.level, quote_display_indent, "");
                defer allocator.free(prefix);
                _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .blockquote, quote_line.level, null, prefix, quote_text, refs);
                markPendingOrderedStartGuard(&pending_container, false);
            }
            list_context = false;
            lazy_blockquote_level = if (isLazyBlockquoteParagraphSeed(quote, quote_trimmed)) quote_line.level else 0;
            lazy_list_level = 0;
            continue;
        }

        if (unorderedListText(std.mem.trimStart(u8, line, " \t"))) |text| {
            const list_level = listMarkerDisplayLevel(line, list_context);
            if (parseOpeningCodeFence(text)) |fence| {
                const container = ActiveContainerFence{
                    .fence = fence,
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = list_level + 1,
                };
                const prefix = try buildPlainListPrefix(allocator, list_level, "* ");
                defer allocator.free(prefix);
                try appendPlainContainerFenceOpenWithPrefix(&out, allocator, prefix);
                active_container_fence = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (headingLevel(text)) |level| {
                const prefix = try buildPlainListPrefix(allocator, list_level, "* ");
                defer allocator.free(prefix);
                try appendPlainContainerHeading(&out, allocator, prefix, atxHeadingTitle(text, level), level, refs);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (isHorizontalRule(text)) {
                const prefix = try buildPlainListPrefix(allocator, list_level, "* ");
                defer allocator.free(prefix);
                try appendPlainContainerThematicBreak(&out, allocator, prefix);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (isHtmlBlockLine(text)) {
                const container = ActiveContainerHtml{
                    .block = containerHtmlBlockStart(text) orelse .{ .end_tag = "", .end_on_blank = false },
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = list_level + 1,
                };
                const prefix = try buildPlainListPrefix(allocator, list_level, "* ");
                defer allocator.free(prefix);
                try out.appendSlice(allocator, prefix);
                try out.appendSlice(allocator, text);
                try out.append(allocator, '\n');
                if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(text, container.block)) active_container_html = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            const prefix = try buildPlainListPrefix(allocator, list_level, "* ");
            defer allocator.free(prefix);
            _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .list, 0, list_level, prefix, text, refs);
            list_context = true;
            lazy_blockquote_level = 0;
            lazy_list_level = list_level + 1;
            continue;
        }

        if (orderedListText(std.mem.trimStart(u8, line, " \t"))) |text| {
            const list_level = listMarkerDisplayLevel(line, list_context);
            if (parseOpeningCodeFence(text)) |fence| {
                const container = ActiveContainerFence{
                    .fence = fence,
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = list_level + 1,
                };
                const marker = try std.fmt.allocPrint(allocator, "{s} ", .{orderedMarker(trimmed)});
                defer allocator.free(marker);
                const prefix = try buildPlainListPrefix(allocator, list_level, marker);
                defer allocator.free(prefix);
                try appendPlainContainerFenceOpenWithPrefix(&out, allocator, prefix);
                active_container_fence = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (headingLevel(text)) |level| {
                const marker = try std.fmt.allocPrint(allocator, "{s} ", .{orderedMarker(trimmed)});
                defer allocator.free(marker);
                const prefix = try buildPlainListPrefix(allocator, list_level, marker);
                defer allocator.free(prefix);
                try appendPlainContainerHeading(&out, allocator, prefix, atxHeadingTitle(text, level), level, refs);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (isHorizontalRule(text)) {
                const marker = try std.fmt.allocPrint(allocator, "{s} ", .{orderedMarker(trimmed)});
                defer allocator.free(marker);
                const prefix = try buildPlainListPrefix(allocator, list_level, marker);
                defer allocator.free(prefix);
                try appendPlainContainerThematicBreak(&out, allocator, prefix);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (isHtmlBlockLine(text)) {
                const container = ActiveContainerHtml{
                    .block = containerHtmlBlockStart(text) orelse .{ .end_tag = "", .end_on_blank = false },
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = list_level + 1,
                };
                const marker = try std.fmt.allocPrint(allocator, "{s} ", .{orderedMarker(trimmed)});
                defer allocator.free(marker);
                const prefix = try buildPlainListPrefix(allocator, list_level, marker);
                defer allocator.free(prefix);
                try out.appendSlice(allocator, prefix);
                try out.appendSlice(allocator, text);
                try out.append(allocator, '\n');
                if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(text, container.block)) active_container_html = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            const marker = try std.fmt.allocPrint(allocator, "{s} ", .{orderedMarker(trimmed)});
            defer allocator.free(marker);
            const prefix = try buildPlainListPrefix(allocator, list_level, marker);
            defer allocator.free(prefix);
            _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .list, 0, list_level, prefix, text, refs);
            list_context = true;
            lazy_blockquote_level = 0;
            lazy_list_level = list_level + 1;
            continue;
        }

        if (hidden_list_prefix) |hidden| {
            if (hidden.in_blockquote) {
                const quote_line = parseBlockquote(trimmed).?;
                const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
                defer {
                    allocator.free(hidden.prefix);
                    hidden_list_prefix = null;
                }
                if (headingLevel(quote_trimmed)) |level| {
                    try appendPlainContainerHeading(&out, allocator, hidden.prefix, atxHeadingTitle(quote_trimmed, level), level, refs);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHorizontalRule(quote_trimmed)) {
                    try appendPlainContainerThematicBreak(&out, allocator, hidden.prefix);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .blockquote, hidden.quote_level, hidden.list_marker_level, hidden.prefix, quote_trimmed, refs);
                list_context = false;
                lazy_blockquote_level = quote_line.level;
                lazy_list_level = 0;
                continue;
            } else if (listIndentLevel(line) > 0) {
                defer {
                    allocator.free(hidden.prefix);
                    hidden_list_prefix = null;
                }
                const indent = listIndentLevel(line);
                if (parseOpeningCodeFence(trimmed)) |fence| {
                    const container = ActiveContainerFence{
                        .fence = fence,
                        .kind = .list,
                        .quote_level = 0,
                        .indent_level = indent,
                    };
                    try appendPlainContainerFenceOpenWithPrefix(&out, allocator, hidden.prefix);
                    active_container_fence = container;
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                if (headingLevel(trimmed)) |level| {
                    try appendPlainContainerHeading(&out, allocator, hidden.prefix, atxHeadingTitle(trimmed, level), level, refs);
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                if (isHorizontalRule(trimmed)) {
                    try appendPlainContainerThematicBreak(&out, allocator, hidden.prefix);
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .list, 0, hidden.list_marker_level, hidden.prefix, trimmed, refs);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            } else {
                allocator.free(hidden.prefix);
                hidden_list_prefix = null;
            }
        }

        if (listIndentLevel(line) > 0) {
            const indent = listIndentLevel(line);
            const prefix = try buildPlainListPrefix(allocator, indent, "");
            defer allocator.free(prefix);
            const active_list_level = activeListLevelForIndentedContinuation(list_context, lazy_list_level);
            if (active_list_level > 0) {
                if (listIndentedCodeText(line, active_list_level)) |code_text| {
                    const code_prefix = try buildPlainListPrefix(allocator, active_list_level, "");
                    defer allocator.free(code_prefix);
                    try out.appendSlice(allocator, code_prefix);
                    try out.appendSlice(allocator, "    ");
                    try out.appendSlice(allocator, code_text);
                    try out.append(allocator, '\n');
                    list_context = true;
                    lazy_blockquote_level = 0;
                    continue;
                }
            }
            if (parseOpeningCodeFence(trimmed)) |fence| {
                const container = ActiveContainerFence{
                    .fence = fence,
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = indent,
                };
                try appendPlainContainerFenceOpenWithPrefix(&out, allocator, prefix);
                active_container_fence = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            if (isHorizontalRule(trimmed)) {
                try appendPlainContainerThematicBreak(&out, allocator, prefix);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            _ = try queueOrAppendPlainContainer(&out, allocator, &pending_container, .list, 0, null, prefix, trimmed, refs);
            list_context = true;
            lazy_blockquote_level = 0;
            lazy_list_level = indent;
            continue;
        }

        const paragraph = paragraphLine(line, trimmed);
        pending_plain = paragraph.text;
        pending_heading_plain = paragraph.heading_text;
        pending_hard_break = paragraph.hard_break;
        list_context = false;
        lazy_blockquote_level = 0;
        lazy_list_level = 0;
    }

    if (pending_container != null) {
        try flushPendingPlainContainer(&out, allocator, &pending_container, refs);
    }

    if (pending_plain) |pending| {
        try appendInline(&out, allocator, pending, refs);
        try out.append(allocator, '\n');
    }

    return out.toOwnedSlice(allocator);
}

pub fn renderRtf(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const normalized = try normalizeInput(allocator, input);
    defer if (normalized.owned) |owned| allocator.free(owned);
    const source = normalized.text;
    const reference_scan = try scanReferences(allocator, source);
    defer freeReferenceScan(allocator, reference_scan);
    const refs = reference_scan.defs;

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    try out.appendSlice(allocator, rtf_header);

    var active_fence: ?CodeFence = null;
    var active_html_comment = false;
    var active_html_cdata = false;
    var active_html_block: ?HtmlBlock = null;
    var active_container_html: ?ActiveContainerHtml = null;
    var active_container_fence: ?ActiveContainerFence = null;
    var list_context = false;
    var lazy_blockquote_level: usize = 0;
    var lazy_list_level: usize = 0;
    var pending_plain: ?[]const u8 = null;
    var pending_heading_plain: ?[]const u8 = null;
    var pending_owned: ?[]u8 = null;
    var pending_heading_owned: ?[]u8 = null;
    defer if (pending_owned) |owned| allocator.free(owned);
    defer if (pending_heading_owned) |owned| allocator.free(owned);
    var pending_hard_break = false;
    var pending_container: ?PendingContainer = null;
    defer freePendingContainer(allocator, &pending_container);
    var hidden_list_prefix: ?HiddenListPrefix = null;
    defer if (hidden_list_prefix) |hidden| allocator.free(hidden.prefix);
    var line_index: usize = 0;
    var lines = lineIterator(source);
    while (lines.next()) |source_line| {
        const current_line_index = line_index;
        line_index += 1;
        const line = source_line.text;
        const trimmed = std.mem.trim(u8, line, " \t");

        if (active_container_fence) |container| {
            if (containerFenceContent(container, line, trimmed)) |content| {
                if (isClosingCodeFence(content, container.fence)) {
                    try appendRtfContainerFenceClose(&out, allocator, container);
                    active_container_fence = null;
                    list_context = container.kind == .list;
                    lazy_blockquote_level = 0;
                    lazy_list_level = if (container.kind == .list) container.indent_level else 0;
                    continue;
                }
                const code_line = try stripCodeFenceContentIndent(allocator, content, container.fence.indent);
                defer allocator.free(code_line);
                try appendRtfContainerFenceContent(&out, allocator, container, code_line);
                list_context = container.kind == .list;
                lazy_blockquote_level = 0;
                lazy_list_level = if (container.kind == .list) container.indent_level else 0;
                continue;
            }
            active_container_fence = null;
        }

        if (active_container_html) |container| {
            if (container.block.end_on_blank and trimmed.len == 0) {
                active_container_html = null;
                try out.appendSlice(allocator, "\\pard\\f0\\fs22\\cf1\\sa80\\par\n");
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            if (containerHtmlContent(container, line, trimmed)) |content| {
                if (container.block.end_on_blank and std.mem.trim(u8, content, " \t").len == 0) {
                    active_container_html = null;
                    try appendRtfContainerHtmlRaw(&out, allocator, container, content);
                    list_context = container.kind == .list;
                    lazy_blockquote_level = 0;
                    lazy_list_level = if (container.kind == .list) container.indent_level else 0;
                    continue;
                }
                try appendRtfContainerHtmlRaw(&out, allocator, container, content);
                if (htmlBlockEndsOnLine(std.mem.trim(u8, content, " \t"), container.block)) active_container_html = null;
                list_context = container.kind == .list;
                lazy_blockquote_level = 0;
                lazy_list_level = if (container.kind == .list) container.indent_level else 0;
                continue;
            }
            active_container_html = null;
        }

        if (pending_container) |current| {
            if (pendingContainerSetextLevel(current, line, trimmed)) |level| {
                try flushPendingRtfContainerHeading(&out, allocator, &pending_container, level, refs);
                list_context = current.kind == .list;
                lazy_blockquote_level = 0;
                lazy_list_level = if (current.kind == .list) 1 else 0;
                continue;
            }
        }
        if (try consumePendingRtfContainerContinuation(allocator, &pending_container, line, trimmed, refs)) {
            continue;
        }
        if (pending_container != null) {
            try flushPendingRtfContainer(&out, allocator, &pending_container, refs);
        }

        if (active_fence == null) {
            if (pending_plain) |pending| {
                if (setextHeadingLevel(line)) |level| {
                    try appendRtfHeading(&out, allocator, pending_heading_plain orelse pending, level, refs);
                    if (pending_owned) |owned| {
                        allocator.free(owned);
                        pending_owned = null;
                    }
                    if (pending_heading_owned) |owned| {
                        allocator.free(owned);
                        pending_heading_owned = null;
                    }
                    pending_plain = null;
                    pending_heading_plain = null;
                    pending_hard_break = false;
                    list_context = false;
                    continue;
                }
                if (isPlainParagraphContinuationLine(line, trimmed, list_context)) {
                    const current = paragraphContinuationLine(pending, line, trimmed);
                    const separator = if (pending_hard_break) "\n" else " ";
                    const combined = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ pending, separator, current.text });
                    const heading_base = if (pending_hard_break) pending else pending_heading_plain orelse pending;
                    const heading_separator = if (pending_hard_break) "\n" else " ";
                    const heading_combined = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ heading_base, heading_separator, current.heading_text });
                    if (pending_owned) |owned| allocator.free(owned);
                    if (pending_heading_owned) |owned| allocator.free(owned);
                    pending_owned = combined;
                    pending_heading_owned = heading_combined;
                    pending_plain = combined;
                    pending_heading_plain = heading_combined;
                    pending_hard_break = current.hard_break;
                    continue;
                }
                try out.appendSlice(allocator, "\\pard\\sa110\\f0\\fs22\\cf1 ");
                try appendInlineRtf(&out, allocator, pending, refs);
                try out.appendSlice(allocator, "\\par\n");
                if (pending_owned) |owned| {
                    allocator.free(owned);
                    pending_owned = null;
                }
                if (pending_heading_owned) |owned| {
                    allocator.free(owned);
                    pending_heading_owned = null;
                }
                pending_plain = null;
                pending_heading_plain = null;
                pending_hard_break = false;
                list_context = false;
            }
        }

        if (current_line_index < reference_scan.hidden_lines.len and reference_scan.hidden_lines[current_line_index]) {
            if (try hiddenRtfListReferencePrefix(allocator, line, trimmed, list_context)) |hidden| {
                if (hidden_list_prefix) |old| allocator.free(old.prefix);
                hidden_list_prefix = hidden;
                list_context = true;
            } else if (hidden_list_prefix != null and listIndentLevel(line) == 0 and parseBlockquote(trimmed) == null) {
                if (hidden_list_prefix) |old| allocator.free(old.prefix);
                hidden_list_prefix = null;
                list_context = false;
            } else {
                list_context = hidden_list_prefix != null;
            }
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }
        if (hidden_list_prefix) |hidden| {
            if (!hidden.in_blockquote and trimmed.len != 0 and listIndentLevel(line) == 0) {
                allocator.free(hidden.prefix);
                hidden_list_prefix = null;
            } else if (hidden.in_blockquote) {
                const quote_line = parseBlockquote(trimmed);
                if (quote_line == null or quote_line.?.level != hidden.quote_level) {
                    allocator.free(hidden.prefix);
                    hidden_list_prefix = null;
                }
            }
        }
        if (hidden_list_prefix) |hidden| {
            if (!hidden.in_blockquote and listIndentLevel(line) > 0) {
                defer {
                    allocator.free(hidden.prefix);
                    hidden_list_prefix = null;
                }
                const indent = listIndentLevel(line);
                if (parseOpeningCodeFence(trimmed)) |fence| {
                    const container = ActiveContainerFence{
                        .fence = fence,
                        .kind = .list,
                        .quote_level = 0,
                        .indent_level = indent,
                    };
                    try appendRtfContainerFenceOpenWithPrefix(&out, allocator, hidden.prefix, "\\par\n");
                    active_container_fence = container;
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                if (headingLevel(trimmed)) |level| {
                    try appendRtfContainerHeading(&out, allocator, hidden.prefix, "\\par\n", atxHeadingTitle(trimmed, level), level, refs);
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                if (isHorizontalRule(trimmed)) {
                    try appendRtfContainerThematicBreak(&out, allocator, hidden.prefix, "\\par\n");
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                if (isHtmlBlockLine(trimmed)) {
                    const container = ActiveContainerHtml{
                        .block = containerHtmlBlockStart(trimmed) orelse .{ .end_tag = "", .end_on_blank = false },
                        .kind = .list,
                        .quote_level = 0,
                        .indent_level = indent,
                    };
                    try out.appendSlice(allocator, hidden.prefix);
                    try appendRtfEscaped(&out, allocator, trimmed);
                    try out.appendSlice(allocator, "\\par\n");
                    if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(trimmed, container.block)) active_container_html = container;
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .list, 0, hidden.list_marker_level, hidden.prefix, "\\par\n", trimmed, refs);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
        }

        if (active_html_comment) {
            try out.appendSlice(allocator, "\\pard\\sa40\\f0\\fs22\\cf1 ");
            try appendRtfEscaped(&out, allocator, line);
            try out.appendSlice(allocator, "\\par\n");
            if (isHtmlCommentEnd(trimmed)) active_html_comment = false;
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (active_html_cdata) {
            try out.appendSlice(allocator, "\\pard\\sa40\\f0\\fs22\\cf1 ");
            try appendRtfEscaped(&out, allocator, line);
            try out.appendSlice(allocator, "\\par\n");
            if (isHtmlCdataEnd(trimmed)) active_html_cdata = false;
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (active_html_block) |block| {
            if (block.end_on_blank and trimmed.len == 0) {
                active_html_block = null;
                try out.appendSlice(allocator, "\\pard\\f0\\fs22\\cf1\\sa80\\par\n");
                list_context = false;
                lazy_list_level = 0;
                continue;
            }
            try out.appendSlice(allocator, "\\pard\\sa40\\f0\\fs22\\cf1 ");
            try appendRtfEscaped(&out, allocator, line);
            try out.appendSlice(allocator, "\\par\n");
            if (htmlBlockEndsOnLine(trimmed, block)) active_html_block = null;
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (active_fence == null and lazy_blockquote_level > 0 and isPlainParagraphLine(line, trimmed, false)) {
            const prefix = try buildRtfBlockquotePrefix(allocator, lazy_blockquote_level, 0, "");
            defer allocator.free(prefix);
            _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .blockquote, lazy_blockquote_level, null, prefix, "\\i0\\cf1\\par\n", trimmed, refs);
            markPendingOrderedStartGuard(&pending_container, false);
            list_context = false;
            lazy_list_level = 0;
            continue;
        }

        if (active_fence == null and lazy_list_level > 0 and isLazyListParagraphContinuation(line, trimmed)) {
            var prefix: std.ArrayList(u8) = .empty;
            defer prefix.deinit(allocator);
            try appendRtfContinuationPrefix(&prefix, allocator, lazy_list_level);
            _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .list, 0, null, prefix.items, "\\par\n", trimmed, refs);
            list_context = true;
            lazy_blockquote_level = 0;
            continue;
        }

        if (active_fence == null and !list_context) {
            if (indentedCodeText(line)) |code_text| {
                try out.appendSlice(allocator, "\\pard\\li360\\ri240\\sa0\\f1\\fs20\\cf2 ");
                if (code_text.len == 0) {
                    try out.appendSlice(allocator, "\\~");
                } else {
                    try appendRtfEscaped(&out, allocator, code_text);
                }
                try out.appendSlice(allocator, "\\par\n");
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
        }

        if (active_fence) |fence| {
            if (isClosingCodeFence(line, fence)) {
                active_fence = null;
                try out.appendSlice(allocator, "\\pard\\f0\\fs22\\cf1\\sa120\\par\n");
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            try out.appendSlice(allocator, "\\pard\\li360\\ri240\\sa0\\f1\\fs20\\cf2 ");
            const code_line = try stripCodeFenceContentIndent(allocator, line, fence.indent);
            defer allocator.free(code_line);
            if (code_line.len == 0) {
                try out.appendSlice(allocator, "\\~");
            } else {
                try appendRtfEscaped(&out, allocator, code_line);
            }
            try out.appendSlice(allocator, "\\par\n");
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (parseOpeningCodeFence(line)) |fence| {
            if (listContinuationBlockStart(line, list_context)) {
                const indent = listIndentLevel(line);
                const list_fence = parseOpeningCodeFence(trimmed) orelse fence;
                const container = ActiveContainerFence{
                    .fence = list_fence,
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = indent,
                };
                var prefix: std.ArrayList(u8) = .empty;
                defer prefix.deinit(allocator);
                try appendRtfContinuationPrefix(&prefix, allocator, indent);
                try appendRtfContainerFenceOpenWithPrefix(&out, allocator, prefix.items, "\\par\n");
                active_container_fence = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            active_fence = fence;
            try out.appendSlice(allocator, "\\pard\\li360\\ri240\\sb80\\sa0\\f1\\fs20\\cf2 ");
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (isHtmlCommentStart(trimmed)) {
            try out.appendSlice(allocator, "\\pard\\sa40\\f0\\fs22\\cf1 ");
            try appendRtfEscaped(&out, allocator, line);
            try out.appendSlice(allocator, "\\par\n");
            active_html_comment = !isHtmlCommentEnd(trimmed);
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (isHtmlCdataStart(trimmed)) {
            try out.appendSlice(allocator, "\\pard\\sa40\\f0\\fs22\\cf1 ");
            try appendRtfEscaped(&out, allocator, line);
            try out.appendSlice(allocator, "\\par\n");
            active_html_cdata = !isHtmlCdataEnd(trimmed);
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (trimmed.len == 0) {
            const keep_list_context = list_context;
            try out.appendSlice(allocator, "\\pard\\f0\\fs22\\cf1\\sa80\\par\n");
            list_context = keep_list_context;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (isHorizontalRule(trimmed)) {
            if (listContinuationBlockStart(line, list_context)) {
                const indent = listIndentLevel(line);
                var prefix: std.ArrayList(u8) = .empty;
                defer prefix.deinit(allocator);
                try appendRtfContinuationPrefix(&prefix, allocator, indent);
                try appendRtfContainerThematicBreak(&out, allocator, prefix.items, "\\par\n");
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            try out.appendSlice(allocator, "\\pard\\sa160\\f1\\fs20\\cf2 ------------------------------\\par\n");
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (headingLevel(trimmed)) |level| {
            if (listContinuationBlockStart(line, list_context)) {
                const indent = listIndentLevel(line);
                var prefix: std.ArrayList(u8) = .empty;
                defer prefix.deinit(allocator);
                try appendRtfContinuationPrefix(&prefix, allocator, indent);
                try appendRtfContainerHeading(&out, allocator, prefix.items, "\\par\n", atxHeadingTitle(trimmed, level), level, refs);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            const title = atxHeadingTitle(trimmed, level);
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
            try appendInlineRtf(&out, allocator, title, refs);
            try out.appendSlice(allocator, "\\b0\\fs22\\par\n");
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        const top_level_html_continues_list_paragraph = if (containerHtmlBlockStart(trimmed)) |block|
            lazy_list_level > 0 and listIndentLevel(line) > 0 and !block.interrupts_paragraph
        else
            false;
        if (isHtmlBlockLine(trimmed) and !top_level_html_continues_list_paragraph) {
            if (listContinuationBlockStart(line, list_context)) {
                const indent = listIndentLevel(line);
                const container = ActiveContainerHtml{
                    .block = containerHtmlBlockStart(trimmed) orelse .{ .end_tag = "", .end_on_blank = false },
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = indent,
                };
                var prefix: std.ArrayList(u8) = .empty;
                defer prefix.deinit(allocator);
                try appendRtfContinuationPrefix(&prefix, allocator, indent);
                try out.appendSlice(allocator, prefix.items);
                try appendRtfEscaped(&out, allocator, trimmed);
                try out.appendSlice(allocator, "\\par\n");
                if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(trimmed, container.block)) active_container_html = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            try out.appendSlice(allocator, "\\pard\\sa110\\f0\\fs22\\cf1 ");
            try appendRtfEscaped(&out, allocator, trimmed);
            try out.appendSlice(allocator, "\\par\n");
            if (htmlBlockStart(trimmed)) |block| {
                if (!htmlBlockEndsOnLine(trimmed, block)) active_html_block = block;
            }
            list_context = false;
            lazy_blockquote_level = 0;
            lazy_list_level = 0;
            continue;
        }

        if (hidden_list_prefix) |hidden| {
            if (hidden.in_blockquote) {
                const quote_line = parseBlockquote(trimmed).?;
                const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
                if (quote_trimmed.len == 0) {
                    const prefix = try buildRtfBlockquotePrefix(allocator, quote_line.level, 0, "");
                    defer allocator.free(prefix);
                    try out.appendSlice(allocator, prefix);
                    try out.appendSlice(allocator, "\\i0\\cf1\\par\n");
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                defer {
                    allocator.free(hidden.prefix);
                    hidden_list_prefix = null;
                }
                if (parseOpeningCodeFence(quote_trimmed)) |fence| {
                    const container = ActiveContainerFence{
                        .fence = fence,
                        .kind = .blockquote,
                        .quote_level = hidden.quote_level,
                        .indent_level = 1,
                    };
                    try appendRtfContainerFenceOpenWithPrefix(&out, allocator, hidden.prefix, "\\i0\\cf1\\par\n");
                    active_container_fence = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (headingLevel(quote_trimmed)) |level| {
                    try appendRtfContainerHeading(&out, allocator, hidden.prefix, "\\i0\\cf1\\par\n", atxHeadingTitle(quote_trimmed, level), level, refs);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHorizontalRule(quote_trimmed)) {
                    try appendRtfContainerThematicBreak(&out, allocator, hidden.prefix, "\\i0\\cf1\\par\n");
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHtmlBlockLine(quote_trimmed)) {
                    const container = ActiveContainerHtml{
                        .block = containerHtmlBlockStart(quote_trimmed) orelse .{ .end_tag = "", .end_on_blank = false },
                        .kind = .blockquote,
                        .quote_level = hidden.quote_level,
                        .indent_level = 1,
                    };
                    try out.appendSlice(allocator, hidden.prefix);
                    try appendRtfEscaped(&out, allocator, quote_trimmed);
                    try out.appendSlice(allocator, "\\i0\\cf1\\par\n");
                    if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(quote_trimmed, container.block)) active_container_html = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .blockquote, hidden.quote_level, hidden.list_marker_level, hidden.prefix, "\\i0\\cf1\\par\n", quote_trimmed, refs);
                list_context = false;
                lazy_blockquote_level = quote_line.level;
                lazy_list_level = 0;
                continue;
            }
        }

        const line_trimmed_start = std.mem.trimStart(u8, line, " \t");
        if (parseBlockquote(line_trimmed_start)) |quote_line| {
            const quote = quote_line.content;
            const quote_indent = blockquoteDisplayIndent(quote);
            const quote_trimmed = std.mem.trim(u8, quote, " \t");
            const quote_text = std.mem.trimStart(u8, quote, " \t");
            if (listContinuationBlockStart(line, list_context)) {
                const indent = listIndentLevel(line);
                var prefix: std.ArrayList(u8) = .empty;
                defer prefix.deinit(allocator);
                try appendRtfBlockquotePrefix(&prefix, allocator, quote_line.level, indent);
                try out.appendSlice(allocator, prefix.items);
                if (quote_trimmed.len != 0) try appendInlineRtf(&out, allocator, quote_trimmed, refs);
                try out.appendSlice(allocator, "\\i0\\cf1\\par\n");
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            if (quote_trimmed.len == 0) {
                const prefix = try buildRtfBlockquotePrefix(allocator, quote_line.level, 0, "");
                defer allocator.free(prefix);
                try out.appendSlice(allocator, prefix);
                try out.appendSlice(allocator, "\\i0\\cf1\\par\n");
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            if (parseOpeningCodeFence(quote_trimmed)) |fence| {
                const container = ActiveContainerFence{
                    .fence = fence,
                    .kind = .blockquote,
                    .quote_level = quote_line.level,
                    .indent_level = quote_indent,
                };
                try appendRtfContainerFenceOpen(&out, allocator, container);
                active_container_fence = container;
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            if (headingLevel(quote_trimmed)) |level| {
                const prefix = try buildRtfBlockquotePrefix(allocator, quote_line.level, quote_indent, "");
                defer allocator.free(prefix);
                try appendRtfContainerHeading(&out, allocator, prefix, "\\i0\\cf1\\par\n", atxHeadingTitle(quote_trimmed, level), level, refs);
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            if (isHorizontalRule(quote_trimmed)) {
                const prefix = try buildRtfBlockquotePrefix(allocator, quote_line.level, quote_indent, "");
                defer allocator.free(prefix);
                try appendRtfContainerThematicBreak(&out, allocator, prefix, "\\i0\\cf1\\par\n");
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            const quote_html_continues_paragraph = if (containerHtmlBlockStart(quote_trimmed)) |block|
                !block.interrupts_paragraph and (lazy_blockquote_level == quote_line.level or quote_indent > 0)
            else
                false;
            if (isHtmlBlockLine(quote_trimmed) and !quote_html_continues_paragraph) {
                const container = ActiveContainerHtml{
                    .block = containerHtmlBlockStart(quote_trimmed) orelse .{ .end_tag = "", .end_on_blank = false },
                    .kind = .blockquote,
                    .quote_level = quote_line.level,
                    .indent_level = 0,
                };
                try appendRtfContainerHtmlRaw(&out, allocator, container, quote_trimmed);
                if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(quote_trimmed, container.block)) active_container_html = container;
                list_context = false;
                lazy_blockquote_level = 0;
                lazy_list_level = 0;
                continue;
            }
            if (unorderedListText(quote_text)) |quote_item| {
                const prefix = try buildRtfBlockquotePrefix(allocator, quote_line.level, quote_indent, "\\bullet\\tab ");
                defer allocator.free(prefix);
                if (parseOpeningCodeFence(quote_item)) |fence| {
                    const container = ActiveContainerFence{
                        .fence = fence,
                        .kind = .blockquote,
                        .quote_level = quote_line.level,
                        .indent_level = quote_indent + 1,
                    };
                    try appendRtfContainerFenceOpenWithPrefix(&out, allocator, prefix, "\\i0\\cf1\\par\n");
                    active_container_fence = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (headingLevel(quote_item)) |level| {
                    try appendRtfContainerHeading(&out, allocator, prefix, "\\i0\\cf1\\par\n", atxHeadingTitle(quote_item, level), level, refs);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHorizontalRule(quote_item)) {
                    try appendRtfContainerThematicBreak(&out, allocator, prefix, "\\i0\\cf1\\par\n");
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHtmlBlockLine(quote_item)) {
                    const container = ActiveContainerHtml{
                        .block = containerHtmlBlockStart(quote_item) orelse .{ .end_tag = "", .end_on_blank = false },
                        .kind = .blockquote,
                        .quote_level = quote_line.level,
                        .indent_level = quote_indent + 1,
                    };
                    try out.appendSlice(allocator, prefix);
                    try appendRtfEscaped(&out, allocator, quote_item);
                    try out.appendSlice(allocator, "\\i0\\cf1\\par\n");
                    if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(quote_item, container.block)) active_container_html = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .blockquote, quote_line.level, listMarkerDisplayLevel(quote, true), prefix, "\\i0\\cf1\\par\n", quote_item, refs);
                markPendingOrderedStartGuard(&pending_container, true);
            } else if (orderedListText(quote_text)) |quote_item| {
                const marker = try allocRtfOrderedMarker(allocator, quote_text);
                defer allocator.free(marker);
                const prefix = try buildRtfBlockquotePrefix(allocator, quote_line.level, quote_indent, marker);
                defer allocator.free(prefix);
                if (parseOpeningCodeFence(quote_item)) |fence| {
                    const container = ActiveContainerFence{
                        .fence = fence,
                        .kind = .blockquote,
                        .quote_level = quote_line.level,
                        .indent_level = quote_indent + 1,
                    };
                    try appendRtfContainerFenceOpenWithPrefix(&out, allocator, prefix, "\\i0\\cf1\\par\n");
                    active_container_fence = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (headingLevel(quote_item)) |level| {
                    try appendRtfContainerHeading(&out, allocator, prefix, "\\i0\\cf1\\par\n", atxHeadingTitle(quote_item, level), level, refs);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHorizontalRule(quote_item)) {
                    try appendRtfContainerThematicBreak(&out, allocator, prefix, "\\i0\\cf1\\par\n");
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHtmlBlockLine(quote_item)) {
                    const container = ActiveContainerHtml{
                        .block = containerHtmlBlockStart(quote_item) orelse .{ .end_tag = "", .end_on_blank = false },
                        .kind = .blockquote,
                        .quote_level = quote_line.level,
                        .indent_level = quote_indent + 1,
                    };
                    try out.appendSlice(allocator, prefix);
                    try appendRtfEscaped(&out, allocator, quote_item);
                    try out.appendSlice(allocator, "\\i0\\cf1\\par\n");
                    if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(quote_item, container.block)) active_container_html = container;
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .blockquote, quote_line.level, listMarkerDisplayLevel(quote, true), prefix, "\\i0\\cf1\\par\n", quote_item, refs);
                markPendingOrderedStartGuard(&pending_container, true);
            } else {
                const prefix = try buildRtfBlockquotePrefix(allocator, quote_line.level, quote_indent, "");
                defer allocator.free(prefix);
                _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .blockquote, quote_line.level, null, prefix, "\\i0\\cf1\\par\n", quote_text, refs);
                markPendingOrderedStartGuard(&pending_container, false);
            }
            list_context = false;
            lazy_blockquote_level = if (isLazyBlockquoteParagraphSeed(quote, quote_trimmed)) quote_line.level else 0;
            lazy_list_level = 0;
            continue;
        }

        if (unorderedListText(std.mem.trimStart(u8, line, " \t"))) |text| {
            const list_level = listMarkerDisplayLevel(line, list_context);
            if (parseOpeningCodeFence(text)) |fence| {
                const container = ActiveContainerFence{
                    .fence = fence,
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = list_level + 1,
                };
                const prefix = try buildRtfListPrefix(allocator, list_level, false, "\\bullet\\tab ");
                defer allocator.free(prefix);
                try appendRtfContainerFenceOpenWithPrefix(&out, allocator, prefix, "\\par\n");
                active_container_fence = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (headingLevel(text)) |level| {
                const prefix = try buildRtfListPrefix(allocator, list_level, false, "\\bullet\\tab ");
                defer allocator.free(prefix);
                try appendRtfContainerHeading(&out, allocator, prefix, "\\par\n", atxHeadingTitle(text, level), level, refs);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (isHorizontalRule(text)) {
                const prefix = try buildRtfListPrefix(allocator, list_level, false, "\\bullet\\tab ");
                defer allocator.free(prefix);
                try appendRtfContainerThematicBreak(&out, allocator, prefix, "\\par\n");
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (isHtmlBlockLine(text)) {
                const container = ActiveContainerHtml{
                    .block = containerHtmlBlockStart(text) orelse .{ .end_tag = "", .end_on_blank = false },
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = list_level + 1,
                };
                const prefix = try buildRtfListPrefix(allocator, list_level, false, "\\bullet\\tab ");
                defer allocator.free(prefix);
                try out.appendSlice(allocator, prefix);
                try appendRtfEscaped(&out, allocator, text);
                try out.appendSlice(allocator, "\\par\n");
                if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(text, container.block)) active_container_html = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            var prefix_marker: []const u8 = "\\bullet\\tab ";
            var item_text = text;
            if (taskItem(text)) |task| {
                prefix_marker = if (task.checked) "\\u9745?\\tab " else "\\u9744?\\tab ";
                item_text = task.text;
            }
            const prefix = try buildRtfListPrefix(allocator, list_level, false, prefix_marker);
            defer allocator.free(prefix);
            _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .list, 0, list_level, prefix, "\\par\n", item_text, refs);
            list_context = true;
            lazy_blockquote_level = 0;
            lazy_list_level = list_level + 1;
            continue;
        }

        if (orderedListText(std.mem.trimStart(u8, line, " \t"))) |text| {
            const list_level = listMarkerDisplayLevel(line, list_context);
            if (parseOpeningCodeFence(text)) |fence| {
                const container = ActiveContainerFence{
                    .fence = fence,
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = list_level + 1,
                };
                const marker = try allocRtfOrderedMarker(allocator, trimmed);
                defer allocator.free(marker);
                const prefix = try buildRtfListPrefix(allocator, list_level, true, marker);
                defer allocator.free(prefix);
                try appendRtfContainerFenceOpenWithPrefix(&out, allocator, prefix, "\\par\n");
                active_container_fence = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (headingLevel(text)) |level| {
                const marker = try allocRtfOrderedMarker(allocator, trimmed);
                defer allocator.free(marker);
                const prefix = try buildRtfListPrefix(allocator, list_level, true, marker);
                defer allocator.free(prefix);
                try appendRtfContainerHeading(&out, allocator, prefix, "\\par\n", atxHeadingTitle(text, level), level, refs);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (isHorizontalRule(text)) {
                const marker = try allocRtfOrderedMarker(allocator, trimmed);
                defer allocator.free(marker);
                const prefix = try buildRtfListPrefix(allocator, list_level, true, marker);
                defer allocator.free(prefix);
                try appendRtfContainerThematicBreak(&out, allocator, prefix, "\\par\n");
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            if (isHtmlBlockLine(text)) {
                const container = ActiveContainerHtml{
                    .block = containerHtmlBlockStart(text) orelse .{ .end_tag = "", .end_on_blank = false },
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = list_level + 1,
                };
                const marker = try allocRtfOrderedMarker(allocator, trimmed);
                defer allocator.free(marker);
                const prefix = try buildRtfListPrefix(allocator, list_level, true, marker);
                defer allocator.free(prefix);
                try out.appendSlice(allocator, prefix);
                try appendRtfEscaped(&out, allocator, text);
                try out.appendSlice(allocator, "\\par\n");
                if (htmlBlockCanContinue(container.block) and !htmlBlockEndsOnLine(text, container.block)) active_container_html = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = list_level + 1;
                continue;
            }
            const marker = try allocRtfOrderedMarker(allocator, trimmed);
            defer allocator.free(marker);
            const prefix = try buildRtfListPrefix(allocator, list_level, true, marker);
            defer allocator.free(prefix);
            _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .list, 0, list_level, prefix, "\\par\n", text, refs);
            list_context = true;
            lazy_blockquote_level = 0;
            lazy_list_level = list_level + 1;
            continue;
        }

        if (hidden_list_prefix) |hidden| {
            if (hidden.in_blockquote) {
                const quote_line = parseBlockquote(trimmed).?;
                const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
                defer {
                    allocator.free(hidden.prefix);
                    hidden_list_prefix = null;
                }
                if (headingLevel(quote_trimmed)) |level| {
                    try appendRtfContainerHeading(&out, allocator, hidden.prefix, "\\i0\\cf1\\par\n", atxHeadingTitle(quote_trimmed, level), level, refs);
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                if (isHorizontalRule(quote_trimmed)) {
                    try appendRtfContainerThematicBreak(&out, allocator, hidden.prefix, "\\i0\\cf1\\par\n");
                    list_context = false;
                    lazy_blockquote_level = 0;
                    lazy_list_level = 0;
                    continue;
                }
                _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .blockquote, hidden.quote_level, hidden.list_marker_level, hidden.prefix, "\\i0\\cf1\\par\n", quote_trimmed, refs);
                list_context = false;
                lazy_blockquote_level = quote_line.level;
                lazy_list_level = 0;
                continue;
            } else if (listIndentLevel(line) > 0) {
                defer {
                    allocator.free(hidden.prefix);
                    hidden_list_prefix = null;
                }
                const indent = listIndentLevel(line);
                if (parseOpeningCodeFence(trimmed)) |fence| {
                    const container = ActiveContainerFence{
                        .fence = fence,
                        .kind = .list,
                        .quote_level = 0,
                        .indent_level = indent,
                    };
                    try appendRtfContainerFenceOpenWithPrefix(&out, allocator, hidden.prefix, "\\par\n");
                    active_container_fence = container;
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                if (headingLevel(trimmed)) |level| {
                    try appendRtfContainerHeading(&out, allocator, hidden.prefix, "\\par\n", atxHeadingTitle(trimmed, level), level, refs);
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                if (isHorizontalRule(trimmed)) {
                    try appendRtfContainerThematicBreak(&out, allocator, hidden.prefix, "\\par\n");
                    list_context = true;
                    lazy_blockquote_level = 0;
                    lazy_list_level = indent;
                    continue;
                }
                _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .list, 0, hidden.list_marker_level, hidden.prefix, "\\par\n", trimmed, refs);
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            } else {
                allocator.free(hidden.prefix);
                hidden_list_prefix = null;
            }
        }

        if (listIndentLevel(line) > 0) {
            const indent = listIndentLevel(line);
            var prefix: std.ArrayList(u8) = .empty;
            defer prefix.deinit(allocator);
            try appendRtfContinuationPrefix(&prefix, allocator, indent);
            const active_list_level = activeListLevelForIndentedContinuation(list_context, lazy_list_level);
            if (active_list_level > 0) {
                if (listIndentedCodeText(line, active_list_level)) |code_text| {
                    var code_prefix: std.ArrayList(u8) = .empty;
                    defer code_prefix.deinit(allocator);
                    try appendRtfContinuationPrefix(&code_prefix, allocator, active_list_level);
                    try out.appendSlice(allocator, code_prefix.items);
                    try out.appendSlice(allocator, "\\f1\\fs20\\cf2 ");
                    if (code_text.len == 0) {
                        try out.appendSlice(allocator, "\\~");
                    } else {
                        try appendRtfEscaped(&out, allocator, code_text);
                    }
                    try out.appendSlice(allocator, "\\par\n");
                    list_context = true;
                    lazy_blockquote_level = 0;
                    continue;
                }
            }
            if (parseOpeningCodeFence(trimmed)) |fence| {
                const container = ActiveContainerFence{
                    .fence = fence,
                    .kind = .list,
                    .quote_level = 0,
                    .indent_level = indent,
                };
                try appendRtfContainerFenceOpenWithPrefix(&out, allocator, prefix.items, "\\par\n");
                active_container_fence = container;
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            if (isHorizontalRule(trimmed)) {
                try appendRtfContainerThematicBreak(&out, allocator, prefix.items, "\\par\n");
                list_context = true;
                lazy_blockquote_level = 0;
                lazy_list_level = indent;
                continue;
            }
            _ = try queueOrAppendRtfContainer(&out, allocator, &pending_container, .list, 0, null, prefix.items, "\\par\n", trimmed, refs);
            list_context = true;
            lazy_blockquote_level = 0;
            lazy_list_level = indent;
            continue;
        }

        const paragraph = paragraphLine(line, trimmed);
        pending_plain = paragraph.text;
        pending_heading_plain = paragraph.heading_text;
        pending_hard_break = paragraph.hard_break;
        list_context = false;
        lazy_blockquote_level = 0;
        lazy_list_level = 0;
    }

    if (pending_container != null) {
        try flushPendingRtfContainer(&out, allocator, &pending_container, refs);
    }

    if (pending_plain) |pending| {
        try out.appendSlice(allocator, "\\pard\\sa110\\f0\\fs22\\cf1 ");
        try appendInlineRtf(&out, allocator, pending, refs);
        try out.appendSlice(allocator, "\\par\n");
    }

    try out.appendSlice(allocator, "}\n");
    return out.toOwnedSlice(allocator);
}

fn appendLine(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    try out.appendSlice(allocator, text);
    try out.append(allocator, '\n');
}

fn appendPlainHeading(out: *std.ArrayList(u8), allocator: std.mem.Allocator, title: []const u8, level: usize, refs: []const ReferenceDef) !void {
    if (level == 1) {
        try out.appendSlice(allocator, "\n== ");
        try appendInline(out, allocator, title, refs);
        try out.appendSlice(allocator, " ==\n");
    } else {
        try out.appendSlice(allocator, "\n-- ");
        try appendInline(out, allocator, title, refs);
        try out.appendSlice(allocator, " --\n");
    }
}

fn appendRtfHeading(out: *std.ArrayList(u8), allocator: std.mem.Allocator, title: []const u8, level: usize, refs: []const ReferenceDef) !void {
    const size = if (level == 1) "44" else "36";
    try out.appendSlice(allocator, "\\pard\\sb220\\sa120\\f0\\cf1\\b\\fs");
    try out.appendSlice(allocator, size);
    try out.append(allocator, ' ');
    try appendRtfHeadingInline(out, allocator, title, size, refs);
    try out.appendSlice(allocator, "\\b0\\fs22\\par\n");
}

fn appendPlainContainerHeading(out: *std.ArrayList(u8), allocator: std.mem.Allocator, prefix: []const u8, title: []const u8, level: usize, refs: []const ReferenceDef) !void {
    try out.appendSlice(allocator, prefix);
    if (level == 1) {
        try out.appendSlice(allocator, "== ");
        try appendInline(out, allocator, title, refs);
        try out.appendSlice(allocator, " ==");
    } else if (level == 2) {
        try out.appendSlice(allocator, "-- ");
        try appendInline(out, allocator, title, refs);
        try out.appendSlice(allocator, " --");
    } else {
        try appendInline(out, allocator, title, refs);
    }
    try out.append(allocator, '\n');
}

fn appendRtfContainerHeading(out: *std.ArrayList(u8), allocator: std.mem.Allocator, prefix: []const u8, suffix: []const u8, title: []const u8, level: usize, refs: []const ReferenceDef) !void {
    const size = switch (level) {
        1 => "44",
        2 => "36",
        3 => "30",
        4 => "26",
        else => "24",
    };
    try out.appendSlice(allocator, prefix);
    try out.appendSlice(allocator, "\\b\\fs");
    try out.appendSlice(allocator, size);
    try out.append(allocator, ' ');
    try appendRtfHeadingInline(out, allocator, title, size, refs);
    try out.appendSlice(allocator, "\\b0\\fs22");
    try out.appendSlice(allocator, suffix);
}

fn appendRtfHeadingInline(out: *std.ArrayList(u8), allocator: std.mem.Allocator, title: []const u8, size: []const u8, refs: []const ReferenceDef) !void {
    var rendered: std.ArrayList(u8) = .empty;
    defer rendered.deinit(allocator);

    try appendInlineRtf(&rendered, allocator, title, refs);
    try appendRtfHeadingInlineRestored(out, allocator, rendered.items, size);
}

fn appendRtfHeadingInlineRestored(out: *std.ArrayList(u8), allocator: std.mem.Allocator, rendered: []const u8, size: []const u8) !void {
    var i: usize = 0;
    while (i < rendered.len) {
        if (std.mem.startsWith(u8, rendered[i..], "\\f1\\fs20\\highlight4 ")) {
            try out.appendSlice(allocator, "\\f1\\fs");
            try out.appendSlice(allocator, size);
            try out.appendSlice(allocator, "\\highlight4 ");
            i += "\\f1\\fs20\\highlight4 ".len;
            continue;
        }

        if (std.mem.startsWith(u8, rendered[i..], "\\highlight0\\f0\\fs22 ")) {
            try appendRtfHeadingRestore(out, allocator, "\\highlight0", size);
            i += "\\highlight0\\f0\\fs22 ".len;
            continue;
        }

        if (std.mem.startsWith(u8, rendered[i..], "\\ulnone\\cf1 ")) {
            try appendRtfHeadingRestore(out, allocator, "\\ulnone", size);
            i += "\\ulnone\\cf1 ".len;
            continue;
        }

        if (std.mem.startsWith(u8, rendered[i..], "\\i0\\b0 ")) {
            try appendRtfHeadingRestore(out, allocator, "\\i0", size);
            i += "\\i0\\b0 ".len;
            continue;
        }

        if (std.mem.startsWith(u8, rendered[i..], "\\b0 ")) {
            try appendRtfHeadingRestore(out, allocator, "", size);
            i += "\\b0 ".len;
            continue;
        }

        try out.append(allocator, rendered[i]);
        i += 1;
    }
}

fn appendRtfHeadingRestore(out: *std.ArrayList(u8), allocator: std.mem.Allocator, prefix: []const u8, size: []const u8) !void {
    try out.appendSlice(allocator, prefix);
    if (prefix.len > 0) try out.append(allocator, ' ');
    try out.appendSlice(allocator, "\\f0\\cf1\\b\\fs");
    try out.appendSlice(allocator, size);
    try out.append(allocator, ' ');
}

fn appendPlainContainerThematicBreak(out: *std.ArrayList(u8), allocator: std.mem.Allocator, prefix: []const u8) !void {
    try out.appendSlice(allocator, prefix);
    try out.appendSlice(allocator, "---\n");
}

fn appendRtfContainerThematicBreak(out: *std.ArrayList(u8), allocator: std.mem.Allocator, prefix: []const u8, suffix: []const u8) !void {
    try out.appendSlice(allocator, prefix);
    try appendRtfEscaped(out, allocator, "------------------------------");
    try out.appendSlice(allocator, suffix);
}

fn containerFenceContent(container: ActiveContainerFence, line: []const u8, trimmed: []const u8) ?[]const u8 {
    switch (container.kind) {
        .blockquote => {
            const quote_line = parseBlockquote(trimmed) orelse return null;
            if (quote_line.level != container.quote_level) return null;
            return std.mem.trim(u8, quote_line.content, " \t");
        },
        .list => {
            if (trimmed.len == 0) return "";
            if (listIndentLevel(line) == 0) return null;
            return trimmed;
        },
    }
}

fn containerOpeningCodeFenceForScan(line: []const u8, trimmed: []const u8) ?ActiveContainerFence {
    if (parseBlockquote(trimmed)) |quote_line| {
        const quote = quote_line.content;
        const quote_trimmed = std.mem.trim(u8, quote, " \t");
        const quote_indent = listIndentLevel(quote);
        if (parseOpeningCodeFence(quote_trimmed)) |fence| {
            return .{
                .fence = fence,
                .kind = .blockquote,
                .quote_level = quote_line.level,
                .indent_level = quote_indent,
            };
        }
        if (unorderedListText(quote_trimmed)) |quote_item| {
            if (parseOpeningCodeFence(quote_item)) |fence| {
                return .{
                    .fence = fence,
                    .kind = .blockquote,
                    .quote_level = quote_line.level,
                    .indent_level = quote_indent + 1,
                };
            }
        }
        if (orderedListText(quote_trimmed)) |quote_item| {
            if (parseOpeningCodeFence(quote_item)) |fence| {
                return .{
                    .fence = fence,
                    .kind = .blockquote,
                    .quote_level = quote_line.level,
                    .indent_level = quote_indent + 1,
                };
            }
        }
    }

    if (unorderedListText(trimmed)) |item| {
        if (parseOpeningCodeFence(item)) |fence| {
            return .{
                .fence = fence,
                .kind = .list,
                .quote_level = 0,
                .indent_level = listMarkerDisplayLevel(line, false) + 1,
            };
        }
    }

    if (orderedListText(trimmed)) |item| {
        if (parseOpeningCodeFence(item)) |fence| {
            return .{
                .fence = fence,
                .kind = .list,
                .quote_level = 0,
                .indent_level = listMarkerDisplayLevel(line, false) + 1,
            };
        }
    }

    return null;
}

fn containerOpeningHtmlBlockForScan(line: []const u8, trimmed: []const u8) ?ActiveContainerHtmlOpen {
    if (parseBlockquote(trimmed)) |quote_line| {
        const quote = quote_line.content;
        const quote_trimmed = std.mem.trim(u8, quote, " \t");
        const quote_indent = listIndentLevel(quote);
        if (containerHtmlBlockStart(quote_trimmed)) |block| {
            if (isHtmlBlockLine(quote_trimmed)) {
                return .{
                    .container = .{
                        .block = block,
                        .kind = .blockquote,
                        .quote_level = quote_line.level,
                        .indent_level = 0,
                    },
                    .content = quote_trimmed,
                };
            }
        }
        if (unorderedListText(quote_trimmed)) |quote_item| {
            if (containerHtmlBlockStart(quote_item)) |block| {
                if (isHtmlBlockLine(quote_item)) {
                    return .{
                        .container = .{
                            .block = block,
                            .kind = .blockquote,
                            .quote_level = quote_line.level,
                            .indent_level = quote_indent + 1,
                        },
                        .content = quote_item,
                    };
                }
            }
        }
        if (orderedListText(quote_trimmed)) |quote_item| {
            if (containerHtmlBlockStart(quote_item)) |block| {
                if (isHtmlBlockLine(quote_item)) {
                    return .{
                        .container = .{
                            .block = block,
                            .kind = .blockquote,
                            .quote_level = quote_line.level,
                            .indent_level = quote_indent + 1,
                        },
                        .content = quote_item,
                    };
                }
            }
        }
    }

    if (unorderedListText(trimmed)) |item| {
        if (containerHtmlBlockStart(item)) |block| {
            if (isHtmlBlockLine(item)) {
                return .{
                    .container = .{
                        .block = block,
                        .kind = .list,
                        .quote_level = 0,
                        .indent_level = listMarkerDisplayLevel(line, false) + 1,
                    },
                    .content = item,
                };
            }
        }
    }

    if (orderedListText(trimmed)) |item| {
        if (containerHtmlBlockStart(item)) |block| {
            if (isHtmlBlockLine(item)) {
                return .{
                    .container = .{
                        .block = block,
                        .kind = .list,
                        .quote_level = 0,
                        .indent_level = listMarkerDisplayLevel(line, false) + 1,
                    },
                    .content = item,
                };
            }
        }
    }

    return null;
}

fn appendPlainContainerFenceOpen(out: *std.ArrayList(u8), allocator: std.mem.Allocator, container: ActiveContainerFence) !void {
    try appendPlainContainerFenceLinePrefix(out, allocator, container);
    try out.appendSlice(allocator, "---- code ----\n");
}

fn appendPlainContainerFenceOpenWithPrefix(out: *std.ArrayList(u8), allocator: std.mem.Allocator, prefix: []const u8) !void {
    try out.appendSlice(allocator, prefix);
    try out.appendSlice(allocator, "---- code ----\n");
}

fn appendPlainContainerFenceContent(out: *std.ArrayList(u8), allocator: std.mem.Allocator, container: ActiveContainerFence, content: []const u8) !void {
    try appendPlainContainerFenceLinePrefix(out, allocator, container);
    try out.appendSlice(allocator, "    ");
    try out.appendSlice(allocator, content);
    try out.append(allocator, '\n');
}

fn appendPlainContainerFenceClose(out: *std.ArrayList(u8), allocator: std.mem.Allocator, container: ActiveContainerFence) !void {
    try appendPlainContainerFenceLinePrefix(out, allocator, container);
    try out.appendSlice(allocator, "--------------\n");
}

fn appendPlainContainerFenceLinePrefix(out: *std.ArrayList(u8), allocator: std.mem.Allocator, container: ActiveContainerFence) !void {
    switch (container.kind) {
        .blockquote => {
            try appendPlainBlockquotePrefix(out, allocator, container.quote_level);
            try appendPlainListIndent(out, allocator, container.indent_level);
        },
        .list => try appendPlainListIndent(out, allocator, container.indent_level),
    }
}

fn appendRtfContainerFenceOpen(out: *std.ArrayList(u8), allocator: std.mem.Allocator, container: ActiveContainerFence) !void {
    try appendRtfContainerFenceLinePrefix(out, allocator, container);
    try out.appendSlice(allocator, "\\i0\\f1\\fs20\\cf2 ");
    try appendRtfEscaped(out, allocator, "---- code ----");
    try out.appendSlice(allocator, "\\par\n");
}

fn appendRtfContainerFenceOpenWithPrefix(out: *std.ArrayList(u8), allocator: std.mem.Allocator, prefix: []const u8, suffix: []const u8) !void {
    try out.appendSlice(allocator, prefix);
    try out.appendSlice(allocator, "\\i0\\f1\\fs20\\cf2 ");
    try appendRtfEscaped(out, allocator, "---- code ----");
    try out.appendSlice(allocator, suffix);
}

fn appendRtfContainerFenceContent(out: *std.ArrayList(u8), allocator: std.mem.Allocator, container: ActiveContainerFence, content: []const u8) !void {
    try appendRtfContainerFenceLinePrefix(out, allocator, container);
    try out.appendSlice(allocator, "\\i0\\f1\\fs20\\cf2 ");
    try appendRtfEscaped(out, allocator, content);
    try out.appendSlice(allocator, "\\par\n");
}

fn appendRtfContainerFenceClose(out: *std.ArrayList(u8), allocator: std.mem.Allocator, container: ActiveContainerFence) !void {
    try appendRtfContainerFenceLinePrefix(out, allocator, container);
    try out.appendSlice(allocator, "\\i0\\f1\\fs20\\cf2 ");
    try appendRtfEscaped(out, allocator, "--------------");
    try out.appendSlice(allocator, "\\par\n");
}

fn appendRtfContainerFenceLinePrefix(out: *std.ArrayList(u8), allocator: std.mem.Allocator, container: ActiveContainerFence) !void {
    switch (container.kind) {
        .blockquote => try appendRtfBlockquotePrefix(out, allocator, container.quote_level, container.indent_level),
        .list => try appendRtfContinuationPrefix(out, allocator, container.indent_level),
    }
}

fn containerHtmlBlockStart(line: []const u8) ?HtmlBlock {
    if (isHtmlCommentStart(line)) return .{ .end_tag = "-->", .end_on_blank = false };
    if (isHtmlCdataStart(line)) return .{ .end_tag = "]]>", .end_on_blank = false };
    return htmlBlockStart(line);
}

fn htmlBlockCanContinue(block: HtmlBlock) bool {
    return block.end_on_blank or block.end_tag.len != 0;
}

fn containerHtmlContent(container: ActiveContainerHtml, line: []const u8, trimmed: []const u8) ?[]const u8 {
    switch (container.kind) {
        .blockquote => {
            const quote_line = parseBlockquote(trimmed) orelse return null;
            if (quote_line.level != container.quote_level) return null;
            return std.mem.trim(u8, quote_line.content, " \t");
        },
        .list => {
            if (trimmed.len == 0) return "";
            if (listIndentLevel(line) == 0) return null;
            return trimmed;
        },
    }
}

fn appendPlainContainerHtmlRaw(out: *std.ArrayList(u8), allocator: std.mem.Allocator, container: ActiveContainerHtml, content: []const u8) !void {
    switch (container.kind) {
        .blockquote => {
            try appendPlainBlockquotePrefix(out, allocator, container.quote_level);
            try appendPlainListIndent(out, allocator, container.indent_level);
            try out.appendSlice(allocator, content);
        },
        .list => {
            try appendPlainListIndent(out, allocator, container.indent_level);
            try out.appendSlice(allocator, content);
        },
    }
    try out.append(allocator, '\n');
}

fn appendRtfContainerHtmlRaw(out: *std.ArrayList(u8), allocator: std.mem.Allocator, container: ActiveContainerHtml, content: []const u8) !void {
    switch (container.kind) {
        .blockquote => {
            try appendRtfBlockquotePrefix(out, allocator, container.quote_level, container.indent_level);
            try appendRtfEscaped(out, allocator, content);
            try out.appendSlice(allocator, "\\i0\\cf1\\par\n");
        },
        .list => {
            try appendRtfContinuationPrefix(out, allocator, container.indent_level);
            try appendRtfEscaped(out, allocator, content);
            try out.appendSlice(allocator, "\\par\n");
        },
    }
}

fn freePendingContainer(allocator: std.mem.Allocator, pending: *?PendingContainer) void {
    if (pending.*) |current| {
        allocator.free(current.prefix);
        allocator.free(current.text);
        allocator.free(current.heading_text);
        if (current.fallback) |fallback| allocator.free(fallback);
        pending.* = null;
    }
}

fn buildPlainListPrefix(allocator: std.mem.Allocator, level: usize, marker: []const u8) ![]u8 {
    var prefix: std.ArrayList(u8) = .empty;
    errdefer prefix.deinit(allocator);
    try appendPlainListIndent(&prefix, allocator, level);
    try prefix.appendSlice(allocator, marker);
    return prefix.toOwnedSlice(allocator);
}

fn buildPlainBlockquotePrefix(allocator: std.mem.Allocator, level: usize, indent: usize, marker: []const u8) ![]u8 {
    var prefix: std.ArrayList(u8) = .empty;
    errdefer prefix.deinit(allocator);
    try appendPlainBlockquotePrefix(&prefix, allocator, level);
    try appendPlainListIndent(&prefix, allocator, indent);
    try prefix.appendSlice(allocator, marker);
    return prefix.toOwnedSlice(allocator);
}

fn buildRtfListPrefix(allocator: std.mem.Allocator, level: usize, ordered: bool, marker: []const u8) ![]u8 {
    var prefix: std.ArrayList(u8) = .empty;
    errdefer prefix.deinit(allocator);
    try appendRtfListPrefix(&prefix, allocator, level, ordered, marker);
    try prefix.appendSlice(allocator, marker);
    return prefix.toOwnedSlice(allocator);
}

fn referenceDefinitionSeed(text: []const u8) bool {
    const trimmed = std.mem.trim(u8, text, " \t");
    return referenceDefinition(trimmed) != null or referenceDefinitionStart(trimmed) != null;
}

fn hiddenPlainListReferencePrefix(
    allocator: std.mem.Allocator,
    line: []const u8,
    trimmed: []const u8,
    list_context: bool,
) !?HiddenListPrefix {
    if (parseBlockquote(trimmed)) |quote_line| {
        const quote = quote_line.content;
        const quote_trimmed = std.mem.trim(u8, quote, " \t");
        const quote_indent = blockquoteDisplayIndent(quote);
        if (unorderedListText(quote_trimmed)) |text| {
            if (!referenceDefinitionSeed(text)) return null;
            return .{
                .prefix = try buildPlainBlockquotePrefix(allocator, quote_line.level, quote_indent, "* "),
                .in_blockquote = true,
                .quote_level = quote_line.level,
                .list_marker_level = listMarkerDisplayLevel(quote, true),
            };
        }
        if (orderedListText(quote_trimmed)) |text| {
            if (!referenceDefinitionSeed(text)) return null;
            const marker = try std.fmt.allocPrint(allocator, "{s} ", .{orderedMarker(quote_trimmed)});
            defer allocator.free(marker);
            return .{
                .prefix = try buildPlainBlockquotePrefix(allocator, quote_line.level, quote_indent, marker),
                .in_blockquote = true,
                .quote_level = quote_line.level,
                .list_marker_level = listMarkerDisplayLevel(quote, true),
            };
        }
    }
    if (unorderedListText(trimmed)) |text| {
        if (!referenceDefinitionSeed(text)) return null;
        const list_level = listMarkerDisplayLevel(line, list_context);
        return .{ .prefix = try buildPlainListPrefix(allocator, list_level, "* "), .list_marker_level = list_level };
    }
    if (orderedListText(trimmed)) |text| {
        if (!referenceDefinitionSeed(text)) return null;
        const marker = try std.fmt.allocPrint(allocator, "{s} ", .{orderedMarker(trimmed)});
        defer allocator.free(marker);
        const list_level = listMarkerDisplayLevel(line, list_context);
        return .{ .prefix = try buildPlainListPrefix(allocator, list_level, marker), .list_marker_level = list_level };
    }
    return null;
}

fn hiddenRtfListReferencePrefix(
    allocator: std.mem.Allocator,
    line: []const u8,
    trimmed: []const u8,
    list_context: bool,
) !?HiddenListPrefix {
    if (parseBlockquote(trimmed)) |quote_line| {
        const quote = quote_line.content;
        const quote_trimmed = std.mem.trim(u8, quote, " \t");
        const quote_indent = blockquoteDisplayIndent(quote);
        if (unorderedListText(quote_trimmed)) |text| {
            if (!referenceDefinitionSeed(text)) return null;
            return .{
                .prefix = try buildRtfBlockquotePrefix(allocator, quote_line.level, quote_indent, "\\bullet\\tab "),
                .in_blockquote = true,
                .quote_level = quote_line.level,
                .list_marker_level = listMarkerDisplayLevel(quote, true),
            };
        }
        if (orderedListText(quote_trimmed)) |text| {
            if (!referenceDefinitionSeed(text)) return null;
            const marker = try allocRtfOrderedMarker(allocator, quote_trimmed);
            defer allocator.free(marker);
            return .{
                .prefix = try buildRtfBlockquotePrefix(allocator, quote_line.level, quote_indent, marker),
                .in_blockquote = true,
                .quote_level = quote_line.level,
                .list_marker_level = listMarkerDisplayLevel(quote, true),
            };
        }
    }
    if (unorderedListText(trimmed)) |text| {
        if (!referenceDefinitionSeed(text)) return null;
        const list_level = listMarkerDisplayLevel(line, list_context);
        return .{ .prefix = try buildRtfListPrefix(allocator, list_level, false, "\\bullet\\tab "), .list_marker_level = list_level };
    }
    if (orderedListText(trimmed)) |text| {
        if (!referenceDefinitionSeed(text)) return null;
        const marker = try allocRtfOrderedMarker(allocator, trimmed);
        defer allocator.free(marker);
        const list_level = listMarkerDisplayLevel(line, list_context);
        return .{ .prefix = try buildRtfListPrefix(allocator, list_level, true, marker), .list_marker_level = list_level };
    }
    return null;
}

fn buildRtfBlockquotePrefix(allocator: std.mem.Allocator, level: usize, indent: usize, marker: []const u8) ![]u8 {
    var prefix: std.ArrayList(u8) = .empty;
    errdefer prefix.deinit(allocator);
    try appendRtfBlockquotePrefix(&prefix, allocator, level, indent);
    try prefix.appendSlice(allocator, marker);
    return prefix.toOwnedSlice(allocator);
}

fn queueOrAppendPlainContainer(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    pending: *?PendingContainer,
    kind: PendingContainerKind,
    quote_level: usize,
    list_marker_level: ?usize,
    prefix: []const u8,
    text: []const u8,
    refs: []const ReferenceDef,
) !bool {
    _ = out;
    const line = containerLine(text);
    const coalesce = true;
    var fallback: ?[]u8 = null;
    if (!coalesce) {
        var rendered: std.ArrayList(u8) = .empty;
        errdefer rendered.deinit(allocator);
        try rendered.appendSlice(allocator, prefix);
        try appendInline(&rendered, allocator, line.text, refs);
        try rendered.append(allocator, '\n');
        fallback = try rendered.toOwnedSlice(allocator);
    }
    freePendingContainer(allocator, pending);
    pending.* = .{
        .kind = kind,
        .quote_level = quote_level,
        .prefix = try allocator.dupe(u8, prefix),
        .suffix = "\n",
        .text = try allocator.dupe(u8, line.text),
        .heading_text = try allocator.dupe(u8, line.heading_text),
        .hard_break = line.hard_break,
        .coalesce_continuations = coalesce,
        .ordered_start_guard = kind == .list,
        .ordered_start_guard_requires_indent = kind == .list,
        .list_marker_level = list_marker_level,
        .fallback = fallback,
    };
    return true;
}

fn queueOrAppendRtfContainer(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    pending: *?PendingContainer,
    kind: PendingContainerKind,
    quote_level: usize,
    list_marker_level: ?usize,
    prefix: []const u8,
    suffix: []const u8,
    text: []const u8,
    refs: []const ReferenceDef,
) !bool {
    _ = out;
    const line = containerLine(text);
    const coalesce = true;
    var fallback: ?[]u8 = null;
    if (!coalesce) {
        var rendered: std.ArrayList(u8) = .empty;
        errdefer rendered.deinit(allocator);
        try rendered.appendSlice(allocator, prefix);
        try appendInlineRtf(&rendered, allocator, line.text, refs);
        try rendered.appendSlice(allocator, suffix);
        fallback = try rendered.toOwnedSlice(allocator);
    }
    freePendingContainer(allocator, pending);
    pending.* = .{
        .kind = kind,
        .quote_level = quote_level,
        .prefix = try allocator.dupe(u8, prefix),
        .suffix = suffix,
        .text = try allocator.dupe(u8, line.text),
        .heading_text = try allocator.dupe(u8, line.heading_text),
        .hard_break = line.hard_break,
        .coalesce_continuations = coalesce,
        .ordered_start_guard = kind == .list,
        .ordered_start_guard_requires_indent = kind == .list,
        .list_marker_level = list_marker_level,
        .fallback = fallback,
    };
    return true;
}

fn markPendingOrderedStartGuard(pending: *?PendingContainer, requires_indent: bool) void {
    if (pending.*) |*current| {
        current.ordered_start_guard = true;
        current.ordered_start_guard_requires_indent = requires_indent;
    }
}

fn consumePendingPlainContainerContinuation(
    allocator: std.mem.Allocator,
    pending: *?PendingContainer,
    line: []const u8,
    trimmed: []const u8,
    refs: []const ReferenceDef,
) !bool {
    if (pending.*) |*current| {
        if (containerContinuationLine(current.text, current.kind, current.quote_level, current.ordered_start_guard, current.ordered_start_guard_requires_indent, line, trimmed)) |continuation| {
            if (isSameOrOuterOrderedListMarker(current.*, line, trimmed)) return false;
            const guarded_ordered = isOrderedStartGuardedContainerContinuation(current.*, line, trimmed);
            if (!current.coalesce_continuations and guarded_ordered) {
                if (current.fallback) |fallback| {
                    allocator.free(fallback);
                    current.fallback = null;
                }
                current.coalesce_continuations = true;
            }
            if (!current.coalesce_continuations and !try appendPlainPendingFallbackContinuation(allocator, current, line, trimmed, refs)) {
                return false;
            }
            const separator = if (current.hard_break) "\n" else " ";
            const combined = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ current.text, separator, continuation.text });
            const heading_base = if (current.hard_break) current.text else current.heading_text;
            const heading_separator = if (current.hard_break) "\n" else " ";
            const heading_combined = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ heading_base, heading_separator, continuation.heading_text });
            allocator.free(current.text);
            allocator.free(current.heading_text);
            current.text = combined;
            current.heading_text = heading_combined;
            current.hard_break = continuation.hard_break;
            return true;
        }
    }

    return false;
}

fn consumePendingRtfContainerContinuation(
    allocator: std.mem.Allocator,
    pending: *?PendingContainer,
    line: []const u8,
    trimmed: []const u8,
    refs: []const ReferenceDef,
) !bool {
    if (pending.*) |*current| {
        if (containerContinuationLine(current.text, current.kind, current.quote_level, current.ordered_start_guard, current.ordered_start_guard_requires_indent, line, trimmed)) |continuation| {
            if (isSameOrOuterOrderedListMarker(current.*, line, trimmed)) return false;
            const guarded_ordered = isOrderedStartGuardedContainerContinuation(current.*, line, trimmed);
            if (!current.coalesce_continuations and guarded_ordered) {
                if (current.fallback) |fallback| {
                    allocator.free(fallback);
                    current.fallback = null;
                }
                current.coalesce_continuations = true;
            }
            if (!current.coalesce_continuations and !try appendRtfPendingFallbackContinuation(allocator, current, line, trimmed, refs)) {
                return false;
            }
            const separator = if (current.hard_break) "\n" else " ";
            const combined = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ current.text, separator, continuation.text });
            const heading_base = if (current.hard_break) current.text else current.heading_text;
            const heading_separator = if (current.hard_break) "\n" else " ";
            const heading_combined = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ heading_base, heading_separator, continuation.heading_text });
            allocator.free(current.text);
            allocator.free(current.heading_text);
            current.text = combined;
            current.heading_text = heading_combined;
            current.hard_break = continuation.hard_break;
            return true;
        }
    }

    return false;
}

fn isSameOrOuterOrderedListMarker(current: PendingContainer, line: []const u8, trimmed: []const u8) bool {
    const current_level = current.list_marker_level orelse return false;
    if (!current.ordered_start_guard) return false;

    switch (current.kind) {
        .list => {
            if (orderedListText(trimmed) == null or orderedListStartsAtOne(trimmed)) return false;
            return listMarkerDisplayLevel(line, true) <= current_level;
        },
        .blockquote => {
            if (parseBlockquote(trimmed)) |quote_line| {
                if (quote_line.level != current.quote_level) return false;
                const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
                if (orderedListText(quote_trimmed) == null or orderedListStartsAtOne(quote_trimmed)) return false;
                return listMarkerDisplayLevel(quote_line.content, true) <= current_level;
            }
            if (orderedListText(trimmed) == null or orderedListStartsAtOne(trimmed)) return false;
            return listMarkerDisplayLevel(line, true) <= current_level;
        },
    }
}

fn appendPlainPendingFallbackContinuation(
    allocator: std.mem.Allocator,
    current: *PendingContainer,
    line: []const u8,
    trimmed: []const u8,
    refs: []const ReferenceDef,
) !bool {
    const fallback = current.fallback orelse return false;

    var prefix: ?[]u8 = null;
    defer if (prefix) |owned| allocator.free(owned);
    var continuation: ParagraphLine = undefined;
    switch (current.kind) {
        .list => {
            if (listIndentLevel(line) == 0) return false;
            continuation = containerLine(trimmed);
            prefix = try buildPlainListPrefix(allocator, listIndentLevel(line), "");
        },
        .blockquote => {
            const quote_line = parseBlockquote(trimmed) orelse return false;
            if (quote_line.level != current.quote_level) return false;
            const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
            continuation = containerLine(quote_trimmed);
            prefix = try buildPlainBlockquotePrefix(allocator, quote_line.level, listIndentLevel(quote_line.content), "");
        },
    }

    var rendered: std.ArrayList(u8) = .empty;
    errdefer rendered.deinit(allocator);
    try rendered.appendSlice(allocator, fallback);
    try rendered.appendSlice(allocator, prefix.?);
    try appendInline(&rendered, allocator, continuation.text, refs);
    try rendered.append(allocator, '\n');

    allocator.free(fallback);
    current.fallback = try rendered.toOwnedSlice(allocator);
    return true;
}

fn appendRtfPendingFallbackContinuation(
    allocator: std.mem.Allocator,
    current: *PendingContainer,
    line: []const u8,
    trimmed: []const u8,
    refs: []const ReferenceDef,
) !bool {
    const fallback = current.fallback orelse return false;

    var prefix: ?[]u8 = null;
    defer if (prefix) |owned| allocator.free(owned);
    var suffix: []const u8 = undefined;
    var continuation: ParagraphLine = undefined;
    switch (current.kind) {
        .list => {
            if (listIndentLevel(line) == 0) return false;
            continuation = containerLine(trimmed);
            var prefix_list: std.ArrayList(u8) = .empty;
            errdefer prefix_list.deinit(allocator);
            try appendRtfContinuationPrefix(&prefix_list, allocator, listIndentLevel(line));
            prefix = try prefix_list.toOwnedSlice(allocator);
            suffix = "\\par\n";
        },
        .blockquote => {
            const quote_line = parseBlockquote(trimmed) orelse return false;
            if (quote_line.level != current.quote_level) return false;
            const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
            continuation = containerLine(quote_trimmed);
            prefix = try buildRtfBlockquotePrefix(allocator, quote_line.level, listIndentLevel(quote_line.content), "");
            suffix = "\\i0\\cf1\\par\n";
        },
    }

    var rendered: std.ArrayList(u8) = .empty;
    errdefer rendered.deinit(allocator);
    try rendered.appendSlice(allocator, fallback);
    try rendered.appendSlice(allocator, prefix.?);
    try appendInlineRtf(&rendered, allocator, continuation.text, refs);
    try rendered.appendSlice(allocator, suffix);

    allocator.free(fallback);
    current.fallback = try rendered.toOwnedSlice(allocator);
    return true;
}

fn flushPendingPlainContainer(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    pending: *?PendingContainer,
    refs: []const ReferenceDef,
) !void {
    if (pending.*) |current| {
        if (!current.coalesce_continuations) {
            if (current.fallback) |fallback| {
                try out.appendSlice(allocator, fallback);
            }
        } else {
            try out.appendSlice(allocator, current.prefix);
            try appendInline(out, allocator, current.text, refs);
            try out.appendSlice(allocator, current.suffix);
        }
    }
    freePendingContainer(allocator, pending);
}

fn flushPendingPlainContainerHeading(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    pending: *?PendingContainer,
    level: usize,
    refs: []const ReferenceDef,
) !void {
    if (pending.*) |current| {
        try out.appendSlice(allocator, current.prefix);
        try out.appendSlice(allocator, if (level == 1) "== " else "-- ");
        try appendInline(out, allocator, current.heading_text, refs);
        try out.appendSlice(allocator, if (level == 1) " ==" else " --");
        try out.appendSlice(allocator, current.suffix);
    }
    freePendingContainer(allocator, pending);
}

fn flushPendingRtfContainer(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    pending: *?PendingContainer,
    refs: []const ReferenceDef,
) !void {
    if (pending.*) |current| {
        if (!current.coalesce_continuations) {
            if (current.fallback) |fallback| {
                try out.appendSlice(allocator, fallback);
            }
        } else {
            try out.appendSlice(allocator, current.prefix);
            try appendInlineRtf(out, allocator, current.text, refs);
            try out.appendSlice(allocator, current.suffix);
        }
    }
    freePendingContainer(allocator, pending);
}

fn flushPendingRtfContainerHeading(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    pending: *?PendingContainer,
    level: usize,
    refs: []const ReferenceDef,
) !void {
    if (pending.*) |current| {
        const size = switch (level) {
            1 => "44",
            2 => "36",
            else => "30",
        };
        try out.appendSlice(allocator, current.prefix);
        try out.appendSlice(allocator, "\\b\\fs");
        try out.appendSlice(allocator, size);
        try out.append(allocator, ' ');
        try appendInlineRtf(out, allocator, current.heading_text, refs);
        try out.appendSlice(allocator, "\\b0\\fs22");
        try out.appendSlice(allocator, current.suffix);
    }
    freePendingContainer(allocator, pending);
}

fn pendingContainerSetextLevel(current: PendingContainer, line: []const u8, trimmed: []const u8) ?usize {
    switch (current.kind) {
        .blockquote => {
            const quote_line = parseBlockquote(trimmed) orelse return null;
            if (quote_line.level != current.quote_level) return null;
            return blockquoteSetextHeadingLevel(quote_line.content);
        },
        .list => {
            return listSetextHeadingLevel(line);
        },
    }
}

fn containerContinuationLine(
    current_text: []const u8,
    kind: PendingContainerKind,
    quote_level: usize,
    ordered_start_guard: bool,
    ordered_start_guard_requires_indent: bool,
    line: []const u8,
    trimmed: []const u8,
) ?ParagraphLine {
    switch (kind) {
        .list => {
            const allow_ordered_start_guard = ordered_start_guard and (!ordered_start_guard_requires_indent or listIndentLevel(line) > 0);
            if (!isContainerParagraphContinuationWithOrderedStartGuard(line, trimmed, allow_ordered_start_guard)) return null;
            if (!isLazyListParagraphContinuation(line, trimmed) and listIndentLevel(line) == 0) return null;
            return containerContinuationTextLine(current_text, std.mem.trimStart(u8, line, " \t"));
        },
        .blockquote => {
            if (parseBlockquote(std.mem.trimStart(u8, line, " \t"))) |quote_line| {
                if (quote_line.level != quote_level) return null;
                const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
                const quote_text = std.mem.trimStart(u8, quote_line.content, " \t");
                const quote_indent = listIndentLevel(quote_line.content);
                const allow_ordered_start_guard = ordered_start_guard and (!ordered_start_guard_requires_indent or quote_indent > 0);
                if (!isContainerParagraphContinuationWithOrderedStartGuard(quote_line.content, quote_trimmed, allow_ordered_start_guard)) return null;
                return containerContinuationTextLine(current_text, quote_text);
            }
            const allow_ordered_start_guard = ordered_start_guard and (!ordered_start_guard_requires_indent or listIndentLevel(line) > 0);
            if (!isContainerParagraphContinuationWithOrderedStartGuard(line, trimmed, allow_ordered_start_guard)) return null;
            return containerContinuationTextLine(current_text, std.mem.trimStart(u8, line, " \t"));
        },
    }
}

fn isOrderedStartGuardedContainerContinuation(current: PendingContainer, line: []const u8, trimmed: []const u8) bool {
    if (!current.ordered_start_guard) return false;
    switch (current.kind) {
        .list => {
            if (listIndentLevel(line) == 0) return false;
            return orderedListText(trimmed) != null and !orderedListStartsAtOne(trimmed);
        },
        .blockquote => {
            if (parseBlockquote(trimmed)) |quote_line| {
                if (quote_line.level != current.quote_level) return false;
                if (current.ordered_start_guard_requires_indent and listIndentLevel(quote_line.content) == 0) return false;
                const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
                return orderedListText(quote_trimmed) != null and !orderedListStartsAtOne(quote_trimmed);
            }
            if (current.ordered_start_guard_requires_indent and listIndentLevel(line) == 0) return false;
            return orderedListText(trimmed) != null and !orderedListStartsAtOne(trimmed);
        },
    }
}

fn isContainerParagraphContinuationWithOrderedStartGuard(line: []const u8, trimmed: []const u8, ordered_start_guard: bool) bool {
    if (!ordered_start_guard) return isContainerParagraphContinuation(line, trimmed);
    if (trimmed.len == 0) return false;
    if (isCodeFence(line)) return false;
    if (isHorizontalRule(trimmed)) return false;
    if (headingLevel(trimmed) != null) return false;
    if (htmlBlockInterruptsParagraph(trimmed)) return false;
    if (parseBlockquote(trimmed) != null) return false;
    if (unorderedListText(trimmed) != null) return false;
    if (orderedListText(trimmed) != null) return !orderedListStartsAtOne(trimmed);
    if (std.mem.startsWith(u8, trimmed, "|")) return false;
    return true;
}

fn isContainerParagraphContinuation(line: []const u8, trimmed: []const u8) bool {
    if (trimmed.len == 0) return false;
    if (isCodeFence(line)) return false;
    if (isHorizontalRule(trimmed)) return false;
    if (headingLevel(trimmed) != null) return false;
    if (htmlBlockInterruptsParagraph(trimmed)) return false;
    if (parseBlockquote(trimmed) != null) return false;
    if (unorderedListText(trimmed) != null) return false;
    if (orderedListText(trimmed) != null) return false;
    if (std.mem.startsWith(u8, trimmed, "|")) return false;
    return true;
}

fn inlineNeedsContinuation(text: []const u8) bool {
    return hasUnmatchedBacktickRun(text) or
        hasUnclosedLinkLabel(text) or
        hasOddUnescapedToken(text, "**") or
        hasOddUnescapedToken(text, "__") or
        hasOddUnescapedSingleDelimiter(text, '*') or
        hasOddUnescapedSingleDelimiter(text, '_');
}

fn hasUnclosedLinkLabel(text: []const u8) bool {
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text[i] != '[' or isEscapedAt(text, i)) continue;
        if (findLinkCloseBracket(text, i + 1) == null) return true;
    }
    return false;
}

const backtick_parity_slots = 1024;

fn hasUnmatchedBacktickRun(text: []const u8) bool {
    return hasUnmatchedBacktickRunAcross("", text);
}

fn hasUnmatchedBacktickRunAcross(first: []const u8, second: []const u8) bool {
    var odd_runs = [_]bool{false} ** backtick_parity_slots;
    var has_large = false;
    toggleBacktickRunParity(&odd_runs, &has_large, first);
    toggleBacktickRunParity(&odd_runs, &has_large, second);
    if (hasAnyOddBacktickRun(&odd_runs)) return true;
    if (!has_large) return false;
    return hasOddLargeBacktickRunAcross(first, second, odd_runs.len);
}

fn toggleBacktickRunParity(odd_runs: []bool, has_large: *bool, text: []const u8) void {
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] != '`') {
            i += 1;
            continue;
        }
        const start = i;
        while (i < text.len and text[i] == '`') : (i += 1) {}
        const run_len = i - start;
        if (run_len < odd_runs.len) {
            odd_runs[run_len] = !odd_runs[run_len];
        } else {
            has_large.* = true;
        }
    }
}

fn hasAnyOddBacktickRun(odd_runs: []const bool) bool {
    for (odd_runs[1..]) |odd| {
        if (odd) return true;
    }
    return false;
}

fn hasOddLargeBacktickRunAcross(first: []const u8, second: []const u8, min_len: usize) bool {
    return hasOddLargeBacktickRunCandidate(first, first, second, min_len) or
        hasOddLargeBacktickRunCandidate(second, first, second, min_len);
}

fn hasOddLargeBacktickRunCandidate(candidate: []const u8, first: []const u8, second: []const u8, min_len: usize) bool {
    var i: usize = 0;
    while (i < candidate.len) {
        if (candidate[i] != '`') {
            i += 1;
            continue;
        }
        const start = i;
        while (i < candidate.len and candidate[i] == '`') : (i += 1) {}
        const run_len = i - start;
        if (run_len >= min_len and ((countBacktickRunLength(first, run_len) + countBacktickRunLength(second, run_len)) % 2 == 1)) return true;
    }
    return false;
}

fn countBacktickRunLength(text: []const u8, target: usize) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] != '`') {
            i += 1;
            continue;
        }
        const start = i;
        while (i < text.len and text[i] == '`') : (i += 1) {}
        if (i - start == target) count += 1;
    }
    return count;
}

fn hasOddUnescapedToken(text: []const u8, token: []const u8) bool {
    var odd = false;
    var i: usize = 0;
    while (i + token.len <= text.len) {
        if (!isEscapedAt(text, i) and std.mem.eql(u8, text[i .. i + token.len], token)) {
            odd = !odd;
            i += token.len;
            continue;
        }
        i += 1;
    }
    return odd;
}

fn hasOddUnescapedSingleDelimiter(text: []const u8, delimiter: u8) bool {
    var odd = false;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text[i] != delimiter or isEscapedAt(text, i)) continue;
        if (i + 1 < text.len and text[i + 1] == delimiter) {
            i += 1;
            continue;
        }
        if (i > 0 and text[i - 1] == delimiter) continue;
        odd = !odd;
    }
    return odd;
}

fn isEscapedAt(text: []const u8, index: usize) bool {
    var count: usize = 0;
    var i = index;
    while (i > 0) {
        i -= 1;
        if (text[i] != '\\') break;
        count += 1;
    }
    return count % 2 == 1;
}

fn setextHeadingLevel(line: []const u8) ?usize {
    if (line.len == 0) return null;
    const trimmed_end = std.mem.trimEnd(u8, line, " \t");

    var index: usize = 0;
    var columns: usize = 0;
    while (index < trimmed_end.len) : (index += 1) {
        switch (trimmed_end[index]) {
            ' ' => columns += 1,
            '\t' => columns += 4,
            else => break,
        }
        if (columns >= 4) return null;
    }

    if (index >= trimmed_end.len) return null;
    const marker = trimmed_end[index];
    if (marker != '=' and marker != '-') return null;

    var marker_count: usize = 0;
    for (trimmed_end[index..]) |ch| {
        if (ch != marker) return null;
        marker_count += 1;
    }

    if (marker_count == 0) return null;
    return if (marker == '=') 1 else 2;
}

fn listIndentLevel(line: []const u8) usize {
    const columns = leadingIndentColumns(line);
    return @min(columns / 2, max_visual_indent_level);
}

fn blockquoteDisplayIndent(line: []const u8) usize {
    if (line.len > 0 and line[0] == '\t') return 0;
    return listIndentLevel(line);
}

fn blockquoteSetextHeadingLevel(line: []const u8) ?usize {
    if (line.len > 0 and line[0] == '\t') return setextHeadingLevel(line[1..]);
    return setextHeadingLevel(line);
}

fn listSetextHeadingLevel(line: []const u8) ?usize {
    const content = listSetextContent(line) orelse return null;
    return setextHeadingLevel(content);
}

fn listContinuationBlockStart(line: []const u8, list_context: bool) bool {
    return list_context and listSetextContent(line) != null;
}

fn listSetextContent(line: []const u8) ?[]const u8 {
    var index: usize = 0;
    var columns: usize = 0;
    while (index < line.len) : (index += 1) {
        switch (line[index]) {
            ' ' => columns += 1,
            '\t' => columns = nextTabStop(columns),
            else => break,
        }
    }
    if (columns < 2 or columns > 5) return null;
    return line[index..];
}

fn listMarkerDisplayLevel(line: []const u8, list_context: bool) usize {
    const columns = leadingIndentColumns(line);
    if (!list_context and columns <= 3) return 0;
    if (list_context) {
        if (columns < 2) return 0;
        return @min(((columns - 2) / 4) + 1, max_visual_indent_level);
    }
    return @min(columns / 2, max_visual_indent_level);
}

fn leadingIndentColumns(line: []const u8) usize {
    var columns: usize = 0;
    for (line) |ch| {
        switch (ch) {
            ' ' => columns += 1,
            '\t' => columns = nextTabStop(columns),
            else => break,
        }
    }
    return columns;
}

fn nextTabStop(columns: usize) usize {
    return ((columns / 4) + 1) * 4;
}

fn appendPlainListIndent(out: *std.ArrayList(u8), allocator: std.mem.Allocator, level: usize) !void {
    var i: usize = 0;
    while (i < level) : (i += 1) {
        try out.appendSlice(allocator, "  ");
    }
}

fn appendPlainBlockquotePrefix(out: *std.ArrayList(u8), allocator: std.mem.Allocator, level: usize) !void {
    var i: usize = 0;
    while (i < level) : (i += 1) {
        try out.appendSlice(allocator, "| ");
    }
}

fn appendRtfContinuationPrefix(out: *std.ArrayList(u8), allocator: std.mem.Allocator, level: usize) !void {
    const left = 360 + level * 360;
    const prefix = try std.fmt.allocPrint(allocator, "\\pard\\li{}\\sa60\\f0\\fs22\\cf1 ", .{left});
    defer allocator.free(prefix);
    try out.appendSlice(allocator, prefix);
}

fn appendRtfBlockquotePrefix(out: *std.ArrayList(u8), allocator: std.mem.Allocator, quote_level: usize, content_level: usize) !void {
    const left = quote_level * 360 + content_level * 360;
    const prefix = try std.fmt.allocPrint(allocator, "\\pard\\li{}\\ri240\\sb60\\sa100\\i\\cf2 ", .{left});
    defer allocator.free(prefix);
    try out.appendSlice(allocator, prefix);
}

fn appendRtfListPrefix(out: *std.ArrayList(u8), allocator: std.mem.Allocator, level: usize, ordered: bool, marker: []const u8) !void {
    const base_left: usize = if (ordered) 520 else 480;
    const first: usize = if (ordered) 300 else 240;
    const left = base_left + level * 360;
    const tab_stop = rtfListTabStop(left, first, ordered, marker);
    const prefix = try std.fmt.allocPrint(allocator, "\\pard\\li{}\\fi-{}\\tx{}\\sa70\\f0\\fs22\\cf1 ", .{ left, first, tab_stop });
    defer allocator.free(prefix);
    try out.appendSlice(allocator, prefix);
}

fn rtfListTabStop(left: usize, first: usize, ordered: bool, marker: []const u8) usize {
    const minimum_gap_stop = left + 120;
    if (!ordered) return minimum_gap_stop;

    const marker_text = if (std.mem.indexOf(u8, marker, "\\tab")) |tab_index| marker[0..tab_index] else marker;
    const marker_start = if (left > first) left - first else 0;
    const estimated_marker_end = marker_start + marker_text.len * 120;
    return @max(minimum_gap_stop, estimated_marker_end + 120);
}

fn headingLevel(line: []const u8) ?usize {
    var i: usize = 0;
    while (i < line.len and line[i] == '#') : (i += 1) {}
    if (i == 0 or i > 6) return null;
    if (i == line.len) return i;
    if (i < line.len and (line[i] == ' ' or line[i] == '\t')) return i;
    return null;
}

fn atxHeadingTitle(line: []const u8, level: usize) []const u8 {
    var title = std.mem.trim(u8, line[level..], " \t");
    var close_start = title.len;
    while (close_start > 0 and title[close_start - 1] == '#') : (close_start -= 1) {}
    if (close_start < title.len and (close_start == 0 or title[close_start - 1] == ' ' or title[close_start - 1] == '\t')) {
        title = std.mem.trimEnd(u8, title[0..close_start], " \t");
    }
    return title;
}

fn isCodeFence(line: []const u8) bool {
    return parseOpeningCodeFence(line) != null;
}

fn parseOpeningCodeFence(line: []const u8) ?CodeFence {
    var index: usize = 0;
    var columns: usize = 0;
    while (index < line.len) : (index += 1) {
        switch (line[index]) {
            ' ' => columns += 1,
            '\t' => columns = nextTabStop(columns),
            else => break,
        }
        if (columns >= 4) return null;
    }

    if (line.len - index < 3) return null;
    const marker = line[index];
    if (marker != '`' and marker != '~') return null;

    var count: usize = 0;
    while (index + count < line.len and line[index + count] == marker) : (count += 1) {}
    if (count < 3) return null;

    const info = std.mem.trim(u8, line[index + count ..], " \t");
    if (marker == '`' and findByteFrom(info, 0, '`') != null) return null;

    return .{ .marker = marker, .len = count, .indent = columns };
}

fn stripCodeFenceContentIndent(allocator: std.mem.Allocator, line: []const u8, indent: usize) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var index: usize = 0;
    var columns: usize = 0;
    while (index < line.len and columns < indent) {
        if (line[index] == ' ') {
            index += 1;
            columns += 1;
            continue;
        }

        if (line[index] == '\t') {
            const next_tab = nextTabStop(columns);
            index += 1;
            if (next_tab <= indent) {
                columns = next_tab;
                continue;
            }

            var remaining = next_tab - indent;
            while (remaining > 0) : (remaining -= 1) {
                try out.append(allocator, ' ');
            }
            columns = indent;
            break;
        }

        break;
    }

    try out.appendSlice(allocator, line[index..]);
    return out.toOwnedSlice(allocator);
}

fn isClosingCodeFence(line: []const u8, fence: CodeFence) bool {
    const trimmed_end = std.mem.trimEnd(u8, line, " \t");
    var index: usize = 0;
    var columns: usize = 0;
    while (index < trimmed_end.len) : (index += 1) {
        switch (trimmed_end[index]) {
            ' ' => columns += 1,
            '\t' => columns += 4,
            else => break,
        }
        if (columns >= 4) return false;
    }

    if (index + fence.len > trimmed_end.len or trimmed_end[index] != fence.marker) return false;

    var count: usize = 0;
    while (index + count < trimmed_end.len and trimmed_end[index + count] == fence.marker) : (count += 1) {}
    if (count < fence.len) return false;

    return index + count == trimmed_end.len;
}

fn indentedCodeText(line: []const u8) ?[]const u8 {
    var columns: usize = 0;
    var index: usize = 0;

    while (index < line.len) : (index += 1) {
        switch (line[index]) {
            ' ' => columns += 1,
            '\t' => columns = nextTabStop(columns),
            else => return null,
        }
        if (columns >= 4) {
            return line[index + 1 ..];
        }
    }

    return null;
}

fn listIndentedCodeText(line: []const u8, list_level: usize) ?[]const u8 {
    if (list_level == 0) return null;
    const code_columns = (list_level - 1) * 4 + 6;
    return stripIndentColumns(line, code_columns);
}

fn activeListLevelForIndentedContinuation(list_context: bool, lazy_list_level: usize) usize {
    if (lazy_list_level > 0) return lazy_list_level;
    return if (list_context) 1 else 0;
}

fn stripIndentColumns(line: []const u8, target_columns: usize) ?[]const u8 {
    var columns: usize = 0;
    var index: usize = 0;

    while (index < line.len) : (index += 1) {
        switch (line[index]) {
            ' ' => columns += 1,
            '\t' => columns = nextTabStop(columns),
            else => return null,
        }
        if (columns >= target_columns) {
            return line[index + 1 ..];
        }
    }

    return null;
}

fn parseBlockquote(line: []const u8) ?BlockquoteLine {
    var rest = line;
    var level: usize = 0;

    while (rest.len > 0 and rest[0] == '>') {
        level += 1;
        rest = rest[1..];
        if (rest.len > 0 and (rest[0] == ' ' or rest[0] == '\t')) {
            rest = rest[1..];
        }
    }

    if (level == 0) return null;
    return .{ .level = level, .content = rest };
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
    if (i == 0 or i > 9 or i + 1 >= line.len) return null;
    if (line[i] != '.' and line[i] != ')') return null;
    if (line[i + 1] != ' ' and line[i + 1] != '\t') return null;
    return std.mem.trimStart(u8, line[i + 2 ..], " \t");
}

fn orderedListStartsAtOne(line: []const u8) bool {
    var i: usize = 0;
    while (i < line.len and std.ascii.isDigit(line[i])) : (i += 1) {}
    if (i == 0 or i > 9) return false;
    const start = std.fmt.parseInt(u64, line[0..i], 10) catch return false;
    return start == 1;
}

fn orderedMarker(line: []const u8) []const u8 {
    var i: usize = 0;
    while (i < line.len and std.ascii.isDigit(line[i])) : (i += 1) {}
    return line[0 .. i + 1];
}

fn allocRtfOrderedMarker(allocator: std.mem.Allocator, line: []const u8) ![]u8 {
    const marker = orderedMarker(line);
    const spacer = if (marker.len > 2) " \\tab " else "\\tab ";
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ marker, spacer });
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
    var marker_count: usize = 0;
    for (line) |ch| {
        if (ch == marker) {
            marker_count += 1;
            continue;
        }
        if (ch != ' ' and ch != '\t') return false;
    }
    return marker_count >= 3;
}

fn collectReferenceDefs(allocator: std.mem.Allocator, input: []const u8) ![]ReferenceDef {
    const reference_scan = try scanReferences(allocator, input);
    allocator.free(reference_scan.hidden_lines);
    allocator.free(reference_scan.owned_labels);
    return reference_scan.defs;
}

fn scanReferences(allocator: std.mem.Allocator, input: []const u8) !ReferenceScan {
    var refs: std.ArrayList(ReferenceDef) = .empty;
    errdefer refs.deinit(allocator);
    var hidden_lines: std.ArrayList(bool) = .empty;
    errdefer hidden_lines.deinit(allocator);
    var owned_labels: std.ArrayList([]u8) = .empty;
    errdefer {
        for (owned_labels.items) |label| allocator.free(label);
        owned_labels.deinit(allocator);
    }

    var active_fence: ?CodeFence = null;
    var active_container_fence: ?ActiveContainerFence = null;
    var active_html_comment = false;
    var active_html_cdata = false;
    var active_html_block: ?HtmlBlock = null;
    var active_container_html: ?ActiveContainerHtml = null;
    var paragraph_open = false;
    var pending_start: ?ReferenceDefStart = null;
    var pending_start_line: usize = 0;
    var pending_multiline_label: ?[]u8 = null;
    defer if (pending_multiline_label) |label| allocator.free(label);
    var pending_multiline_label_start_line: usize = 0;
    var pending_reference_title = false;
    var line_index: usize = 0;
    var lines = lineIterator(input);
    while (lines.next()) |source_line| {
        try hidden_lines.append(allocator, false);
        const current_line_index = line_index;
        line_index += 1;

        const line = source_line.text;
        const trimmed = std.mem.trim(u8, line, " \t");

        if (active_container_fence) |container| {
            if (containerFenceContent(container, line, trimmed)) |content| {
                if (isClosingCodeFence(content, container.fence)) active_container_fence = null;
                paragraph_open = false;
                continue;
            }
            active_container_fence = null;
        }

        if (active_container_html) |container| {
            if (container.block.end_on_blank and trimmed.len == 0) {
                active_container_html = null;
                paragraph_open = false;
                continue;
            }
            if (containerHtmlContent(container, line, trimmed)) |content| {
                const content_trimmed = std.mem.trim(u8, content, " \t");
                if (container.block.end_on_blank and content_trimmed.len == 0) {
                    active_container_html = null;
                } else if (htmlBlockEndsOnLine(content_trimmed, container.block)) {
                    active_container_html = null;
                }
                paragraph_open = false;
                continue;
            }
            active_container_html = null;
        }

        if (pending_multiline_label) |label_so_far| {
            if (referenceMultilineLabelCloseInContainerLine(line, trimmed)) |close| {
                const label = try appendMultilineLabelPart(allocator, label_so_far, close.before);
                allocator.free(label_so_far);
                pending_multiline_label = null;
                const rest = std.mem.trim(u8, close.rest, " \t");
                if (label.len > 0 and referenceLabelOk(label)) {
                    owned_labels.append(allocator, label) catch |err| {
                        allocator.free(label);
                        return err;
                    };
                    if (rest.len == 0) {
                        pending_start = .{ .label = label };
                        pending_start_line = pending_multiline_label_start_line;
                        paragraph_open = false;
                        continue;
                    }
                    if (referenceLinkDestinationParse(rest)) |parsed| {
                        if (findReference(refs.items, label) == null) {
                            try refs.append(allocator, .{ .label = label, .destination = parsed.destination });
                        }
                        var hide_line = pending_multiline_label_start_line;
                        while (hide_line <= current_line_index) : (hide_line += 1) {
                            hidden_lines.items[hide_line] = true;
                        }
                        pending_reference_title = !parsed.has_title;
                        paragraph_open = false;
                        continue;
                    }
                } else {
                    allocator.free(label);
                }
            } else if (trimmed.len == 0) {
                allocator.free(label_so_far);
                pending_multiline_label = null;
            } else {
                if (referenceMultilineLabelContinuationTextInContainerLine(line, trimmed)) |part| {
                    const combined = try appendMultilineLabelPart(allocator, label_so_far, part);
                    allocator.free(label_so_far);
                    pending_multiline_label = combined;
                    paragraph_open = false;
                    continue;
                }
                allocator.free(label_so_far);
                pending_multiline_label = null;
                paragraph_open = false;
                continue;
            }
        }

        if (pending_start) |start| {
            pending_start = null;
            if (trimmed.len != 0) {
                if (referenceDestinationInContainerLine(line, trimmed)) |parsed| {
                    if (findReference(refs.items, start.label) == null) {
                        try refs.append(allocator, .{ .label = start.label, .destination = parsed.destination });
                    }
                    var hide_line = pending_start_line;
                    while (hide_line <= current_line_index) : (hide_line += 1) {
                        hidden_lines.items[hide_line] = true;
                    }
                    pending_reference_title = !parsed.has_title;
                    paragraph_open = false;
                    continue;
                }
            }

            paragraph_open = true;
        }

        if (pending_reference_title) {
            pending_reference_title = false;
            if (isReferenceTitleContinuationInContainerLine(line, trimmed)) {
                hidden_lines.items[current_line_index] = true;
                paragraph_open = false;
                continue;
            }
        }

        if (active_fence) |fence| {
            if (isClosingCodeFence(line, fence)) active_fence = null;
            paragraph_open = false;
            continue;
        }

        if (active_html_comment) {
            if (isHtmlCommentEnd(trimmed)) active_html_comment = false;
            paragraph_open = false;
            continue;
        }

        if (active_html_cdata) {
            if (isHtmlCdataEnd(trimmed)) active_html_cdata = false;
            paragraph_open = false;
            continue;
        }

        if (active_html_block) |block| {
            if (block.end_on_blank and trimmed.len == 0) {
                active_html_block = null;
                paragraph_open = false;
                continue;
            }
            if (htmlBlockEndsOnLine(trimmed, block)) active_html_block = null;
            paragraph_open = false;
            continue;
        }

        if (parseOpeningCodeFence(line)) |fence| {
            active_fence = fence;
            paragraph_open = false;
            continue;
        }

        if (containerOpeningCodeFenceForScan(line, trimmed)) |container| {
            active_container_fence = container;
            paragraph_open = false;
            continue;
        }

        if (containerOpeningHtmlBlockForScan(line, trimmed)) |opened| {
            if (htmlBlockCanContinue(opened.container.block) and !htmlBlockEndsOnLine(opened.content, opened.container.block)) {
                active_container_html = opened.container;
            }
            paragraph_open = false;
            continue;
        }

        if (isHtmlCommentStart(trimmed)) {
            active_html_comment = !isHtmlCommentEnd(trimmed);
            paragraph_open = false;
            continue;
        }

        if (isHtmlCdataStart(trimmed)) {
            active_html_cdata = !isHtmlCdataEnd(trimmed);
            paragraph_open = false;
            continue;
        }

        if (isHtmlBlockLine(trimmed) and (!paragraph_open or htmlBlockInterruptsParagraph(trimmed))) {
            if (htmlBlockStart(trimmed)) |block| {
                if (!htmlBlockEndsOnLine(trimmed, block)) active_html_block = block;
            }
            paragraph_open = false;
            continue;
        }

        if (indentedCodeText(line) != null) {
            paragraph_open = false;
            continue;
        }

        if (trimmed.len == 0) {
            paragraph_open = false;
            continue;
        }

        if (referenceDefinitionInContainerLine(line, trimmed)) |parsed| {
            if (!paragraph_open) {
                if (findReference(refs.items, parsed.def.label) == null) {
                    try refs.append(allocator, parsed.def);
                }
                hidden_lines.items[current_line_index] = true;
                pending_reference_title = parsed.allow_following_title;
                paragraph_open = false;
                continue;
            }
        }

        if (referenceDefinitionStartInContainerLine(line, trimmed)) |start| {
            if (!paragraph_open) {
                pending_start = start;
                pending_start_line = current_line_index;
                paragraph_open = false;
                continue;
            }
        }

        if (referenceMultilineLabelStartInContainerLine(line, trimmed)) |label_start_text| {
            if (!paragraph_open) {
                pending_multiline_label = try allocator.dupe(u8, label_start_text);
                pending_multiline_label_start_line = current_line_index;
                paragraph_open = false;
                continue;
            }
        }

        if (setextHeadingLevel(line) != null or
            isHorizontalRule(trimmed) or
            headingLevel(trimmed) != null or
            parseBlockquote(trimmed) != null or
            unorderedListText(trimmed) != null or
            (orderedListText(trimmed) != null and (!paragraph_open or orderedListStartsAtOne(trimmed))) or
            listIndentLevel(line) > 0 or
            std.mem.startsWith(u8, trimmed, "|"))
        {
            paragraph_open = false;
        } else {
            paragraph_open = true;
        }
    }

    const defs = try refs.toOwnedSlice(allocator);
    errdefer allocator.free(defs);
    const hidden = try hidden_lines.toOwnedSlice(allocator);
    errdefer allocator.free(hidden);
    const owned = try owned_labels.toOwnedSlice(allocator);

    return .{
        .defs = defs,
        .hidden_lines = hidden,
        .owned_labels = owned,
    };
}

fn referenceDefinition(line: []const u8) ?ReferenceDefParse {
    if (line.len < 4 or line[0] != '[') return null;
    const close = findReferenceLabelCloseBracket(line, 1) orelse return null;
    if (close == 1 or close + 1 >= line.len or line[close + 1] != ':') return null;

    const label = std.mem.trim(u8, line[1..close], " \t");
    if (label.len == 0) return null;
    if (!referenceLabelOk(label)) return null;

    const rest = std.mem.trim(u8, line[close + 2 ..], " \t");
    if (rest.len == 0) return null;

    const parsed = referenceLinkDestinationParse(rest) orelse return null;
    return .{
        .def = .{ .label = label, .destination = parsed.destination },
        .allow_following_title = !parsed.has_title,
    };
}

fn referenceDefinitionStart(line: []const u8) ?ReferenceDefStart {
    if (line.len < 3 or line[0] != '[') return null;
    const close = findReferenceLabelCloseBracket(line, 1) orelse return null;
    if (close == 1 or close + 1 >= line.len or line[close + 1] != ':') return null;

    const label = std.mem.trim(u8, line[1..close], " \t");
    if (label.len == 0) return null;
    if (!referenceLabelOk(label)) return null;

    const rest = std.mem.trim(u8, line[close + 2 ..], " \t");
    if (rest.len != 0) return null;

    return .{ .label = label };
}

fn referenceMultilineLabelStart(line: []const u8, trimmed: []const u8) ?usize {
    if (trimmed.len == 0 or trimmed[0] != '[') return null;
    if (findLinkCloseBracket(trimmed, 1) != null) return null;
    return leadingTrimBytes(line) + 1;
}

fn referenceMultilineLabelStartText(line: []const u8) ?[]const u8 {
    if (line.len == 0 or line[0] != '[') return null;
    if (findLinkCloseBracket(line, 1) != null) return null;
    return line[1..];
}

fn referenceMultilineLabelStartInContainerLine(line: []const u8, trimmed: []const u8) ?[]const u8 {
    if (indentedCodeText(line) == null) {
        if (referenceMultilineLabelStartText(trimmed)) |start| return start;
    }

    if (parseBlockquote(trimmed)) |quote_line| {
        const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
        return referenceMultilineLabelStartInContainerLine(quote_line.content, quote_trimmed);
    }

    if (unorderedListText(trimmed)) |item| {
        if (referenceMultilineLabelStartText(item)) |start| return start;
    }

    if (orderedListText(trimmed)) |item| {
        if (referenceMultilineLabelStartText(item)) |start| return start;
    }

    return null;
}

fn referenceMultilineLabelClose(trimmed: []const u8) ?usize {
    const close = findLinkCloseBracket(trimmed, 0) orelse return null;
    if (close + 1 >= trimmed.len or trimmed[close + 1] != ':') return null;
    return close;
}

const ReferenceMultilineClose = struct {
    before: []const u8,
    rest: []const u8,
};

fn referenceMultilineLabelCloseInContainerLine(line: []const u8, trimmed: []const u8) ?ReferenceMultilineClose {
    if (parseBlockquote(trimmed)) |quote_line| {
        const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
        return referenceMultilineLabelCloseInContainerLine(quote_line.content, quote_trimmed);
    }

    if (indentedCodeText(line) == null) {
        if (referenceMultilineLabelClose(trimmed)) |close| {
            return .{ .before = trimmed[0..close], .rest = trimmed[close + 2 ..] };
        }
    }

    if (unorderedListText(trimmed)) |item| {
        if (referenceMultilineLabelClose(item)) |close| {
            return .{ .before = item[0..close], .rest = item[close + 2 ..] };
        }
    }

    if (orderedListText(trimmed)) |item| {
        if (referenceMultilineLabelClose(item)) |close| {
            return .{ .before = item[0..close], .rest = item[close + 2 ..] };
        }
    }

    return null;
}

fn referenceMultilineLabelContinuationTextInContainerLine(line: []const u8, trimmed: []const u8) ?[]const u8 {
    if (trimmed.len == 0) return null;
    if (parseBlockquote(trimmed)) |quote_line| {
        return std.mem.trim(u8, quote_line.content, " \t");
    }
    _ = line;
    return trimmed;
}

fn appendMultilineLabelPart(allocator: std.mem.Allocator, label: []const u8, part: []const u8) ![]u8 {
    if (label.len == 0) return allocator.dupe(u8, part);
    if (part.len == 0) return allocator.dupe(u8, label);
    return std.fmt.allocPrint(allocator, "{s}\n{s}", .{ label, part });
}

fn leadingTrimBytes(line: []const u8) usize {
    var index: usize = 0;
    while (index < line.len and (line[index] == ' ' or line[index] == '\t')) : (index += 1) {}
    return index;
}

fn referenceDefinitionInContainerLine(line: []const u8, trimmed: []const u8) ?ReferenceDefParse {
    if (indentedCodeText(line) == null) {
        if (referenceDefinition(trimmed)) |parsed| return parsed;
    }

    if (parseBlockquote(trimmed)) |quote_line| {
        const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
        return referenceDefinitionInContainerLine(quote_line.content, quote_trimmed);
    }

    if (unorderedListText(trimmed)) |item| {
        if (referenceDefinition(item)) |parsed| return parsed;
    }

    if (orderedListText(trimmed)) |item| {
        if (referenceDefinition(item)) |parsed| return parsed;
    }

    return null;
}

fn referenceDefinitionStartInContainerLine(line: []const u8, trimmed: []const u8) ?ReferenceDefStart {
    if (indentedCodeText(line) == null) {
        if (referenceDefinitionStart(trimmed)) |start| return start;
    }

    if (parseBlockquote(trimmed)) |quote_line| {
        const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
        return referenceDefinitionStartInContainerLine(quote_line.content, quote_trimmed);
    }

    if (unorderedListText(trimmed)) |item| {
        if (referenceDefinitionStart(item)) |start| return start;
    }

    if (orderedListText(trimmed)) |item| {
        if (referenceDefinitionStart(item)) |start| return start;
    }

    return null;
}

fn referenceDestinationInContainerLine(line: []const u8, trimmed: []const u8) ?LinkDestinationParse {
    _ = line;
    if (referenceLinkDestinationParse(trimmed)) |parsed| return parsed;

    if (parseBlockquote(trimmed)) |quote_line| {
        const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
        return referenceDestinationInContainerLine(quote_line.content, quote_trimmed);
    }

    if (unorderedListText(trimmed)) |item| {
        if (referenceLinkDestinationParse(item)) |parsed| return parsed;
    }

    if (orderedListText(trimmed)) |item| {
        if (referenceLinkDestinationParse(item)) |parsed| return parsed;
    }

    return null;
}

fn isReferenceTitleContinuation(line: []const u8) bool {
    const trimmed = std.mem.trim(u8, line, " \t");
    return isLinkTitle(trimmed);
}

fn isReferenceTitleContinuationInContainerLine(line: []const u8, trimmed: []const u8) bool {
    if (isReferenceTitleContinuation(line)) return true;

    if (parseBlockquote(trimmed)) |quote_line| {
        const quote_trimmed = std.mem.trim(u8, quote_line.content, " \t");
        return isReferenceTitleContinuationInContainerLine(quote_line.content, quote_trimmed);
    }

    if (unorderedListText(trimmed)) |item| return isLinkTitle(item);
    if (orderedListText(trimmed)) |item| return isLinkTitle(item);

    return false;
}

fn isLazyBlockquoteParagraphSeed(line: []const u8, trimmed: []const u8) bool {
    if (trimmed.len == 0) return false;
    if (indentedCodeText(line) != null) return false;
    return isPlainParagraphLine(line, trimmed, false);
}

fn isLazyListParagraphContinuation(line: []const u8, trimmed: []const u8) bool {
    if (trimmed.len == 0) return false;
    if (listIndentLevel(line) > 0) return false;
    if (unorderedListText(trimmed) != null) return false;
    if (orderedListText(trimmed) != null) return false;
    return isPlainParagraphLine(line, trimmed, false);
}

fn isPlainParagraphContinuationLine(line: []const u8, trimmed: []const u8, list_context: bool) bool {
    if (trimmed.len == 0) return false;
    if (!list_context and indentedCodeText(line) != null) return true;
    if (isCodeFence(line)) return false;
    if (isHorizontalRule(trimmed)) return false;
    if (headingLevel(trimmed) != null) return false;
    if (htmlBlockInterruptsParagraph(trimmed)) return false;
    if (parseBlockquote(trimmed) != null) return false;
    if (unorderedListText(trimmed) != null) return false;
    if (orderedListText(trimmed) != null) return !orderedListStartsAtOne(trimmed);
    if (std.mem.startsWith(u8, trimmed, "|")) return false;
    return true;
}

fn isPlainParagraphLine(line: []const u8, trimmed: []const u8, list_context: bool) bool {
    if (trimmed.len == 0) return false;
    if (!list_context and indentedCodeText(line) != null) return true;
    if (isCodeFence(line)) return false;
    if (isHorizontalRule(trimmed)) return false;
    if (headingLevel(trimmed) != null) return false;
    if (htmlBlockInterruptsParagraph(trimmed)) return false;
    if (parseBlockquote(trimmed) != null) return false;
    if (unorderedListText(trimmed) != null) return false;
    if (orderedListText(trimmed) != null) return !orderedListStartsAtOne(trimmed);
    if (listIndentLevel(line) > 0) return false;
    if (std.mem.startsWith(u8, trimmed, "|")) return false;
    return true;
}

fn paragraphLine(line: []const u8, trimmed: []const u8) ParagraphLine {
    const has_unmatched_code_span = hasUnmatchedBacktickRun(line);
    if (hasTwoTrailingSpaces(line) and !has_unmatched_code_span) {
        const text = std.mem.trimEnd(u8, line, " \t");
        return .{ .text = text, .heading_text = text, .hard_break = true };
    }

    if (line.len > 0 and line[line.len - 1] == '\\' and hasOddTrailingBackslashes(line) and !hasUnmatchedBacktickRun(line[0 .. line.len - 1])) {
        const text = std.mem.trim(u8, line[0 .. line.len - 1], " \t");
        return .{ .text = text, .heading_text = trimmed, .hard_break = true };
    }

    if (has_unmatched_code_span) {
        const text = std.mem.trimStart(u8, line, " \t");
        return .{ .text = text, .heading_text = text, .hard_break = false };
    }

    return .{ .text = trimmed, .heading_text = trimmed, .hard_break = false };
}

fn paragraphContinuationLine(pending_text: []const u8, line: []const u8, trimmed: []const u8) ParagraphLine {
    const text = std.mem.trimStart(u8, line, " \t");
    if (hasUnmatchedBacktickRun(pending_text)) {
        if (hasTwoTrailingSpaces(line)) {
            const hard_break_text = std.mem.trimEnd(u8, line, " \t");
            if (!hasUnmatchedBacktickRunAcross(pending_text, hard_break_text)) {
                return .{ .text = hard_break_text, .heading_text = hard_break_text, .hard_break = true };
            }
        }
        if (line.len > 0 and line[line.len - 1] == '\\' and hasOddTrailingBackslashes(line) and !hasUnmatchedBacktickRunAcross(pending_text, line[0 .. line.len - 1])) {
            const hard_break_text = std.mem.trim(u8, line[0 .. line.len - 1], " \t");
            return .{ .text = hard_break_text, .heading_text = trimmed, .hard_break = true };
        }
        if (!hasUnmatchedBacktickRunAcross(pending_text, text)) return paragraphLineClosedCodeContinuation(line, trimmed);
        return .{ .text = text, .heading_text = text, .hard_break = false };
    }
    return paragraphLine(line, trimmed);
}

fn paragraphLineClosedCodeContinuation(line: []const u8, trimmed: []const u8) ParagraphLine {
    if (hasUnmatchedBacktickRun(line)) {
        const text = std.mem.trimStart(u8, line, " \t");
        return .{ .text = text, .heading_text = text, .hard_break = false };
    }
    return .{ .text = trimmed, .heading_text = trimmed, .hard_break = false };
}

fn containerLine(text: []const u8) ParagraphLine {
    const has_unmatched_code_span = hasUnmatchedBacktickRun(text);
    if (hasTwoTrailingSpaces(text) and !has_unmatched_code_span) {
        const trimmed = std.mem.trimEnd(u8, text, " \t");
        return .{ .text = trimmed, .heading_text = trimmed, .hard_break = true };
    }

    if (text.len > 0 and text[text.len - 1] == '\\' and hasOddTrailingBackslashes(text) and !hasUnmatchedBacktickRun(text[0 .. text.len - 1])) {
        return .{ .text = std.mem.trimEnd(u8, text[0 .. text.len - 1], " \t"), .heading_text = std.mem.trim(u8, text, " \t"), .hard_break = true };
    }

    return .{ .text = text, .heading_text = text, .hard_break = false };
}

fn containerContinuationTextLine(current_text: []const u8, text: []const u8) ParagraphLine {
    if (hasUnmatchedBacktickRun(current_text)) {
        if (hasTwoTrailingSpaces(text)) {
            const hard_break_text = std.mem.trimEnd(u8, text, " \t");
            if (!hasUnmatchedBacktickRunAcross(current_text, hard_break_text)) {
                return .{ .text = hard_break_text, .heading_text = hard_break_text, .hard_break = true };
            }
        }
        if (text.len > 0 and text[text.len - 1] == '\\' and hasOddTrailingBackslashes(text) and !hasUnmatchedBacktickRunAcross(current_text, text[0 .. text.len - 1])) {
            const hard_break_text = std.mem.trimEnd(u8, text[0 .. text.len - 1], " \t");
            return .{ .text = hard_break_text, .heading_text = std.mem.trim(u8, text, " \t"), .hard_break = true };
        }
        if (!hasUnmatchedBacktickRunAcross(current_text, text)) return .{ .text = text, .heading_text = text, .hard_break = false };
        return .{ .text = text, .heading_text = text, .hard_break = false };
    }
    return containerLine(text);
}

fn containerInlineText(text: []const u8) []const u8 {
    return containerLine(text).text;
}

fn hasOddTrailingBackslashes(line: []const u8) bool {
    var count: usize = 0;
    var i = line.len;
    while (i > 0) {
        i -= 1;
        if (line[i] != '\\') break;
        count += 1;
    }
    return count % 2 == 1;
}

fn hasTwoTrailingSpaces(line: []const u8) bool {
    var count: usize = 0;
    var i = line.len;
    while (i > 0) {
        i -= 1;
        if (line[i] == ' ') {
            count += 1;
            if (count >= 2) return true;
            continue;
        }
        if (line[i] == '\t') continue;
        return false;
    }
    return false;
}

fn findReference(refs: []const ReferenceDef, label: []const u8) ?[]const u8 {
    if (!referenceLabelLengthOk(label)) return null;
    for (refs) |def| {
        if (referenceLabelMatches(def.label, label)) return def.destination;
    }
    return null;
}

fn referenceLabelMatches(a_raw: []const u8, b_raw: []const u8) bool {
    const a = std.mem.trim(u8, a_raw, " \t\r\n");
    const b = std.mem.trim(u8, b_raw, " \t\r\n");
    if (!referenceLabelLengthOk(a) or !referenceLabelLengthOk(b)) return false;

    var ac: ReferenceLabelCursor = .{ .text = a };
    var bc: ReferenceLabelCursor = .{ .text = b };
    while (!ac.finished() and !bc.finished()) {
        if (ac.atWhitespace() or bc.atWhitespace()) {
            if (!ac.atWhitespace() or !bc.atWhitespace()) return false;
            ac.skipWhitespaceRun();
            bc.skipWhitespaceRun();
            continue;
        }

        const a_folded = ac.nextFolded() orelse break;
        const b_folded = bc.nextFolded() orelse break;
        if (a_folded != b_folded) return false;
    }

    ac.skipWhitespaceRun();
    bc.skipWhitespaceRun();
    return ac.finished() and bc.finished();
}

fn referenceLabelLengthOk(label: []const u8) bool {
    return label.len <= max_reference_label_bytes;
}

fn referenceLabelOk(label: []const u8) bool {
    if (!referenceLabelLengthOk(label)) return false;

    var i: usize = 0;
    while (i < label.len) : (i += 1) {
        if (label[i] == '\\' and i + 1 < label.len and isEscapableAsciiPunctuation(label[i + 1])) {
            i += 1;
            continue;
        }
        if (label[i] == '[' or label[i] == ']') return false;
    }

    return true;
}

fn isReferenceLabelWhitespace(ch: u8) bool {
    return ch == ' ' or ch == '\t' or ch == '\r' or ch == '\n';
}

const FoldedCodepoint = struct {
    first: u21,
    second: ?u21 = null,
    third: ?u21 = null,
};

const ReferenceLabelCursor = struct {
    text: []const u8,
    index: usize = 0,
    pending: [2]u21 = undefined,
    pending_len: u2 = 0,

    fn finished(self: ReferenceLabelCursor) bool {
        return self.pending_len == 0 and self.index >= self.text.len;
    }

    fn atWhitespace(self: ReferenceLabelCursor) bool {
        return self.pending_len == 0 and self.index < self.text.len and isReferenceLabelWhitespace(self.text[self.index]);
    }

    fn skipWhitespaceRun(self: *ReferenceLabelCursor) void {
        if (self.pending_len != 0) return;
        while (self.index < self.text.len and isReferenceLabelWhitespace(self.text[self.index])) : (self.index += 1) {}
    }

    fn nextFolded(self: *ReferenceLabelCursor) ?u21 {
        if (self.pending_len != 0) {
            const codepoint = self.pending[0];
            if (self.pending_len == 2) self.pending[0] = self.pending[1];
            self.pending_len -= 1;
            return codepoint;
        }
        if (self.index >= self.text.len) return null;

        const codepoint: u21 = if (self.text[self.index] < 0x80) ascii_label: {
            const ch = self.text[self.index];
            self.index += 1;
            break :ascii_label std.ascii.toLower(ch);
        } else if (decodeUtf8At(self.text, self.index)) |decoded| utf8_label: {
            self.index += decoded.len;
            break :utf8_label decoded.codepoint;
        } else invalid_label: {
            const ch = self.text[self.index];
            self.index += 1;
            break :invalid_label ch;
        };

        const folded = foldReferenceLabelCodepoint(codepoint);
        self.pending_len = 0;
        if (folded.second) |second| {
            self.pending[0] = second;
            self.pending_len = 1;
            if (folded.third) |third| {
                self.pending[1] = third;
                self.pending_len = 2;
            }
        }
        return folded.first;
    }
};

fn foldReferenceLabelCodepoint(codepoint: u21) FoldedCodepoint {
    if (codepoint == 0x00b5) return .{ .first = 0x03bc };
    if (codepoint == 0x00df or codepoint == 0x1e9e) return .{ .first = 's', .second = 's' };
    if (codepoint == 0x0130) return .{ .first = 'i', .second = 0x0307 };
    if (codepoint == 0x017f) return .{ .first = 's' };
    if (codepoint == 0x01c4 or codepoint == 0x01c5) return .{ .first = 0x01c6 };
    if (codepoint == 0x2126) return .{ .first = 0x03c9 };
    if (codepoint == 0x212a) return .{ .first = 'k' };
    if (codepoint == 0x212b) return .{ .first = 0x00e5 };
    if (codepoint == 0xfb00) return .{ .first = 'f', .second = 'f' };
    if (codepoint == 0xfb01) return .{ .first = 'f', .second = 'i' };
    if (codepoint == 0xfb02) return .{ .first = 'f', .second = 'l' };
    if (codepoint == 0xfb03) return .{ .first = 'f', .second = 'f', .third = 'i' };
    if (codepoint == 0xfb04) return .{ .first = 'f', .second = 'f', .third = 'l' };
    if (codepoint == 0xfb05 or codepoint == 0xfb06) return .{ .first = 's', .second = 't' };
    if (codepoint == 0x010e) return .{ .first = 0x010f };
    if (codepoint == 0x0386) return .{ .first = 0x03ac };
    if (codepoint == 0x0388) return .{ .first = 0x03ad };
    if (codepoint == 0x0389) return .{ .first = 0x03ae };
    if (codepoint == 0x038a) return .{ .first = 0x03af };
    if (codepoint == 0x038c) return .{ .first = 0x03cc };
    if (codepoint == 0x038e) return .{ .first = 0x03cd };
    if (codepoint == 0x038f) return .{ .first = 0x03ce };

    if (codepoint >= 'A' and codepoint <= 'Z') return .{ .first = codepoint + 32 };
    if (codepoint >= 0x0100 and codepoint <= 0x012f and codepoint % 2 == 0) return .{ .first = codepoint + 1 };
    if (codepoint >= 0x0132 and codepoint <= 0x0137 and codepoint % 2 == 0) return .{ .first = codepoint + 1 };
    if (codepoint >= 0x0139 and codepoint <= 0x0148 and codepoint % 2 == 1) return .{ .first = codepoint + 1 };
    if (codepoint >= 0x014a and codepoint <= 0x0177 and codepoint % 2 == 0) return .{ .first = codepoint + 1 };
    if (codepoint >= 0x0179 and codepoint <= 0x017e and codepoint % 2 == 1) return .{ .first = codepoint + 1 };
    if (codepoint >= 0x00c0 and codepoint <= 0x00d6) return .{ .first = codepoint + 32 };
    if (codepoint >= 0x00d8 and codepoint <= 0x00de) return .{ .first = codepoint + 32 };
    if (codepoint == 0x0178) return .{ .first = 0x00ff };

    if (codepoint >= 0x0391 and codepoint <= 0x03a1) return .{ .first = codepoint + 32 };
    if (codepoint >= 0x03a3 and codepoint <= 0x03ab) return .{ .first = codepoint + 32 };
    if (codepoint == 0x03c2) return .{ .first = 0x03c3 };

    if (codepoint >= 0x0410 and codepoint <= 0x042f) return .{ .first = codepoint + 32 };

    return .{ .first = codepoint };
}

fn canUseSimpleEmphasis(text: []const u8, start: usize, end: usize, marker_len: usize, marker: u8) bool {
    if (end <= start + marker_len) return false;

    const after_open = start + marker_len;
    const after_close = end + marker_len;
    if (after_open >= text.len) return false;
    if (isAsciiWhitespace(text[after_open]) or isAsciiWhitespace(text[end - 1])) return false;

    const before_start_is_word = start > 0 and isAsciiWord(text[start - 1]);
    const after_start_is_word = isAsciiWord(text[after_open]);
    const before_end_is_word = end > 0 and isAsciiWord(text[end - 1]);
    const after_end_is_word = after_close < text.len and isAsciiWord(text[after_close]);
    const before_start_is_space = start == 0 or isAsciiWhitespace(text[start - 1]);
    const before_start_is_punctuation = start > 0 and isAsciiPunctuation(text[start - 1]);
    const after_start_is_punctuation = isAsciiPunctuation(text[after_open]);
    const before_end_is_punctuation = isAsciiPunctuation(text[end - 1]);
    const after_end_is_space = after_close >= text.len or isAsciiWhitespace(text[after_close]);
    const after_end_is_punctuation = after_close < text.len and isAsciiPunctuation(text[after_close]);

    if (after_start_is_punctuation and !before_start_is_space and !before_start_is_punctuation) return false;
    if (before_end_is_punctuation and !after_end_is_space and !after_end_is_punctuation) return false;

    if (marker != '*') {
        if (before_start_is_word and after_start_is_word) return false;
        if (before_end_is_word and after_end_is_word) return false;
    }
    return true;
}

fn isAsciiPunctuation(ch: u8) bool {
    return isEscapableAsciiPunctuation(ch);
}

fn adjustedStrongClose(text: []const u8, start: usize, end: usize, marker: u8) usize {
    if (end + 2 >= text.len or text[end] != marker or text[end + 1] != marker or text[end + 2] != marker) {
        return end;
    }

    if (std.mem.indexOfScalar(u8, text[start + 2 .. end], marker) == null) {
        return end;
    }

    return end + 1;
}

fn findEmphasisClose(text: []const u8, start: usize, marker_len: usize, marker: u8) ?usize {
    var search = start + marker_len;
    while (findMarkerRunFrom(text, search, marker, marker_len)) |raw_end| {
        if (marker == '_' and marker_len == 1 and isIntrawordUnderscoreRun(text, raw_end)) {
            search = markerRunEnd(text, raw_end, marker);
            continue;
        }

        const close = if (marker_len == 2) adjustedStrongClose(text, start, raw_end, marker) else raw_end;
        if (!isEscapedAt(text, raw_end) and
            canUseSimpleEmphasis(text, start, close, marker_len, marker) and
            !singleEmphasisCloseBelongsToNestedStrong(text, start, close, marker_len, marker))
        {
            return close;
        }
        search = raw_end + marker_len;
    }
    return null;
}

fn isIntrawordUnderscoreRun(text: []const u8, pos: usize) bool {
    const run_start = markerRunStart(text, pos, '_');
    const run_end = markerRunEnd(text, pos, '_');
    if (run_end - run_start < 2) return false;
    if (run_start == 0 or run_end >= text.len) return false;

    return isAsciiWord(text[run_start - 1]) and isAsciiWord(text[run_end]);
}

fn singleEmphasisCloseBelongsToNestedStrong(text: []const u8, start: usize, close: usize, marker_len: usize, marker: u8) bool {
    if (marker_len != 1) return false;

    const run_start = markerRunStart(text, close, marker);
    const run_end = markerRunEnd(text, close, marker);
    const run_len = run_end - run_start;
    if (run_len < 2) return false;

    if (!hasUnclosedStrongRunBefore(text, start + 1, run_start, marker)) return false;

    // A closing run of three markers can close an inner strong span with two
    // markers and still leave the final marker for the surrounding emphasis.
    if (run_len >= 3 and close == run_end - 1) return false;

    return true;
}

fn markerRunStart(text: []const u8, pos: usize, marker: u8) usize {
    var start = pos;
    while (start > 0 and text[start - 1] == marker) : (start -= 1) {}
    return start;
}

fn markerRunEnd(text: []const u8, pos: usize, marker: u8) usize {
    var end = pos;
    while (end < text.len and text[end] == marker) : (end += 1) {}
    return end;
}

fn hasUnclosedStrongRunBefore(text: []const u8, start: usize, limit: usize, marker: u8) bool {
    var open_count: usize = 0;
    var i = start;
    while (i + 1 < limit) {
        if (text[i] != marker or text[i + 1] != marker or isEscapedAt(text, i)) {
            i += 1;
            continue;
        }

        const run_len = markerRunEnd(text, i, marker) - i;
        if (open_count > 0 and canCloseEmphasisRun(text, i, 2, marker)) {
            open_count -= 1;
        } else if (canOpenEmphasisRun(text, i, 2, marker)) {
            open_count += 1;
        }
        i += run_len;
    }

    return open_count > 0;
}

fn canOpenEmphasisRun(text: []const u8, start: usize, marker_len: usize, marker: u8) bool {
    const after_open = start + marker_len;
    if (after_open >= text.len) return false;
    if (isAsciiWhitespace(text[after_open])) return false;

    const before_start_is_word = start > 0 and isAsciiWord(text[start - 1]);
    const after_start_is_word = isAsciiWord(text[after_open]);
    const before_start_is_space = start == 0 or isAsciiWhitespace(text[start - 1]);
    const before_start_is_punctuation = start > 0 and isAsciiPunctuation(text[start - 1]);
    const after_start_is_punctuation = isAsciiPunctuation(text[after_open]);

    if (after_start_is_punctuation and !before_start_is_space and !before_start_is_punctuation) return false;
    if (marker != '*' and before_start_is_word and after_start_is_word) return false;
    return true;
}

fn canCloseEmphasisRun(text: []const u8, start: usize, marker_len: usize, marker: u8) bool {
    if (start == 0) return false;
    if (isAsciiWhitespace(text[start - 1])) return false;

    const after_close = start + marker_len;
    const before_end_is_word = isAsciiWord(text[start - 1]);
    const after_end_is_word = after_close < text.len and isAsciiWord(text[after_close]);
    const before_end_is_punctuation = isAsciiPunctuation(text[start - 1]);
    const after_end_is_space = after_close >= text.len or isAsciiWhitespace(text[after_close]);
    const after_end_is_punctuation = after_close < text.len and isAsciiPunctuation(text[after_close]);

    if (before_end_is_punctuation and !after_end_is_space and !after_end_is_punctuation) return false;
    if (marker != '*' and before_end_is_word and after_end_is_word) return false;
    return true;
}

fn findEscapedStrongMarkerPair(text: []const u8, start: usize, end: usize, marker: u8) ?usize {
    var i = start;
    while (i + 2 < end) : (i += 1) {
        if (text[i] == '\\' and !isEscapedAt(text, i) and text[i + 1] == marker and text[i + 2] == marker) return i;
    }
    return null;
}

fn findMarkerRunFrom(text: []const u8, start: usize, marker: u8, marker_len: usize) ?usize {
    var i = start;
    while (i + marker_len <= text.len) : (i += 1) {
        var matched = true;
        var j: usize = 0;
        while (j < marker_len) : (j += 1) {
            if (text[i + j] != marker) {
                matched = false;
                break;
            }
        }
        if (matched) return i;
    }
    return null;
}

fn appendRtfStarRunOpen(out: *std.ArrayList(u8), allocator: std.mem.Allocator, run_len: usize) !void {
    if (run_len % 2 == 0) {
        try out.appendSlice(allocator, "\\b ");
    } else if (run_len == 1) {
        try out.appendSlice(allocator, "\\i ");
    } else {
        try out.appendSlice(allocator, "\\b\\i ");
    }
}

fn appendRtfStarRunClose(out: *std.ArrayList(u8), allocator: std.mem.Allocator, run_len: usize) !void {
    if (run_len % 2 == 0) {
        try out.appendSlice(allocator, "\\b0 ");
    } else if (run_len == 1) {
        try out.appendSlice(allocator, "\\i0 ");
    } else {
        try out.appendSlice(allocator, "\\i0\\b0 ");
    }
}

fn isAsciiWord(ch: u8) bool {
    return ch >= 0x80 or
        (ch >= 'a' and ch <= 'z') or
        (ch >= 'A' and ch <= 'Z') or
        (ch >= '0' and ch <= '9');
}

fn isAsciiWhitespace(ch: u8) bool {
    return ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r';
}

fn parseCodeSpan(text: []const u8, start: usize) ?CodeSpan {
    if (start >= text.len or text[start] != '`') return null;
    const ticks = backtickRunLength(text, start);
    var i = start + ticks;

    while (i < text.len) {
        if (text[i] != '`') {
            i += 1;
            continue;
        }

        const run = backtickRunLength(text, i);
        if (run == ticks) {
            return .{ .content = text[start + ticks .. i], .end = i + ticks };
        }
        i += run;
    }

    return null;
}

fn backtickRunLength(text: []const u8, start: usize) usize {
    var i = start;
    while (i < text.len and text[i] == '`') : (i += 1) {}
    return i - start;
}

fn codeSpanContainsNonSpace(content: []const u8) bool {
    for (content) |ch| {
        if (ch != ' ') return true;
    }

    return false;
}

fn normalizeCodeSpan(allocator: std.mem.Allocator, content: []const u8) ![]u8 {
    var normalized: std.ArrayList(u8) = .empty;
    errdefer normalized.deinit(allocator);

    var i: usize = 0;
    while (i < content.len) : (i += 1) {
        if (content[i] == '\r') {
            try normalized.append(allocator, ' ');
            if (i + 1 < content.len and content[i + 1] == '\n') i += 1;
        } else if (content[i] == '\n') {
            try normalized.append(allocator, ' ');
        } else {
            try normalized.append(allocator, content[i]);
        }
    }

    var start: usize = 0;
    var end: usize = normalized.items.len;
    if (normalized.items.len >= 2 and normalized.items[0] == ' ' and normalized.items[normalized.items.len - 1] == ' ' and codeSpanContainsNonSpace(normalized.items)) {
        start = 1;
        end = normalized.items.len - 1;
    }

    if (start == 0 and end == normalized.items.len) {
        return normalized.toOwnedSlice(allocator);
    }

    const trimmed = try allocator.dupe(u8, normalized.items[start..end]);
    normalized.deinit(allocator);
    return trimmed;
}

fn appendInline(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8, refs: []const ReferenceDef) !void {
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '\\' and i + 1 < text.len and isEscapableAsciiPunctuation(text[i + 1])) {
            try out.append(allocator, text[i + 1]);
            i += 2;
            continue;
        }

        if (text[i] == '&') {
            if (try appendEntity(out, allocator, text, i)) |next| {
                i = next;
                continue;
            }
        }

        if (text[i] == '<') {
            if (findByteFrom(text, i + 1, '>')) |close_angle| {
                const target = text[i + 1 .. close_angle];
                if (isAutoLink(target)) {
                    try out.appendSlice(allocator, target);
                    i = close_angle + 1;
                    continue;
                }
            }
        }

        if (std.mem.startsWith(u8, text[i..], "![")) {
            if (findLinkCloseBracket(text, i + 2)) |close_bracket| {
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (findLinkCloseParen(text, close_bracket + 2)) |close_paren| {
                        if (inlineLinkDestination(text[close_bracket + 2 .. close_paren])) |dest| {
                            try out.appendSlice(allocator, "[image: ");
                            try appendInlineNoLinks(out, allocator, text[i + 2 .. close_bracket], refs);
                            try out.appendSlice(allocator, "] <");
                            try appendEscapedMarkdownText(out, allocator, dest);
                            try out.append(allocator, '>');
                            i = close_paren + 1;
                            continue;
                        }
                    }
                }

                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '[') {
                    if (findLinkCloseBracket(text, close_bracket + 2)) |close_label| {
                        const explicit_label = text[close_bracket + 2 .. close_label];
                        const label = if (explicit_label.len == 0) text[i + 2 .. close_bracket] else explicit_label;
                        if (findReference(refs, label)) |dest| {
                            try out.appendSlice(allocator, "[image: ");
                            try appendInlineNoLinks(out, allocator, text[i + 2 .. close_bracket], refs);
                            try out.appendSlice(allocator, "] <");
                            try appendEscapedMarkdownText(out, allocator, dest);
                            try out.append(allocator, '>');
                            i = close_label + 1;
                            continue;
                        }
                    }
                } else if (findReference(refs, text[i + 2 .. close_bracket])) |dest| {
                    try out.appendSlice(allocator, "[image: ");
                    try appendInlineNoLinks(out, allocator, text[i + 2 .. close_bracket], refs);
                    try out.appendSlice(allocator, "] <");
                    try appendEscapedMarkdownText(out, allocator, dest);
                    try out.append(allocator, '>');
                    i = close_bracket + 1;
                    continue;
                }
            }
        }

        if (text[i] == '[') {
            if (findLinkCloseBracket(text, i + 1)) |close_bracket| {
                const label_text = text[i + 1 .. close_bracket];
                const label_has_link = labelContainsInlineLink(label_text, refs);
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (!label_has_link) {
                        if (findLinkCloseParen(text, close_bracket + 2)) |close_paren| {
                            if (inlineLinkDestination(text[close_bracket + 2 .. close_paren])) |dest| {
                                try appendInline(out, allocator, label_text, refs);
                                try out.appendSlice(allocator, " <");
                                try appendEscapedMarkdownText(out, allocator, dest);
                                try out.append(allocator, '>');
                                i = close_paren + 1;
                                continue;
                            }
                        }
                    }
                }

                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '[') {
                    if (!label_has_link) {
                        if (findLinkCloseBracket(text, close_bracket + 2)) |close_label| {
                            const explicit_label = text[close_bracket + 2 .. close_label];
                            const label = if (explicit_label.len == 0) label_text else explicit_label;
                            if (findReference(refs, label)) |dest| {
                                try appendInline(out, allocator, label_text, refs);
                                try out.appendSlice(allocator, " <");
                                try appendEscapedMarkdownText(out, allocator, dest);
                                try out.append(allocator, '>');
                                i = close_label + 1;
                                continue;
                            }
                        }
                    }
                } else if (!label_has_link) {
                    if (findReference(refs, label_text)) |dest| {
                        try appendInline(out, allocator, label_text, refs);
                        try out.appendSlice(allocator, " <");
                        try appendEscapedMarkdownText(out, allocator, dest);
                        try out.append(allocator, '>');
                        i = close_bracket + 1;
                        continue;
                    }
                }
            }
        }

        if (std.mem.startsWith(u8, text[i..], "~~")) {
            if (findSliceFrom(text, i + 2, "~~")) |end| {
                if (canUseSimpleEmphasis(text, i, end, 2, '~')) {
                    try appendInline(out, allocator, text[i + 2 .. end], refs);
                    i = end + 2;
                    continue;
                }
            }
            try out.appendSlice(allocator, "~~");
            i += 2;
            continue;
        }

        if (text[i] == '*') {
            const run_len = markerRunEnd(text, i, '*') - i;
            if (run_len > 3) {
                if (findEmphasisClose(text, i, run_len, '*')) |end| {
                    try appendInline(out, allocator, text[i + run_len .. end], refs);
                    i = end + run_len;
                    continue;
                }
            }
        }

        if (std.mem.startsWith(u8, text[i..], "***")) {
            if (findEmphasisClose(text, i, 3, '*')) |end| {
                try appendInline(out, allocator, text[i + 3 .. end], refs);
                i = end + 3;
                continue;
            }
            try out.appendSlice(allocator, "***");
            i += 3;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "___")) {
            if (findEmphasisClose(text, i, 3, '_')) |end| {
                try appendInline(out, allocator, text[i + 3 .. end], refs);
                i = end + 3;
                continue;
            }
            try out.appendSlice(allocator, "___");
            i += 3;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "**")) {
            if (findEmphasisClose(text, i, 2, '*')) |close| {
                if (findEscapedStrongMarkerPair(text, i + 2, close, '*')) |escaped| {
                    try appendInline(out, allocator, text[i + 2 .. escaped], refs);
                    try out.append(allocator, '*');
                    try appendInline(out, allocator, text[escaped + 3 .. close], refs);
                    try out.append(allocator, '*');
                    i = close + 2;
                    continue;
                }
                try appendInline(out, allocator, text[i + 2 .. close], refs);
                i = close + 2;
                continue;
            }
            try out.appendSlice(allocator, "**");
            i += 2;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "__")) {
            if (findEmphasisClose(text, i, 2, '_')) |close| {
                if (findEscapedStrongMarkerPair(text, i + 2, close, '_')) |escaped| {
                    try appendInline(out, allocator, text[i + 2 .. escaped], refs);
                    try out.append(allocator, '_');
                    try appendInline(out, allocator, text[escaped + 3 .. close], refs);
                    try out.append(allocator, '_');
                    i = close + 2;
                    continue;
                }
                try appendInline(out, allocator, text[i + 2 .. close], refs);
                i = close + 2;
                continue;
            }
            try out.appendSlice(allocator, "__");
            i += 2;
            continue;
        }

        if (text[i] == '*') {
            if (findEmphasisClose(text, i, 1, '*')) |end| {
                try appendInline(out, allocator, text[i + 1 .. end], refs);
                i = end + 1;
                continue;
            }
        }

        if (text[i] == '_') {
            if (findEmphasisClose(text, i, 1, '_')) |end| {
                try appendInline(out, allocator, text[i + 1 .. end], refs);
                i = end + 1;
                continue;
            }
        }

        if (text[i] == '`') {
            if (parseCodeSpan(text, i)) |code| {
                const normalized = try normalizeCodeSpan(allocator, code.content);
                defer allocator.free(normalized);
                try out.appendSlice(allocator, normalized);
                i = code.end;
                continue;
            }
            const ticks = backtickRunLength(text, i);
            try out.appendSlice(allocator, text[i .. i + ticks]);
            i += ticks;
            continue;
        }

        try out.append(allocator, text[i]);
        i += 1;
    }
}

fn appendInlineNoLinks(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8, refs: []const ReferenceDef) !void {
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '\\' and i + 1 < text.len and isEscapableAsciiPunctuation(text[i + 1])) {
            try out.append(allocator, text[i + 1]);
            i += 2;
            continue;
        }

        if (text[i] == '&') {
            if (try appendEntity(out, allocator, text, i)) |next| {
                i = next;
                continue;
            }
        }

        if (text[i] == '<') {
            if (findByteFrom(text, i + 1, '>')) |close_angle| {
                const target = text[i + 1 .. close_angle];
                if (isAutoLink(target)) {
                    try out.appendSlice(allocator, target);
                    i = close_angle + 1;
                    continue;
                }
            }
        }

        if (std.mem.startsWith(u8, text[i..], "![")) {
            if (findLinkCloseBracket(text, i + 2)) |close_bracket| {
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (findLinkCloseParen(text, close_bracket + 2)) |close_paren| {
                        if (inlineLinkDestination(text[close_bracket + 2 .. close_paren]) != null) {
                            try appendInlineNoLinks(out, allocator, text[i + 2 .. close_bracket], refs);
                            i = close_paren + 1;
                            continue;
                        }
                    }
                }

                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '[') {
                    if (findLinkCloseBracket(text, close_bracket + 2)) |close_label| {
                        const explicit_label = text[close_bracket + 2 .. close_label];
                        const label = if (explicit_label.len == 0) text[i + 2 .. close_bracket] else explicit_label;
                        if (findReference(refs, label) != null) {
                            try appendInlineNoLinks(out, allocator, text[i + 2 .. close_bracket], refs);
                            i = close_label + 1;
                            continue;
                        }
                    }
                } else if (findReference(refs, text[i + 2 .. close_bracket]) != null) {
                    try appendInlineNoLinks(out, allocator, text[i + 2 .. close_bracket], refs);
                    i = close_bracket + 1;
                    continue;
                }
            }
        }

        if (text[i] == '[') {
            if (findLinkCloseBracket(text, i + 1)) |close_bracket| {
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (findLinkCloseParen(text, close_bracket + 2)) |close_paren| {
                        if (inlineLinkDestination(text[close_bracket + 2 .. close_paren]) != null) {
                            try appendInlineNoLinks(out, allocator, text[i + 1 .. close_bracket], refs);
                            i = close_paren + 1;
                            continue;
                        }
                    }
                }

                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '[') {
                    if (findLinkCloseBracket(text, close_bracket + 2)) |close_label| {
                        const explicit_label = text[close_bracket + 2 .. close_label];
                        const label = if (explicit_label.len == 0) text[i + 1 .. close_bracket] else explicit_label;
                        if (findReference(refs, label) != null) {
                            try appendInlineNoLinks(out, allocator, text[i + 1 .. close_bracket], refs);
                            i = close_label + 1;
                            continue;
                        }
                    }
                } else if (findReference(refs, text[i + 1 .. close_bracket]) != null) {
                    try appendInlineNoLinks(out, allocator, text[i + 1 .. close_bracket], refs);
                    i = close_bracket + 1;
                    continue;
                }
            }
        }

        if (std.mem.startsWith(u8, text[i..], "~~")) {
            if (findSliceFrom(text, i + 2, "~~")) |end| {
                if (canUseSimpleEmphasis(text, i, end, 2, '~')) {
                    try appendInlineNoLinks(out, allocator, text[i + 2 .. end], refs);
                    i = end + 2;
                    continue;
                }
            }
            try out.appendSlice(allocator, "~~");
            i += 2;
            continue;
        }

        if (text[i] == '*') {
            const run_len = markerRunEnd(text, i, '*') - i;
            if (run_len > 3) {
                if (findEmphasisClose(text, i, run_len, '*')) |end| {
                    try appendInlineNoLinks(out, allocator, text[i + run_len .. end], refs);
                    i = end + run_len;
                    continue;
                }
            }
        }

        if (std.mem.startsWith(u8, text[i..], "***")) {
            if (findEmphasisClose(text, i, 3, '*')) |end| {
                try appendInlineNoLinks(out, allocator, text[i + 3 .. end], refs);
                i = end + 3;
                continue;
            }
            try out.appendSlice(allocator, "***");
            i += 3;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "___")) {
            if (findEmphasisClose(text, i, 3, '_')) |end| {
                try appendInlineNoLinks(out, allocator, text[i + 3 .. end], refs);
                i = end + 3;
                continue;
            }
            try out.appendSlice(allocator, "___");
            i += 3;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "**")) {
            if (findEmphasisClose(text, i, 2, '*')) |close| {
                if (findEscapedStrongMarkerPair(text, i + 2, close, '*')) |escaped| {
                    try appendInlineNoLinks(out, allocator, text[i + 2 .. escaped], refs);
                    try out.append(allocator, '*');
                    try appendInlineNoLinks(out, allocator, text[escaped + 3 .. close], refs);
                    try out.append(allocator, '*');
                    i = close + 2;
                    continue;
                }
                try appendInlineNoLinks(out, allocator, text[i + 2 .. close], refs);
                i = close + 2;
                continue;
            }
            try out.appendSlice(allocator, "**");
            i += 2;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "__")) {
            if (findEmphasisClose(text, i, 2, '_')) |close| {
                if (findEscapedStrongMarkerPair(text, i + 2, close, '_')) |escaped| {
                    try appendInlineNoLinks(out, allocator, text[i + 2 .. escaped], refs);
                    try out.append(allocator, '_');
                    try appendInlineNoLinks(out, allocator, text[escaped + 3 .. close], refs);
                    try out.append(allocator, '_');
                    i = close + 2;
                    continue;
                }
                try appendInlineNoLinks(out, allocator, text[i + 2 .. close], refs);
                i = close + 2;
                continue;
            }
            try out.appendSlice(allocator, "__");
            i += 2;
            continue;
        }

        if (text[i] == '*') {
            if (findEmphasisClose(text, i, 1, '*')) |end| {
                try appendInlineNoLinks(out, allocator, text[i + 1 .. end], refs);
                i = end + 1;
                continue;
            }
        }

        if (text[i] == '_') {
            if (findEmphasisClose(text, i, 1, '_')) |end| {
                try appendInlineNoLinks(out, allocator, text[i + 1 .. end], refs);
                i = end + 1;
                continue;
            }
        }

        if (text[i] == '`') {
            if (parseCodeSpan(text, i)) |code| {
                const normalized = try normalizeCodeSpan(allocator, code.content);
                defer allocator.free(normalized);
                try out.appendSlice(allocator, normalized);
                i = code.end;
                continue;
            }
            const ticks = backtickRunLength(text, i);
            try out.appendSlice(allocator, text[i .. i + ticks]);
            i += ticks;
            continue;
        }

        try out.append(allocator, text[i]);
        i += 1;
    }
}

fn labelContainsInlineLink(text: []const u8, refs: []const ReferenceDef) bool {
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text[i] != '[') continue;
        if (i > 0 and text[i - 1] == '!') continue;

        const close_bracket = findLinkCloseBracket(text, i + 1) orelse continue;
        if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
            if (findLinkCloseParen(text, close_bracket + 2)) |close_paren| {
                if (inlineLinkDestination(text[close_bracket + 2 .. close_paren]) != null) return true;
            }
        } else if (close_bracket + 1 < text.len and text[close_bracket + 1] == '[') {
            if (findLinkCloseBracket(text, close_bracket + 2)) |close_label| {
                const explicit_label = text[close_bracket + 2 .. close_label];
                const label = if (explicit_label.len == 0) text[i + 1 .. close_bracket] else explicit_label;
                if (findReference(refs, label) != null) return true;
            }
        } else if (findReference(refs, text[i + 1 .. close_bracket]) != null) {
            return true;
        }
    }

    return false;
}

fn appendInlineRtf(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8, refs: []const ReferenceDef) !void {
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '\\' and i + 1 < text.len and isEscapableAsciiPunctuation(text[i + 1])) {
            try appendRtfEscapedByte(out, allocator, text[i + 1]);
            i += 2;
            continue;
        }

        if (text[i] == '&') {
            if (try appendEntityRtf(out, allocator, text, i)) |next| {
                i = next;
                continue;
            }
        }

        if (text[i] == '<') {
            if (findByteFrom(text, i + 1, '>')) |close_angle| {
                const target = text[i + 1 .. close_angle];
                if (isAutoLink(target)) {
                    try out.appendSlice(allocator, "\\cf3\\ul ");
                    try appendRtfEscaped(out, allocator, target);
                    try out.appendSlice(allocator, "\\ulnone\\cf1 ");
                    i = close_angle + 1;
                    continue;
                }
            }
        }

        if (std.mem.startsWith(u8, text[i..], "![")) {
            if (findLinkCloseBracket(text, i + 2)) |close_bracket| {
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (findLinkCloseParen(text, close_bracket + 2)) |close_paren| {
                        if (inlineLinkDestination(text[close_bracket + 2 .. close_paren])) |dest| {
                            try out.appendSlice(allocator, "\\cf2 [image: ");
                            try appendImageAltRtf(out, allocator, text[i + 2 .. close_bracket], refs);
                            try out.appendSlice(allocator, "] ");
                            try appendEscapedMarkdownTextRtf(out, allocator, dest);
                            try out.appendSlice(allocator, "\\cf1 ");
                            i = close_paren + 1;
                            continue;
                        }
                    }
                }

                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '[') {
                    if (findLinkCloseBracket(text, close_bracket + 2)) |close_label| {
                        const explicit_label = text[close_bracket + 2 .. close_label];
                        const label = if (explicit_label.len == 0) text[i + 2 .. close_bracket] else explicit_label;
                        if (findReference(refs, label)) |dest| {
                            try out.appendSlice(allocator, "\\cf2 [image: ");
                            try appendImageAltRtf(out, allocator, text[i + 2 .. close_bracket], refs);
                            try out.appendSlice(allocator, "] ");
                            try appendEscapedMarkdownTextRtf(out, allocator, dest);
                            try out.appendSlice(allocator, "\\cf1 ");
                            i = close_label + 1;
                            continue;
                        }
                    }
                } else if (findReference(refs, text[i + 2 .. close_bracket])) |dest| {
                    try out.appendSlice(allocator, "\\cf2 [image: ");
                    try appendImageAltRtf(out, allocator, text[i + 2 .. close_bracket], refs);
                    try out.appendSlice(allocator, "] ");
                    try appendEscapedMarkdownTextRtf(out, allocator, dest);
                    try out.appendSlice(allocator, "\\cf1 ");
                    i = close_bracket + 1;
                    continue;
                }
            }
        }

        if (text[i] == '[') {
            if (findLinkCloseBracket(text, i + 1)) |close_bracket| {
                const label_text = text[i + 1 .. close_bracket];
                const label_has_link = labelContainsInlineLink(label_text, refs);
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (!label_has_link) {
                        if (findLinkCloseParen(text, close_bracket + 2)) |close_paren| {
                            if (inlineLinkDestination(text[close_bracket + 2 .. close_paren])) |dest| {
                                try out.appendSlice(allocator, "\\cf3\\ul ");
                                try appendInlineRtf(out, allocator, label_text, refs);
                                try out.appendSlice(allocator, "\\ulnone\\cf1 ");
                                try out.appendSlice(allocator, "\\cf2 <");
                                try appendEscapedMarkdownTextRtf(out, allocator, dest);
                                try out.appendSlice(allocator, ">\\cf1 ");
                                i = close_paren + 1;
                                continue;
                            }
                        }
                    }
                }

                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '[') {
                    if (!label_has_link) {
                        if (findLinkCloseBracket(text, close_bracket + 2)) |close_label| {
                            const explicit_label = text[close_bracket + 2 .. close_label];
                            const label = if (explicit_label.len == 0) label_text else explicit_label;
                            if (findReference(refs, label)) |dest| {
                                try out.appendSlice(allocator, "\\cf3\\ul ");
                                try appendInlineRtf(out, allocator, label_text, refs);
                                try out.appendSlice(allocator, "\\ulnone\\cf1 ");
                                try out.appendSlice(allocator, "\\cf2 <");
                                try appendEscapedMarkdownTextRtf(out, allocator, dest);
                                try out.appendSlice(allocator, ">\\cf1 ");
                                i = close_label + 1;
                                continue;
                            }
                        }
                    }
                } else if (!label_has_link) {
                    if (findReference(refs, label_text)) |dest| {
                        try out.appendSlice(allocator, "\\cf3\\ul ");
                        try appendInlineRtf(out, allocator, label_text, refs);
                        try out.appendSlice(allocator, "\\ulnone\\cf1 ");
                        try out.appendSlice(allocator, "\\cf2 <");
                        try appendEscapedMarkdownTextRtf(out, allocator, dest);
                        try out.appendSlice(allocator, ">\\cf1 ");
                        i = close_bracket + 1;
                        continue;
                    }
                }
            }
        }

        if (text[i] == '*') {
            const run_len = markerRunEnd(text, i, '*') - i;
            if (run_len > 3) {
                if (findEmphasisClose(text, i, run_len, '*')) |end| {
                    try appendRtfStarRunOpen(out, allocator, run_len);
                    try appendInlineRtf(out, allocator, text[i + run_len .. end], refs);
                    try appendRtfStarRunClose(out, allocator, run_len);
                    i = end + run_len;
                    continue;
                }
            }
        }

        if (std.mem.startsWith(u8, text[i..], "***")) {
            if (findEmphasisClose(text, i, 3, '*')) |end| {
                try out.appendSlice(allocator, "\\b\\i ");
                try appendInlineRtf(out, allocator, text[i + 3 .. end], refs);
                try out.appendSlice(allocator, "\\i0\\b0 ");
                i = end + 3;
                continue;
            }
            try out.appendSlice(allocator, "***");
            i += 3;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "___")) {
            if (findEmphasisClose(text, i, 3, '_')) |end| {
                try out.appendSlice(allocator, "\\b\\i ");
                try appendInlineRtf(out, allocator, text[i + 3 .. end], refs);
                try out.appendSlice(allocator, "\\i0\\b0 ");
                i = end + 3;
                continue;
            }
            try out.appendSlice(allocator, "___");
            i += 3;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "**")) {
            if (findEmphasisClose(text, i, 2, '*')) |close| {
                if (findEscapedStrongMarkerPair(text, i + 2, close, '*')) |escaped| {
                    try out.appendSlice(allocator, "\\i ");
                    try appendInlineRtf(out, allocator, text[i + 2 .. escaped], refs);
                    try out.append(allocator, '*');
                    try appendInlineRtf(out, allocator, text[escaped + 3 .. close], refs);
                    try out.appendSlice(allocator, "\\i0 ");
                    try out.append(allocator, '*');
                    i = close + 2;
                    continue;
                }
                try out.appendSlice(allocator, "\\b ");
                try appendInlineRtf(out, allocator, text[i + 2 .. close], refs);
                try out.appendSlice(allocator, "\\b0 ");
                i = close + 2;
                continue;
            }
            try out.appendSlice(allocator, "**");
            i += 2;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "__")) {
            if (findEmphasisClose(text, i, 2, '_')) |close| {
                if (findEscapedStrongMarkerPair(text, i + 2, close, '_')) |escaped| {
                    try out.appendSlice(allocator, "\\i ");
                    try appendInlineRtf(out, allocator, text[i + 2 .. escaped], refs);
                    try out.append(allocator, '_');
                    try appendInlineRtf(out, allocator, text[escaped + 3 .. close], refs);
                    try out.appendSlice(allocator, "\\i0 ");
                    try out.append(allocator, '_');
                    i = close + 2;
                    continue;
                }
                try out.appendSlice(allocator, "\\b ");
                try appendInlineRtf(out, allocator, text[i + 2 .. close], refs);
                try out.appendSlice(allocator, "\\b0 ");
                i = close + 2;
                continue;
            }
            try out.appendSlice(allocator, "__");
            i += 2;
            continue;
        }

        if (text[i] == '*') {
            if (findEmphasisClose(text, i, 1, '*')) |end| {
                try out.appendSlice(allocator, "\\i ");
                try appendInlineRtf(out, allocator, text[i + 1 .. end], refs);
                try out.appendSlice(allocator, "\\i0 ");
                i = end + 1;
                continue;
            }
        }

        if (text[i] == '_') {
            if (findEmphasisClose(text, i, 1, '_')) |end| {
                try out.appendSlice(allocator, "\\i ");
                try appendInlineRtf(out, allocator, text[i + 1 .. end], refs);
                try out.appendSlice(allocator, "\\i0 ");
                i = end + 1;
                continue;
            }
        }

        if (text[i] == '`') {
            if (parseCodeSpan(text, i)) |code| {
                const normalized = try normalizeCodeSpan(allocator, code.content);
                defer allocator.free(normalized);
                try out.appendSlice(allocator, "\\f1\\fs20\\highlight4 ");
                try appendRtfEscaped(out, allocator, normalized);
                try out.appendSlice(allocator, "\\highlight0\\f0\\fs22 ");
                i = code.end;
                continue;
            }
            const ticks = backtickRunLength(text, i);
            try appendRtfEscaped(out, allocator, text[i .. i + ticks]);
            i += ticks;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "~~")) {
            if (findSliceFrom(text, i + 2, "~~")) |end| {
                if (canUseSimpleEmphasis(text, i, end, 2, '~')) {
                    try out.appendSlice(allocator, "\\strike ");
                    try appendInlineRtf(out, allocator, text[i + 2 .. end], refs);
                    try out.appendSlice(allocator, "\\strike0 ");
                    i = end + 2;
                    continue;
                }
            }
            try out.appendSlice(allocator, "~~");
            i += 2;
            continue;
        }

        if (text[i] < 0x80) {
            try appendRtfEscapedByte(out, allocator, text[i]);
            i += 1;
        } else if (decodeUtf8At(text, i)) |decoded| {
            try appendRtfUnicode(out, allocator, decoded.codepoint);
            i += decoded.len;
        } else {
            try out.append(allocator, '?');
            i += 1;
        }
    }
}

fn appendImageAltRtf(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8, refs: []const ReferenceDef) !void {
    var plain: std.ArrayList(u8) = .empty;
    defer plain.deinit(allocator);
    try appendInlineNoLinks(&plain, allocator, text, refs);
    try appendRtfEscaped(out, allocator, plain.items);
}

fn appendInlineNoLinksRtf(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8, refs: []const ReferenceDef) !void {
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '\\' and i + 1 < text.len and isEscapableAsciiPunctuation(text[i + 1])) {
            try appendRtfEscapedByte(out, allocator, text[i + 1]);
            i += 2;
            continue;
        }

        if (text[i] == '&') {
            if (try appendEntityRtf(out, allocator, text, i)) |next| {
                i = next;
                continue;
            }
        }

        if (text[i] == '<') {
            if (findByteFrom(text, i + 1, '>')) |close_angle| {
                const target = text[i + 1 .. close_angle];
                if (isAutoLink(target)) {
                    try appendRtfEscaped(out, allocator, target);
                    i = close_angle + 1;
                    continue;
                }
            }
        }

        if (std.mem.startsWith(u8, text[i..], "![")) {
            if (findLinkCloseBracket(text, i + 2)) |close_bracket| {
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (findLinkCloseParen(text, close_bracket + 2)) |close_paren| {
                        if (inlineLinkDestination(text[close_bracket + 2 .. close_paren]) != null) {
                            try appendInlineNoLinksRtf(out, allocator, text[i + 2 .. close_bracket], refs);
                            i = close_paren + 1;
                            continue;
                        }
                    }
                }

                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '[') {
                    if (findLinkCloseBracket(text, close_bracket + 2)) |close_label| {
                        const explicit_label = text[close_bracket + 2 .. close_label];
                        const label = if (explicit_label.len == 0) text[i + 2 .. close_bracket] else explicit_label;
                        if (findReference(refs, label) != null) {
                            try appendInlineNoLinksRtf(out, allocator, text[i + 2 .. close_bracket], refs);
                            i = close_label + 1;
                            continue;
                        }
                    }
                } else if (findReference(refs, text[i + 2 .. close_bracket]) != null) {
                    try appendInlineNoLinksRtf(out, allocator, text[i + 2 .. close_bracket], refs);
                    i = close_bracket + 1;
                    continue;
                }
            }
        }

        if (text[i] == '[') {
            if (findLinkCloseBracket(text, i + 1)) |close_bracket| {
                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '(') {
                    if (findLinkCloseParen(text, close_bracket + 2)) |close_paren| {
                        if (inlineLinkDestination(text[close_bracket + 2 .. close_paren]) != null) {
                            try appendInlineNoLinksRtf(out, allocator, text[i + 1 .. close_bracket], refs);
                            i = close_paren + 1;
                            continue;
                        }
                    }
                }

                if (close_bracket + 1 < text.len and text[close_bracket + 1] == '[') {
                    if (findLinkCloseBracket(text, close_bracket + 2)) |close_label| {
                        const explicit_label = text[close_bracket + 2 .. close_label];
                        const label = if (explicit_label.len == 0) text[i + 1 .. close_bracket] else explicit_label;
                        if (findReference(refs, label) != null) {
                            try appendInlineNoLinksRtf(out, allocator, text[i + 1 .. close_bracket], refs);
                            i = close_label + 1;
                            continue;
                        }
                    }
                } else if (findReference(refs, text[i + 1 .. close_bracket]) != null) {
                    try appendInlineNoLinksRtf(out, allocator, text[i + 1 .. close_bracket], refs);
                    i = close_bracket + 1;
                    continue;
                }
            }
        }

        if (text[i] == '*') {
            const run_len = markerRunEnd(text, i, '*') - i;
            if (run_len > 3) {
                if (findEmphasisClose(text, i, run_len, '*')) |end| {
                    try appendRtfStarRunOpen(out, allocator, run_len);
                    try appendInlineNoLinksRtf(out, allocator, text[i + run_len .. end], refs);
                    try appendRtfStarRunClose(out, allocator, run_len);
                    i = end + run_len;
                    continue;
                }
            }
        }

        if (std.mem.startsWith(u8, text[i..], "***")) {
            if (findEmphasisClose(text, i, 3, '*')) |end| {
                try out.appendSlice(allocator, "\\b\\i ");
                try appendInlineNoLinksRtf(out, allocator, text[i + 3 .. end], refs);
                try out.appendSlice(allocator, "\\i0\\b0 ");
                i = end + 3;
                continue;
            }
            try out.appendSlice(allocator, "***");
            i += 3;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "___")) {
            if (findEmphasisClose(text, i, 3, '_')) |end| {
                try out.appendSlice(allocator, "\\b\\i ");
                try appendInlineNoLinksRtf(out, allocator, text[i + 3 .. end], refs);
                try out.appendSlice(allocator, "\\i0\\b0 ");
                i = end + 3;
                continue;
            }
            try out.appendSlice(allocator, "___");
            i += 3;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "**")) {
            if (findEmphasisClose(text, i, 2, '*')) |close| {
                if (findEscapedStrongMarkerPair(text, i + 2, close, '*')) |escaped| {
                    try out.appendSlice(allocator, "\\i ");
                    try appendInlineNoLinksRtf(out, allocator, text[i + 2 .. escaped], refs);
                    try out.append(allocator, '*');
                    try appendInlineNoLinksRtf(out, allocator, text[escaped + 3 .. close], refs);
                    try out.appendSlice(allocator, "\\i0 ");
                    try out.append(allocator, '*');
                    i = close + 2;
                    continue;
                }
                try out.appendSlice(allocator, "\\b ");
                try appendInlineNoLinksRtf(out, allocator, text[i + 2 .. close], refs);
                try out.appendSlice(allocator, "\\b0 ");
                i = close + 2;
                continue;
            }
            try out.appendSlice(allocator, "**");
            i += 2;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "__")) {
            if (findEmphasisClose(text, i, 2, '_')) |close| {
                if (findEscapedStrongMarkerPair(text, i + 2, close, '_')) |escaped| {
                    try out.appendSlice(allocator, "\\i ");
                    try appendInlineNoLinksRtf(out, allocator, text[i + 2 .. escaped], refs);
                    try out.append(allocator, '_');
                    try appendInlineNoLinksRtf(out, allocator, text[escaped + 3 .. close], refs);
                    try out.appendSlice(allocator, "\\i0 ");
                    try out.append(allocator, '_');
                    i = close + 2;
                    continue;
                }
                try out.appendSlice(allocator, "\\b ");
                try appendInlineNoLinksRtf(out, allocator, text[i + 2 .. close], refs);
                try out.appendSlice(allocator, "\\b0 ");
                i = close + 2;
                continue;
            }
            try out.appendSlice(allocator, "__");
            i += 2;
            continue;
        }

        if (text[i] == '*') {
            if (findEmphasisClose(text, i, 1, '*')) |end| {
                try out.appendSlice(allocator, "\\i ");
                try appendInlineNoLinksRtf(out, allocator, text[i + 1 .. end], refs);
                try out.appendSlice(allocator, "\\i0 ");
                i = end + 1;
                continue;
            }
        }

        if (text[i] == '_') {
            if (findEmphasisClose(text, i, 1, '_')) |end| {
                try out.appendSlice(allocator, "\\i ");
                try appendInlineNoLinksRtf(out, allocator, text[i + 1 .. end], refs);
                try out.appendSlice(allocator, "\\i0 ");
                i = end + 1;
                continue;
            }
        }

        if (text[i] == '`') {
            if (parseCodeSpan(text, i)) |code| {
                const normalized = try normalizeCodeSpan(allocator, code.content);
                defer allocator.free(normalized);
                try out.appendSlice(allocator, "\\f1\\fs20\\highlight4 ");
                try appendRtfEscaped(out, allocator, normalized);
                try out.appendSlice(allocator, "\\highlight0\\f0\\fs22 ");
                i = code.end;
                continue;
            }
            const ticks = backtickRunLength(text, i);
            try appendRtfEscaped(out, allocator, text[i .. i + ticks]);
            i += ticks;
            continue;
        }

        if (std.mem.startsWith(u8, text[i..], "~~")) {
            if (findSliceFrom(text, i + 2, "~~")) |end| {
                if (canUseSimpleEmphasis(text, i, end, 2, '~')) {
                    try out.appendSlice(allocator, "\\strike ");
                    try appendInlineNoLinksRtf(out, allocator, text[i + 2 .. end], refs);
                    try out.appendSlice(allocator, "\\strike0 ");
                    i = end + 2;
                    continue;
                }
            }
            try out.appendSlice(allocator, "~~");
            i += 2;
            continue;
        }

        if (text[i] < 0x80) {
            try appendRtfEscapedByte(out, allocator, text[i]);
            i += 1;
        } else if (decodeUtf8At(text, i)) |decoded| {
            try appendRtfUnicode(out, allocator, decoded.codepoint);
            i += decoded.len;
        } else {
            try out.append(allocator, '?');
            i += 1;
        }
    }
}

fn appendRtfEscaped(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    var i: usize = 0;
    while (i < text.len) {
        const ch = text[i];
        if (ch < 0x80) {
            try appendRtfEscapedByte(out, allocator, ch);
            i += 1;
            continue;
        }

        if (decodeUtf8At(text, i)) |decoded| {
            try appendRtfUnicode(out, allocator, decoded.codepoint);
            i += decoded.len;
        } else {
            try out.append(allocator, '?');
            i += 1;
        }
    }
}

fn isAutoLink(text: []const u8) bool {
    if (text.len == 0) return false;
    for (text) |ch| {
        if (isInvalidAutolinkTargetByte(ch)) return false;
    }
    if (isUriAutolink(text)) return true;
    return isEmailAutolink(text);
}

fn isInvalidAutolinkTargetByte(ch: u8) bool {
    return ch <= 0x20 or ch == 0x7f or ch == '<' or ch == '>';
}

fn isUriAutolink(text: []const u8) bool {
    const colon = findByteFrom(text, 0, ':') orelse return false;
    if (colon < 2 or colon > 32) return false;
    if (!std.ascii.isAlphabetic(text[0])) return false;

    for (text[1..colon]) |ch| {
        if (std.ascii.isAlphanumeric(ch) or ch == '+' or ch == '.' or ch == '-') continue;
        return false;
    }

    return true;
}

fn isEmailAutolink(text: []const u8) bool {
    const at = findByteFrom(text, 0, '@') orelse return false;
    if (at == 0 or at + 1 >= text.len) return false;
    if (findByteFrom(text, at + 1, '@') != null) return false;

    for (text[0..at]) |ch| {
        if (!isEmailLocalByte(ch)) return false;
    }

    return isEmailDomain(text[at + 1 ..]);
}

fn isEmailLocalByte(ch: u8) bool {
    if (std.ascii.isAlphanumeric(ch)) return true;
    return switch (ch) {
        '.', '!', '#', '$', '%', '&', '\'', '*', '+', '/', '=', '?', '^', '_', '`', '{', '|', '}', '~', '-' => true,
        else => false,
    };
}

fn isEmailDomain(domain: []const u8) bool {
    var start: usize = 0;
    while (start < domain.len) {
        const end = findByteFrom(domain, start, '.') orelse domain.len;
        if (!isEmailDomainLabel(domain[start..end])) return false;
        if (end == domain.len) return true;
        start = end + 1;
        if (start == domain.len) return false;
    }
    return false;
}

fn isEmailDomainLabel(label: []const u8) bool {
    if (label.len == 0 or label.len > 63) return false;
    if (!std.ascii.isAlphanumeric(label[0])) return false;
    if (!std.ascii.isAlphanumeric(label[label.len - 1])) return false;

    if (label.len > 2) {
        for (label[1 .. label.len - 1]) |ch| {
            if (std.ascii.isAlphanumeric(ch) or ch == '-') continue;
            return false;
        }
    }

    return true;
}

fn isHtmlBlockLine(line: []const u8) bool {
    if (line.len < 2 or line[0] != '<') return false;
    if (isHtmlCommentStart(line) or isHtmlCdataStart(line)) return true;
    if (htmlBlockStart(line) != null) return true;
    if (line.len < 3) return false;
    const close = findByteFrom(line, 1, '>') orelse return false;
    const tag = line[1..close];
    if (isAutoLink(tag)) return false;
    if (tag.len == 0) return false;

    const first = tag[0];
    return (first >= 'a' and first <= 'z') or
        (first >= 'A' and first <= 'Z') or
        first == '/' or
        first == '!' or
        first == '?';
}

fn htmlBlockInterruptsParagraph(line: []const u8) bool {
    if (isHtmlCommentStart(line) or isHtmlCdataStart(line)) return true;
    if (htmlBlockStart(line)) |block| return block.interrupts_paragraph;
    return false;
}

fn isHtmlCommentStart(line: []const u8) bool {
    return std.mem.startsWith(u8, line, "<!--");
}

fn isHtmlCommentEnd(line: []const u8) bool {
    return std.mem.indexOf(u8, line, "-->") != null;
}

fn isHtmlCdataStart(line: []const u8) bool {
    return std.mem.startsWith(u8, line, "<![CDATA[");
}

fn isHtmlCdataEnd(line: []const u8) bool {
    return std.mem.indexOf(u8, line, "]]>") != null;
}

fn htmlBlockStart(line: []const u8) ?HtmlBlock {
    if (line.len < 2 or line[0] != '<') return null;
    if (isHtmlCommentStart(line) or isHtmlCdataStart(line)) return null;

    var i: usize = 1;
    if (line[i] == '?') return .{ .end_tag = "?>", .end_on_blank = false };
    if (line[i] == '!') {
        if (line.len > 2 and line[2] >= 'A' and line[2] <= 'Z') return .{ .end_tag = ">", .end_on_blank = false };
        return null;
    }
    const is_closing = line[i] == '/';
    if (is_closing) i += 1;

    const name_start = i;
    while (i < line.len and isHtmlTagNameByte(line[i])) : (i += 1) {}
    if (i == name_start) return null;

    const tag = line[name_start..i];
    if (!htmlBlockTagBoundaryOk(line, i)) return null;

    if (!is_closing) {
        if (std.ascii.eqlIgnoreCase(tag, "script")) return .{ .end_tag = "</script>", .end_on_blank = false };
        if (std.ascii.eqlIgnoreCase(tag, "style")) return .{ .end_tag = "</style>", .end_on_blank = false };
        if (std.ascii.eqlIgnoreCase(tag, "pre")) return .{ .end_tag = "</pre>", .end_on_blank = false };
        if (std.ascii.eqlIgnoreCase(tag, "textarea")) return .{ .end_tag = "</textarea>", .end_on_blank = false };
    }

    if (isHtmlBlockLevelTag(tag)) {
        return .{ .end_tag = "", .end_on_blank = true };
    }
    if (isHtmlTypeSevenBlockStart(line, i, tag, is_closing)) {
        return .{ .end_tag = "", .end_on_blank = true, .interrupts_paragraph = false };
    }
    return null;
}

fn isHtmlBlockLevelTag(tag: []const u8) bool {
    for (html_block_level_tags) |candidate| {
        if (std.ascii.eqlIgnoreCase(tag, candidate)) return true;
    }
    return false;
}

fn isHtmlTypeSevenBlockStart(line: []const u8, index: usize, tag: []const u8, is_closing: bool) bool {
    if (!is_closing and isHtmlLiteralContentTag(tag)) return false;

    if (is_closing) {
        if (index >= line.len or line[index] != '>') return false;
        return isOnlySpacesTabs(line[index + 1 ..]);
    }

    var quote: ?u8 = null;
    var i = index;
    while (i < line.len) : (i += 1) {
        const ch = line[i];
        if (quote) |q| {
            if (ch == q) quote = null;
            continue;
        }
        if (ch == '"' or ch == '\'') {
            quote = ch;
            continue;
        }
        if (ch == '>') return isOnlySpacesTabs(line[i + 1 ..]);
    }
    return false;
}

fn isHtmlLiteralContentTag(tag: []const u8) bool {
    return std.ascii.eqlIgnoreCase(tag, "pre") or
        std.ascii.eqlIgnoreCase(tag, "script") or
        std.ascii.eqlIgnoreCase(tag, "style") or
        std.ascii.eqlIgnoreCase(tag, "textarea");
}

fn htmlBlockTagBoundaryOk(line: []const u8, index: usize) bool {
    if (index >= line.len) return true;
    if (line[index] == ' ' or line[index] == '\t' or line[index] == '>') return true;
    return line[index] == '/' and index + 1 < line.len and line[index + 1] == '>';
}

fn isOnlySpacesTabs(text: []const u8) bool {
    for (text) |ch| {
        if (ch != ' ' and ch != '\t') return false;
    }
    return true;
}

fn htmlBlockEndsOnLine(line: []const u8, block: HtmlBlock) bool {
    if (block.end_tag.len == 0) return false;
    return containsAsciiIgnoreCase(line, block.end_tag);
}

fn isHtmlTagNameByte(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or
        (ch >= 'A' and ch <= 'Z') or
        (ch >= '0' and ch <= '9') or
        ch == '-';
}

fn containsAsciiIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;

    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return true;
    }
    return false;
}

fn referenceLinkDestination(raw: []const u8) ?[]const u8 {
    const parsed = referenceLinkDestinationParse(raw) orelse return null;
    return parsed.destination;
}

fn referenceLinkDestinationParse(raw: []const u8) ?LinkDestinationParse {
    return linkDestinationWithOptionalTitle(raw, false);
}

fn inlineLinkDestination(raw: []const u8) ?[]const u8 {
    const parsed = linkDestinationWithOptionalTitle(raw, true) orelse return null;
    return parsed.destination;
}

fn linkDestinationWithOptionalTitle(raw: []const u8, allow_empty_plain: bool) ?LinkDestinationParse {
    const trimmed = std.mem.trim(u8, raw, " \t");
    if (trimmed.len == 0) {
        return if (allow_empty_plain) .{ .destination = trimmed, .has_title = false } else null;
    }

    if (trimmed[0] == '<') {
        const end = angleLinkDestinationEnd(trimmed) orelse return null;
        const has_title = trailingLinkTitlePresence(trimmed[end + 1 ..]) orelse return null;
        return .{ .destination = trimmed[1..end], .has_title = has_title };
    }

    var end: usize = 0;
    while (end < trimmed.len) : (end += 1) {
        if (trimmed[end] == '\\' and end + 1 < trimmed.len and isEscapableAsciiPunctuation(trimmed[end + 1])) {
            end += 1;
            continue;
        }
        if (trimmed[end] == ' ' or trimmed[end] == '\t') break;
        if (trimmed[end] < 0x20 or trimmed[end] == 0x7f) return null;
    }

    const destination = trimmed[0..end];
    if (destination.len == 0) return null;
    const has_title = trailingLinkTitlePresence(trimmed[end..]) orelse return null;
    return .{ .destination = destination, .has_title = has_title };
}

fn angleLinkDestinationEnd(text: []const u8) ?usize {
    var i: usize = 1;
    while (i < text.len) : (i += 1) {
        if (text[i] == '\\' and i + 1 < text.len and isEscapableAsciiPunctuation(text[i + 1])) {
            i += 1;
            continue;
        }
        if (text[i] == '<') return null;
        if (text[i] == '>') return i;
        if (text[i] == '\n' or text[i] == '\r') return null;
    }

    return null;
}

fn validTrailingLinkTitle(trailing: []const u8) bool {
    return trailingLinkTitlePresence(trailing) != null;
}

fn trailingLinkTitlePresence(trailing: []const u8) ?bool {
    if (trailing.len == 0) return false;
    if (trailing[0] != ' ' and trailing[0] != '\t') return null;
    const title = std.mem.trim(u8, trailing, " \t");
    if (title.len == 0) return false;
    return if (isLinkTitle(title)) true else null;
}

fn isLinkTitle(text: []const u8) bool {
    if (text.len < 2) return false;

    const close: u8 = switch (text[0]) {
        '"' => '"',
        '\'' => '\'',
        '(' => ')',
        else => return false,
    };
    if (text[text.len - 1] != close) return false;

    var i: usize = 1;
    while (i + 1 < text.len) : (i += 1) {
        if (text[i] == '\\' and i + 1 < text.len and isEscapableAsciiPunctuation(text[i + 1])) {
            i += 1;
            continue;
        }
        if (text[i] == close) return false;
        if (text[0] == '(' and text[i] == '(') return false;
    }

    return true;
}

fn isEscapableAsciiPunctuation(ch: u8) bool {
    if (ch < 0x21 or ch > 0x7e) return false;
    if (ch >= '0' and ch <= '9') return false;
    if (ch >= 'A' and ch <= 'Z') return false;
    if (ch >= 'a' and ch <= 'z') return false;
    return true;
}

fn findLinkCloseParen(text: []const u8, start: usize) ?usize {
    var i = start;
    var depth: usize = 0;
    var saw_destination_start = false;
    var in_angle_destination = false;
    var after_destination_space = false;
    var title_quote: ?u8 = null;

    while (i < text.len) : (i += 1) {
        if (text[i] == '\\' and i + 1 < text.len and isEscapableAsciiPunctuation(text[i + 1])) {
            i += 1;
            continue;
        }

        if (title_quote) |quote| {
            if (text[i] == quote) title_quote = null;
            continue;
        }

        if (in_angle_destination) {
            if (text[i] == '>') in_angle_destination = false;
            continue;
        }

        if (!saw_destination_start) {
            if (text[i] == ' ' or text[i] == '\t') continue;
            saw_destination_start = true;
            if (text[i] == '<') {
                in_angle_destination = true;
                continue;
            }
        }

        if (depth == 0 and (text[i] == ' ' or text[i] == '\t')) {
            after_destination_space = true;
            continue;
        }

        if (after_destination_space and (text[i] == '"' or text[i] == '\'')) {
            title_quote = text[i];
            continue;
        }

        if (text[i] == '(') {
            depth += 1;
            continue;
        }

        if (text[i] == ')') {
            if (depth == 0) return i;
            depth -= 1;
        }
    }

    return null;
}

fn findLinkCloseBracket(text: []const u8, start: usize) ?usize {
    var i = start;
    var depth: usize = 0;

    while (i < text.len) : (i += 1) {
        if (text[i] == '\\' and i + 1 < text.len and isEscapableAsciiPunctuation(text[i + 1])) {
            i += 1;
            continue;
        }

        if (text[i] == '[') {
            depth += 1;
            continue;
        }

        if (text[i] == ']') {
            if (depth == 0) return i;
            depth -= 1;
        }
    }

    return null;
}

fn findReferenceLabelCloseBracket(text: []const u8, start: usize) ?usize {
    var i = start;
    while (i < text.len) : (i += 1) {
        if (text[i] == '\\' and i + 1 < text.len and isEscapableAsciiPunctuation(text[i + 1])) {
            i += 1;
            continue;
        }

        if (text[i] == '[') return null;
        if (text[i] == ']') return i;
    }

    return null;
}

fn appendEscapedMarkdownText(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '\\' and i + 1 < text.len and isEscapableAsciiPunctuation(text[i + 1])) {
            try out.append(allocator, text[i + 1]);
            i += 2;
            continue;
        }

        if (text[i] == '&') {
            if (try appendEntity(out, allocator, text, i)) |next| {
                i = next;
                continue;
            }
        }

        try out.append(allocator, text[i]);
        i += 1;
    }
}

fn appendEscapedMarkdownTextRtf(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '\\' and i + 1 < text.len and isEscapableAsciiPunctuation(text[i + 1])) {
            try appendRtfEscapedByte(out, allocator, text[i + 1]);
            i += 2;
            continue;
        }

        if (text[i] == '&') {
            if (try appendEntityRtf(out, allocator, text, i)) |next| {
                i = next;
                continue;
            }
        }

        if (text[i] < 0x80) {
            try appendRtfEscapedByte(out, allocator, text[i]);
            i += 1;
        } else if (decodeUtf8At(text, i)) |decoded| {
            try appendRtfUnicode(out, allocator, decoded.codepoint);
            i += decoded.len;
        } else {
            try out.append(allocator, '?');
            i += 1;
        }
    }
}

fn appendEntity(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8, start: usize) !?usize {
    const end = findByteFrom(text, start + 1, ';') orelse return null;
    const body = text[start + 1 .. end];
    if (try appendEntityBody(out, allocator, body, false)) return end + 1;
    return null;
}

fn appendEntityRtf(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8, start: usize) !?usize {
    const end = findByteFrom(text, start + 1, ';') orelse return null;
    const body = text[start + 1 .. end];
    if (try appendEntityBody(out, allocator, body, true)) return end + 1;
    return null;
}

fn appendEntityBody(out: *std.ArrayList(u8), allocator: std.mem.Allocator, body: []const u8, rtf: bool) !bool {
    if (namedEntityValue(body)) |value| return appendDecodedEntity(out, allocator, value, rtf);

    if (body.len >= 2 and body[0] == '#') {
        const base: u8 = if (body[1] == 'x' or body[1] == 'X') 16 else 10;
        const digits = if (base == 16) body[2..] else body[1..];
        if (digits.len == 0) return false;
        if (base == 16 and digits.len > 6) return false;
        if (base == 10 and digits.len > 7) return false;
        const parsed = std.fmt.parseInt(u64, digits, base) catch |err| switch (err) {
            error.Overflow => std.math.maxInt(u64),
            error.InvalidCharacter => return false,
        };
        const codepoint = validEntityCodepoint(parsed);
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(codepoint, &buf) catch return false;
        return appendDecodedEntity(out, allocator, buf[0..len], rtf);
    }

    return false;
}

fn namedEntityValue(body: []const u8) ?[]const u8 {
    for (named_entities) |entity| {
        if (std.mem.eql(u8, body, entity.name)) return entity.value;
    }

    return null;
}

fn validEntityCodepoint(codepoint: u64) u21 {
    if (codepoint == 0) return 0xfffd;
    if (codepoint > 0x10ffff) return 0xfffd;
    if (codepoint >= 0xd800 and codepoint <= 0xdfff) return 0xfffd;
    if (html5C1NumericEntityRemap(codepoint)) |remapped| return remapped;
    return @intCast(codepoint);
}

fn html5C1NumericEntityRemap(codepoint: u64) ?u21 {
    return switch (codepoint) {
        0x80 => 0x20ac,
        0x82 => 0x201a,
        0x83 => 0x0192,
        0x84 => 0x201e,
        0x85 => 0x2026,
        0x86 => 0x2020,
        0x87 => 0x2021,
        0x88 => 0x02c6,
        0x89 => 0x2030,
        0x8a => 0x0160,
        0x8b => 0x2039,
        0x8c => 0x0152,
        0x8e => 0x017d,
        0x91 => 0x2018,
        0x92 => 0x2019,
        0x93 => 0x201c,
        0x94 => 0x201d,
        0x95 => 0x2022,
        0x96 => 0x2013,
        0x97 => 0x2014,
        0x98 => 0x02dc,
        0x99 => 0x2122,
        0x9a => 0x0161,
        0x9b => 0x203a,
        0x9c => 0x0153,
        0x9e => 0x017e,
        0x9f => 0x0178,
        else => null,
    };
}

fn appendDecodedEntity(out: *std.ArrayList(u8), allocator: std.mem.Allocator, decoded: []const u8, rtf: bool) !bool {
    if (rtf) {
        try appendRtfEscaped(out, allocator, decoded);
    } else {
        try out.appendSlice(allocator, decoded);
    }
    return true;
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

const Utf8Decoded = struct {
    codepoint: u21,
    len: usize,
};

fn decodeUtf8At(text: []const u8, index: usize) ?Utf8Decoded {
    if (index >= text.len) return null;
    const b0 = text[index];

    if (b0 < 0x80) return .{ .codepoint = b0, .len = 1 };

    if ((b0 & 0xe0) == 0xc0) {
        if (index + 1 >= text.len) return null;
        const b1 = text[index + 1];
        if ((b1 & 0xc0) != 0x80) return null;
        return .{ .codepoint = (@as(u21, b0 & 0x1f) << 6) | @as(u21, b1 & 0x3f), .len = 2 };
    }

    if ((b0 & 0xf0) == 0xe0) {
        if (index + 2 >= text.len) return null;
        const b1 = text[index + 1];
        const b2 = text[index + 2];
        if ((b1 & 0xc0) != 0x80 or (b2 & 0xc0) != 0x80) return null;
        return .{ .codepoint = (@as(u21, b0 & 0x0f) << 12) | (@as(u21, b1 & 0x3f) << 6) | @as(u21, b2 & 0x3f), .len = 3 };
    }

    if ((b0 & 0xf8) == 0xf0) {
        if (index + 3 >= text.len) return null;
        const b1 = text[index + 1];
        const b2 = text[index + 2];
        const b3 = text[index + 3];
        if ((b1 & 0xc0) != 0x80 or (b2 & 0xc0) != 0x80 or (b3 & 0xc0) != 0x80) return null;
        return .{ .codepoint = (@as(u21, b0 & 0x07) << 18) | (@as(u21, b1 & 0x3f) << 12) | (@as(u21, b2 & 0x3f) << 6) | @as(u21, b3 & 0x3f), .len = 4 };
    }

    return null;
}

fn appendRtfUnicode(out: *std.ArrayList(u8), allocator: std.mem.Allocator, codepoint: u21) !void {
    if (codepoint == 0xfffd) {
        // RichEdit hides U+FFFD when sent as \u-3? under the UTF-8 RTF
        // codepage. Hex-escape the UTF-8 bytes so the replacement glyph stays
        // visible in malformed-input fixtures without embedding raw non-ASCII.
        try out.appendSlice(allocator, "\\'ef\\'bf\\'bd");
        return;
    }

    if (codepoint <= 0xffff) {
        try appendRtfUnicodeUnit(out, allocator, @intCast(codepoint));
        return;
    }

    // The Windows GUI feeds RTF through RichEdit with CP_UTF8. In that mode,
    // supplementary-plane codepoints render more reliably as their original
    // UTF-8 bytes than as adjacent surrogate \u control words.
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(codepoint, &buf) catch {
        try out.append(allocator, '?');
        return;
    };
    try out.appendSlice(allocator, buf[0..len]);
}

fn appendRtfUnicodeUnit(out: *std.ArrayList(u8), allocator: std.mem.Allocator, unit: u16) !void {
    const positive: i32 = @intCast(unit);
    const signed = if (unit <= 0x7fff) positive else positive - 0x10000;
    const escaped = try std.fmt.allocPrint(allocator, "\\u{}?", .{signed});
    defer allocator.free(escaped);
    try out.appendSlice(allocator, escaped);
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

test "renders long star delimiter runs without leaking markers" {
    const input =
        \\Triple nested both: ***bold italic*** should render both.
        \\Four stars split: ****literal?**** should follow CommonMark delimiter resolution.
        \\Mixed leftovers: *****five star text***** should not leak unexpected markers.
        \\Underscore word boundaries: foo___bar___baz should stay mostly literal.
        \\Punctuation delimiters: (**strong**) and (*em*) should render inside punctuation.
        \\Image alt long run: ![****alt****](image.png).
    ;

    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Triple nested both: bold italic should render both.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Four stars split: literal? should follow CommonMark delimiter resolution.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Mixed leftovers: five star text should not leak unexpected markers.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Underscore word boundaries: foo___bar___baz should stay mostly literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Punctuation delimiters: (strong) and (em) should render inside punctuation.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: alt] <image.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "*literal?*") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**five star text**") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "****alt****") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b literal?\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\i five star text\\i0\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "****literal") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "*****five") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "****alt****") == null);
}

test "keeps supplementary unicode visible in RTF" {
    const input = "Emoji outside BMP: 🚀 and BMP text: 한글.\n";

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "🚀") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u-10179?\\u-8576?") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u-10916?\\u-20992?") != null);
}

test "ignores utf8 bom before first markdown construct" {
    const heading_input =
        "\xEF\xBB\xBF" ++
        \\# BOM Heading
        \\
        \\First paragraph with **bold** and [inline](https://example.com/bom).
        \\
        \\- list item after BOM heading
        ;
    const heading_rendered = try render(std.testing.allocator, heading_input);
    defer std.testing.allocator.free(heading_rendered);

    try std.testing.expect(std.mem.indexOf(u8, heading_rendered, "== BOM Heading ==") != null);
    try std.testing.expect(std.mem.indexOf(u8, heading_rendered, "# BOM Heading") == null);
    try std.testing.expect(std.mem.indexOf(u8, heading_rendered, "First paragraph with bold and inline <https://example.com/bom>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, heading_rendered, "* list item after BOM heading") != null);

    const reference_input =
        "\xEF\xBB\xBF" ++
        \\[ref]: https://example.com/bom
        \\
        \\[ref link][ref].
        ;
    const reference_rendered = try render(std.testing.allocator, reference_input);
    defer std.testing.allocator.free(reference_rendered);

    try std.testing.expect(std.mem.indexOf(u8, reference_rendered, "ref link <https://example.com/bom>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, reference_rendered, "[ref]:") == null);

    const rtf = try renderRtf(std.testing.allocator, heading_input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs44 BOM Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "# BOM Heading") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul inline") != null);
}

test "replaces nul bytes with replacement characters" {
    const input =
        "# NUL Replacement\n\n" ++
        "Text before \x00 after should show replacement.\n" ++
        "Code raw `inline \x00 code`.\n" ++
        "Link dest: [nul](/path/\x00x).\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOfScalar(u8, rendered, 0) == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Text before � after should show replacement.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code raw inline � code.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Link dest: nul </path/�x>.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOfScalar(u8, rtf, 0) == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Text before \\'ef\\'bf\\'bd after should show replacement.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "inline \\'ef\\'bf\\'bd code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "/path/\\'ef\\'bf\\'bdx") != null);
}

test "handles cr-only line endings as markdown line endings" {
    const input =
        "# Cycle 78 CR Line Endings\r" ++
        "\r" ++
        "[ref]: https://example.com/cr\r" ++
        "\r" ++
        "Paragraph with **bold** and [ref link][ref].\r" ++
        "- cr list item\r";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "== Cycle 78 CR Line Endings ==") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[ref]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph with bold and ref link <https://example.com/cr>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* cr list item") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\r") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs44 Cycle 78 CR Line Endings") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul ref link") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab cr list item") != null);
}

test "renders setext headings and escaped inline markers" {
    const input =
        \\Title One
        \\=========
        \\
        \\Title Two
        \\---------
        \\
        \\Escaped: \*not italic\*, \`not code\`, and \[not link\](x).
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "== Title One ==") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "-- Title Two --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "=========") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "*not italic*") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "`not code`") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[not link](x)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "not link <x>") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs44 Title One") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 Title Two") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul not link") == null);
}

test "preserves trailing backslash in setext heading text" {
    const input =
        "Heading with two trailing spaces  \n" ++
        "---\n\n" ++
        "Heading with trailing backslash\\\n" ++
        "---\n\n" ++
        "Paragraph hard break  \n" ++
        "not heading underline text\n" ++
        "---x\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "-- Heading with two trailing spaces --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "-- Heading with trailing backslash\\ --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph hard break\nnot heading underline text ---x") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "-- Heading with trailing backslash --") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 Heading with two trailing spaces") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 Heading with trailing backslash\\\\") != null);
}

test "renders hard breaks inside multiline setext headings" {
    const input =
        "Multi line heading part one\\\n" ++
        "part two with `code` and [link](https://example.com/setext)\n" ++
        "---\n\n" ++
        "> Quote multi heading part one\\\n" ++
        "> part two with **bold**\n" ++
        "> ---\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "-- Multi line heading part one\npart two with code and link <https://example.com/setext> --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| -- Quote multi heading part one\npart two with bold --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "heading part one\\ part two") == null);
}

test "restores heading RTF style after inline code and links" {
    const input =
        \\A second heading with `code` and [link](https://example.test/inline)
        \\------------------------------------------------------------------------
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "-- A second heading with code and link <https://example.test/inline> --") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\highlight4 code") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs36\\highlight4 code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\highlight0\\f0\\fs22  and \\cf3\\ul link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\highlight0 \\f0\\cf1\\b\\fs36  and \\cf3\\ul link") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\ulnone \\f0\\cf1\\b\\fs36 \\cf2 <https://example.test/inline>") != null);
}

test "parses inline markdown in pipe-start paragraphs for RTF" {
    const input =
        \\| Header | Header |
        \\| ------ | ------ |
        \\| *not table emphasis?* | [link](https://example.test/pipe) |
        \\
        \\Inline pipe text: a | b | c with `x | y` and [pipe | label](https://example.test/label).
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| not table emphasis? | link <https://example.test/pipe> |") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "pipe | label <https://example.test/label>") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\i not table emphasis?\\i0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul link\\ulnone") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul pipe | label\\ulnone") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[link](https://example.test/pipe)") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "*not table emphasis?*") == null);
}

test "renders setext headings inside blockquote and list containers" {
    const input =
        \\> Quote Setext Heading
        \\> ---
        \\> after quote **bold** paragraph.
        \\
        \\- List Setext Heading
        \\  ===
        \\  after list **bold** paragraph.
        \\
        \\> - Quoted List Setext Heading
        \\>   ---
        \\>   after quoted list **bold** paragraph.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| -- Quote Setext Heading --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* == List Setext Heading ==") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * -- Quoted List Setext Heading --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| ---") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  ===") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| after quote bold paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  after list bold paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   after quoted list bold paragraph.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 Quote Setext Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs44 List Setext Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 Quoted List Setext Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quote \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after list \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quoted list \\b bold\\b0") != null);
}

test "renders tab-padded setext underlines inside blockquotes" {
    const input =
        "> quoted setext candidate\n" ++
        "> \t---\n" ++
        "\n" ++
        "> quoted direct-tab setext candidate\n" ++
        ">\t---\n" ++
        "\n" ++
        "After quote.\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| -- quoted setext candidate --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| -- quoted direct-tab setext candidate --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| quoted setext candidate\n| ---") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 quoted setext candidate") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 quoted direct-tab setext candidate") != null);
}

test "renders tab-padded setext underlines inside list items" {
    const input =
        "- list setext candidate\n" ++
        "  \t---\n" ++
        "\n" ++
        "- direct tab list setext candidate\n" ++
        "\t---\n" ++
        "\n" ++
        "- four-space list setext candidate\n" ++
        "    ---\n" ++
        "\n" ++
        "- five-space list setext candidate\n" ++
        "     ---\n" ++
        "\n" ++
        "- six-space stays paragraph\n" ++
        "      ---\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "* -- list setext candidate --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* -- direct tab list setext candidate --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* -- four-space list setext candidate --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* -- five-space list setext candidate --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* six-space stays paragraph\n---") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* -- six-space stays paragraph --") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 list setext candidate") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 direct tab list setext candidate") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 four-space list setext candidate") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 five-space list setext candidate") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "six-space stays paragraph") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 six-space stays paragraph") == null);
}

test "renders multiline setext headings inside containers" {
    const input =
        \\> Quote multi
        \\> line heading
        \\> ---
        \\> after quote **bold** paragraph.
        \\
        \\- List multi
        \\  line heading
        \\  ===
        \\  after list **bold** paragraph.
        \\
        \\> - Quoted list multi
        \\>   line heading
        \\>   ---
        \\>   after quoted list **bold** paragraph.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| -- Quote multi line heading --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* == List multi line heading ==") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * -- Quoted list multi line heading --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| line heading") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  line heading") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| ---") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  ===") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 Quote multi line heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs44 List multi line heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 Quoted list multi line heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quote \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after list \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quoted list \\b bold\\b0") != null);
}

test "renders ATX headings inside blockquote and list containers" {
    const input =
        \\> ## Quote ATX Heading ##
        \\> after quote **bold** paragraph.
        \\
        \\- # List ATX Heading #
        \\  after list **bold** paragraph.
        \\
        \\- Loose List ATX Heading owner
        \\
        \\  ## Loose List ATX Heading ##
        \\
        \\  after loose list **bold** paragraph.
        \\
        \\> - ### Quoted List ATX Heading ###
        \\>   after quoted list **bold** paragraph.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| -- Quote ATX Heading --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* == List ATX Heading ==") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* Loose List ATX Heading owner") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  -- Loose List ATX Heading --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * Quoted List ATX Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "## Quote ATX Heading") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "# List ATX Heading") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "### Quoted List ATX Heading") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| after quote bold paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  after list bold paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  after loose list bold paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   after quoted list bold paragraph.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 Quote ATX Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs44 List ATX Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 Loose List ATX Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs30 Quoted List ATX Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quote \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after list \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after loose list \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quoted list \\b bold\\b0") != null);
}

test "does not treat indented setext underline as heading" {
    const input =
        \\Paragraph before indented underline
        \\    ---
        \\
        \\Normal Setext
        \\---
        \\
        \\Indented equals should also stay code
        \\    ===
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph before indented underline ---") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "-- Normal Setext --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Indented equals should also stay code ===") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "-- Paragraph before indented underline --") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "== Indented equals should also stay code ==") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Paragraph before indented underline ---") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 Normal Setext") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Indented equals should also stay code ===") != null);
}

test "requires thematic breaks to have three markers and setext underlines to be contiguous" {
    const input =
        \\Invalid hyphen marker line follows:
        \\- -
        \\
        \\Invalid star marker line follows:
        \\* *
        \\
        \\Invalid underscore marker line follows:
        \\_ _
        \\
        \\Valid hyphen thematic follows:
        \\- - -
        \\
        \\Valid star thematic follows:
        \\* * *
        \\
        \\Valid Setext
        \\---
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Invalid hyphen marker line follows:\n* -") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Invalid star marker line follows:\n* *") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Invalid underscore marker line follows: _ _") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Valid hyphen thematic follows:\n---") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Valid star thematic follows:\n---") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "-- Valid Setext --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "-- Invalid hyphen marker line follows: --") == null);
}

test "renders thematic breaks inside list and blockquote containers" {
    const input =
        \\> Before quote break
        \\> ---
        \\> After quote **bold** paragraph.
        \\
        \\- Before list break
        \\  ***
        \\  After list **bold** paragraph.
        \\
        \\- Loose list before thematic
        \\
        \\  * * *
        \\
        \\  After loose list **bold** paragraph.
        \\
        \\> - Before quoted list break
        \\>   _ _ _
        \\>   After quoted list **bold** paragraph.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| -- Before quote break --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* Before list break") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "---") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* Loose list before thematic") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  ---") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  After loose list bold paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   ---") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "_ _ _") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   After quoted list bold paragraph.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "------------------------------") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "_ _ _") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After loose list \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After quoted list \\b bold\\b0") != null);
}

test "only escapes ascii punctuation after backslash" {
    const input =
        \\Escapable punctuation: \*literal star\* and \[literal bracket\](x).
        \\Non-escapable ASCII: \a should keep the slash, and path C:\notes should keep slash-like text.
        \\Non-escapable Unicode: \한글 and \🚀 should keep their leading slash without corrupting UTF-8.
        \\Link label nonescape: [label \한][ref]
        \\
        \\[ref]: https://example.com/backslash
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "*literal star*",
        "[literal bracket](x)",
        "\\a should keep the slash",
        "C:\\notes",
        "\\한글",
        "\\🚀",
        "label \\한 <https://example.com/backslash>",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\\\a should keep the slash") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "C:\\\\notes") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\\\\\u-10916?\\u-20992?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\\\🚀") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul label \\\\\\u-10916?") != null);
}

test "renders nested list indentation and autolinks" {
    const input =
        \\Autolink: <https://example.org/auto> and <zmd@example.org>.
        \\
        \\- parent
        \\  - child
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "https://example.org/auto") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "<https://example.org/auto>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* parent") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  * child") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul https://example.org/auto") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul zmd@example.org") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li480\\fi-240") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li840\\fi-240") != null);
}

test "renders generic uri scheme autolinks" {
    const input =
        \\Generic scheme: <ftp://example.com/file.txt>.
        \\Uppercase scheme: <HTTPS://EXAMPLE.COM/UP>.
        \\Custom scheme: <web+zmd.demo:viewer/path>.
        \\Email still works: <reader@example.com>.
        \\Plain HTML tag stays literal: <span class="x">not autolink</span>.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "Generic scheme: ftp://example.com/file.txt.",
        "Uppercase scheme: HTTPS://EXAMPLE.COM/UP.",
        "Custom scheme: web+zmd.demo:viewer/path.",
        "Email still works: reader@example.com.",
        "<span class=\"x\">not autolink</span>",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }

    try std.testing.expect(std.mem.indexOf(u8, rendered, "<ftp://example.com/file.txt>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "<HTTPS://EXAMPLE.COM/UP>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "<web+zmd.demo:viewer/path>") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul ftp://example.com/file.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul HTTPS://EXAMPLE.COM/UP") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul web+zmd.demo:viewer/path") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<span class=\"x\">not autolink</span>") != null);
}

test "validates email autolinks with CommonMark boundaries" {
    const input =
        \\Valid simple email: <foo@bar.example.com>.
        \\Valid plus email: <foo+special@Bar-baz0.com>.
        \\Escaped plus invalid email: <foo\+@bar.example.com>.
        \\Trailing dot invalid email: <foo@bar.example.com.>.
        \\Bad domain label invalid email: <foo@-bar.example.com>.
        \\Plain email outside angle: foo@bar.example.com.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Valid simple email: foo@bar.example.com.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Valid plus email: foo+special@Bar-baz0.com.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Escaped plus invalid email: <foo+@bar.example.com>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Trailing dot invalid email: <foo@bar.example.com.>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Bad domain label invalid email: <foo@-bar.example.com>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Plain email outside angle: foo@bar.example.com.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "foo\\+@bar.example.com") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul foo@bar.example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul foo+special@Bar-baz0.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<foo+@bar.example.com>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<foo@bar.example.com.>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<foo@-bar.example.com>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul foo@-bar.example.com") == null);
}

test "rejects autolinks containing nested angle brackets" {
    const input =
        \\Valid URI autolink: <https://example.com/ok>.
        \\Invalid nested angle URI: <https://example.com/<bad>>.
        \\Invalid custom nested angle: <web+zmd:viewer/<bad>>.
        \\Valid email autolink still works: <reader@example.com>.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Valid URI autolink: https://example.com/ok.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Invalid nested angle URI: <https://example.com/<bad>>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Invalid custom nested angle: <web+zmd:viewer/<bad>>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Valid email autolink still works: reader@example.com.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Invalid nested angle URI: https://example.com/<bad>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Invalid custom nested angle: web+zmd:viewer/<bad>") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul https://example.com/ok") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<https://example.com/<bad>>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<web+zmd:viewer/<bad>>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul reader@example.com") != null);
}

test "preserves raw html block text while keeping autolinks active" {
    const input =
        \\Autolinks: <https://example.com/docs?q=zmd> and <user@example.com>.
        \\
        \\<div class="note">literal **markdown** inside block tag text</div>
        \\<script>deleteEverything()</script>
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "https://example.com/docs?q=zmd") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "<https://example.com/docs?q=zmd>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "user@example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "<div class=\"note\">literal **markdown** inside block tag text</div>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "<script>deleteEverything()</script>") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul https://example.com/docs?q=zmd") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<div class=\"note\">literal **markdown** inside block tag text</div>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<script>deleteEverything()</script>") != null);
}

test "preserves multiline raw html blocks as inert text" {
    const input =
        \\<script type="text/plain">
        \\**literal script bold** should not become bold.
        \\[script link](https://example.com/script) should stay literal.
        \\</script>
        \\
        \\<div class="note">
        \\**literal div bold** should not become bold.
        \\[div link](https://example.com/div) should stay literal.
        \\</div>
        \\
        \\After html **Markdown resumes** here.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "**literal script bold** should not become bold.",
        "[script link](https://example.com/script) should stay literal.",
        "**literal div bold** should not become bold.",
        "[div link](https://example.com/div) should stay literal.",
        "After html Markdown resumes here.",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }
    try std.testing.expect(std.mem.indexOf(u8, rendered, "script link <https://example.com/script>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "div link <https://example.com/div>") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal script bold**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[script link](https://example.com/script)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal div bold**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[div link](https://example.com/div)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After html \\b Markdown resumes\\b0") != null);
}

test "preserves CommonMark block-level html tags as inert multiline blocks" {
    const input =
        \\<p class="lead">
        \\**literal paragraph html bold** should not render.
        \\[paragraph html link](https://example.com/p) should stay literal.
        \\</p>
        \\
        \\<ul>
        \\<li>**literal list html bold** should not render.</li>
        \\<li>[html list link](https://example.com/li) should stay literal.</li>
        \\</ul>
        \\
        \\After html **Markdown resumes** here.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal paragraph html bold** should not render.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[paragraph html link](https://example.com/p) should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "<li>**literal list html bold** should not render.</li>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "<li>[html list link](https://example.com/li) should stay literal.</li>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After html Markdown resumes here.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "paragraph html link <https://example.com/p>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "html list link <https://example.com/li>") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal paragraph html bold**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[paragraph html link](https://example.com/p)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<li>**literal list html bold**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<li>[html list link](https://example.com/li)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After html \\b Markdown resumes\\b0") != null);
}

test "ends CommonMark block-level html blocks only at a blank line" {
    const input =
        \\<div>
        \\**literal before close** stays raw.
        \\</div>
        \\[still raw before blank](https://example.com/still-raw) should stay literal until blank.
        \\
        \\After blank [real link](https://example.com/real) and **real bold** render.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal before close** stays raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[still raw before blank](https://example.com/still-raw) should stay literal until blank.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After blank real link <https://example.com/real> and real bold render.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "still raw before blank <https://example.com/still-raw>") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal before close**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[still raw before blank](https://example.com/still-raw)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul still raw before blank") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After blank \\cf3\\ul real link") != null);
}

test "keeps raw HTML blocks inert inside blockquote and list containers" {
    const input =
        \\> <div>
        \\> **not bold in quote html**
        \\> </div>
        \\>
        \\> after quote **bold** resumes.
        \\
        \\- <div>
        \\  **not bold in list html**
        \\  </div>
        \\
        \\- loose list before html
        \\
        \\  <div>
        \\  **not bold in loose list html**
        \\  </div>
        \\
        \\  after loose list **bold** resumes.
        \\
        \\After list **bold** resumes.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| **not bold in quote html**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  **not bold in list html**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* loose list before html") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  <div>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  **not bold in loose list html**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  after loose list bold resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| after quote bold resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After list bold resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| not bold in quote html") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  not bold in list html") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in quote html**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in list html**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in loose list html**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after loose list \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quote \\b bold\\b0  resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After list \\b bold\\b0  resumes.") != null);
}

test "keeps raw HTML blocks inert inside quoted lists and ordered lists" {
    const input =
        \\> - <div>
        \\>   **not bold in quoted list html**
        \\>   </div>
        \\>
        \\> - after quoted list **bold** resumes.
        \\
        \\1. <div>
        \\   **not bold in ordered html**
        \\   </div>
        \\
        \\After ordered **bold** resumes.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   **not bold in quoted list html**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  **not bold in ordered html**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * after quoted list bold resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After ordered bold resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   not bold in quoted list html") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  not bold in ordered html") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in quoted list html**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in ordered html**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quoted list \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After ordered \\b bold\\b0") != null);
}

test "ends type one HTML blocks inside containers at closing tags" {
    const input =
        \\> <script>
        \\> **not bold in quote script**
        \\> </script>
        \\> after quote script **bold** resumes immediately.
        \\
        \\- <pre>
        \\  **not bold in list pre**
        \\  </pre>
        \\  after list pre **bold** resumes immediately.
        \\
        \\> - <script>
        \\>   **not bold in quoted list script**
        \\>   </script>
        \\>   after quoted list script **bold** resumes immediately.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| **not bold in quote script**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  **not bold in list pre**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   **not bold in quoted list script**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| after quote script bold resumes immediately.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  after list pre bold resumes immediately.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   after quoted list script bold resumes immediately.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "not bold in quote script") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| not bold in quote script") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  not bold in list pre") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   not bold in quoted list script") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in quote script**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in list pre**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in quoted list script**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quote script \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after list pre \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quoted list script \\b bold\\b0") != null);
}

test "ends comments and CDATA inside containers at their closing markers" {
    const input =
        \\> <!-- quote comment starts
        \\> **not bold in quote comment**
        \\> -->
        \\> after quote comment **bold** resumes immediately.
        \\
        \\- <![CDATA[
        \\  **not bold in list cdata**
        \\  ]]>
        \\  after list cdata **bold** resumes immediately.
        \\
        \\> - <!-- quoted list comment starts
        \\>   **not bold in quoted list comment**
        \\>   -->
        \\>   after quoted list comment **bold** resumes immediately.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| **not bold in quote comment**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  **not bold in list cdata**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   **not bold in quoted list comment**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| after quote comment bold resumes immediately.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  after list cdata bold resumes immediately.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   after quoted list comment bold resumes immediately.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| after quote comment **bold**") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  after list cdata **bold**") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   after quoted list comment **bold**") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in quote comment**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in list cdata**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in quoted list comment**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quote comment \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after list cdata \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quoted list comment \\b bold\\b0") != null);
}

test "does not keep lowercase declarations active inside containers" {
    const input =
        \\> <!doctype html>
        \\> lowercase declaration **bold should render** here.
        \\>
        \\> <?zmd instruction
        \\> **not bold in quote pi**
        \\> ?>
        \\> after quote pi **bold** resumes immediately.
        \\
        \\- <!doctype html>
        \\  lowercase list declaration **bold should render** here.
        \\
        \\> - <!DOCTYPE markdown-test
        \\>   **not bold in quoted list declaration**
        \\>   >
        \\>   after quoted declaration **bold** resumes immediately.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| lowercase declaration bold should render here.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  lowercase list declaration bold should render here.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| **not bold in quote pi**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   **not bold in quoted list declaration**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| after quote pi bold resumes immediately.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   after quoted declaration bold resumes immediately.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| lowercase declaration **bold should render**") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  lowercase list declaration **bold should render**") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "lowercase declaration \\b bold should render\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "lowercase list declaration \\b bold should render\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in quote pi**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in quoted list declaration**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quote pi \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quoted declaration \\b bold\\b0") != null);
}

test "does not let type seven HTML interrupt container paragraphs" {
    const input =
        \\> Quote paragraph before
        \\> <del>
        \\> *emphasis inside quoted paragraph*
        \\> </del>
        \\> continues after closing tag.
        \\
        \\- List paragraph before
        \\  <del>
        \\  *emphasis inside list paragraph*
        \\  </del>
        \\  continues after closing tag.
        \\
        \\> - Quoted list paragraph before
        \\>   <del>
        \\>   *emphasis inside quoted list paragraph*
        \\>   </del>
        \\>   continues after closing tag.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| Quote paragraph before <del> emphasis inside quoted paragraph </del> continues after closing tag.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* List paragraph before <del> emphasis inside list paragraph </del> continues after closing tag.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * Quoted list paragraph before <del> emphasis inside quoted list paragraph </del> continues after closing tag.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| *emphasis inside quoted paragraph*") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  *emphasis inside list paragraph*") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|   *emphasis inside quoted list paragraph*") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "*emphasis inside quoted paragraph*") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "*emphasis inside list paragraph*") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "*emphasis inside quoted list paragraph*") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "emphasis inside quoted paragraph") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\i emphasis inside list paragraph\\i0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "emphasis inside quoted list paragraph") != null);
}

test "preserves CommonMark type six html block tag list as raw blocks" {
    const input =
        \\<aside class="note">
        \\**literal aside bold** should stay raw.
        \\[aside link](https://example.com/aside) should stay literal.
        \\</aside>
        \\[still raw before blank](https://example.com/still-raw) should stay literal until blank.
        \\
        \\After blank [real link](https://example.com/real) and **real bold** render.
        \\
        \\<main>
        \\**literal main bold** should stay raw too.
        \\[main link](https://example.com/main) should stay literal.
        \\</main>
        \\
        \\<footer>
        \\**literal footer bold** should stay raw too.
        \\</footer>
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal aside bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[aside link](https://example.com/aside) should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[still raw before blank](https://example.com/still-raw) should stay literal until blank.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "aside link <https://example.com/aside>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "still raw before blank <https://example.com/still-raw>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After blank real link <https://example.com/real> and real bold render.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal main bold** should stay raw too.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[main link](https://example.com/main) should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal footer bold** should stay raw too.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal aside bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[aside link](https://example.com/aside)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul aside link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After blank \\cf3\\ul real link") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal main bold** should stay raw too.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal footer bold** should stay raw too.") != null);
}

test "preserves CommonMark processing instructions and declarations as raw html blocks" {
    const input =
        \\<?zmd instruction
        \\**literal processing bold** should stay raw.
        \\[processing link](https://example.com/pi) should stay literal.
        \\?>
        \\
        \\<!DOCTYPE markdown-test
        \\**literal declaration bold** should stay raw.
        \\[declaration link](https://example.com/decl) should stay literal.
        \\>
        \\
        \\After html [real link](https://example.com/real) and **real bold** render.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal processing bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[processing link](https://example.com/pi) should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "processing link <https://example.com/pi>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal declaration bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[declaration link](https://example.com/decl) should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "declaration link <https://example.com/decl>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After html real link <https://example.com/real> and real bold render.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal processing bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[processing link](https://example.com/pi)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul processing link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal declaration bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[declaration link](https://example.com/decl)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul declaration link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After html \\cf3\\ul real link") != null);
}

test "does not treat lowercase html declarations as raw blocks" {
    const input =
        \\<!doctype markdown-test
        \\**lowercase declaration bold** should render.
        \\[lowercase declaration link](https://example.com/lower) should render.
        \\>
        \\
        \\<!DOCTYPE markdown-test
        \\**uppercase declaration bold** should stay raw.
        \\[uppercase declaration link](https://example.com/upper) should stay literal.
        \\>
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "<!doctype markdown-test lowercase declaration bold should render. lowercase declaration link <https://example.com/lower> should render.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| ") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**lowercase declaration bold**") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[lowercase declaration link](https://example.com/lower)") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**uppercase declaration bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[uppercase declaration link](https://example.com/upper) should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "uppercase declaration link <https://example.com/upper>") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b lowercase declaration bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul lowercase declaration link") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**uppercase declaration bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul uppercase declaration link") == null);
}

test "preserves CommonMark type seven complete html tags as raw blocks" {
    const input =
        \\<del>
        \\**literal del bold** should stay raw.
        \\[del link](https://example.com/del) should stay literal.
        \\</del>
        \\
        \\<a href="foo">
        \\**literal anchor bold** should stay raw.
        \\[anchor link](https://example.com/a) should stay literal.
        \\</a>
        \\
        \\</ins>
        \\**literal closing-start bold** should stay raw.
        \\[closing link](https://example.com/closing) should stay literal.
        \\
        \\After html [real link](https://example.com/real) and **real bold** render.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal del bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[del link](https://example.com/del) should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "del link <https://example.com/del>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal anchor bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[anchor link](https://example.com/a) should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "anchor link <https://example.com/a>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal closing-start bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[closing link](https://example.com/closing) should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "closing link <https://example.com/closing>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After html real link <https://example.com/real> and real bold render.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal del bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[del link](https://example.com/del)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul del link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal anchor bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[anchor link](https://example.com/a)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul anchor link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal closing-start bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[closing link](https://example.com/closing)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul closing link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After html \\cf3\\ul real link") != null);
}

test "does not let CommonMark type seven html blocks interrupt paragraphs" {
    const input =
        \\Paragraph before
        \\<del>
        \\*emphasized inside paragraph*
        \\</del>
        \\continues after closing tag.
        \\
        \\Blank-separated block should still stay raw:
        \\
        \\<del>
        \\**literal block bold** should stay raw.
        \\[block link](https://example.com/block) should stay literal.
        \\</del>
        \\
        \\After block [real link](https://example.com/real) and **real bold** render.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph before <del> emphasized inside paragraph </del> continues after closing tag.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "*emphasized inside paragraph*") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal block bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[block link](https://example.com/block) should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "block link <https://example.com/block>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After block real link <https://example.com/real> and real bold render.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Paragraph before <del> ") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\i emphasized inside paragraph\\i0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "</del> continues after closing tag.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal block bold** should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[block link](https://example.com/block)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul block link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After block \\cf3\\ul real link") != null);
}

test "preserves multiline html comments as inert text" {
    const input =
        \\<!-- comment starts
        \\**literal bold markers inside comment** should not become bold.
        \\[not a link](https://example.com/inside-comment) should stay literal.
        \\comment ends -->
        \\
        \\Paragraph after comment with **real bold** should still render bold.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "<!-- comment starts") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal bold markers inside comment**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[not a link](https://example.com/inside-comment)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "not a link <https://example.com/inside-comment>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph after comment with real bold should still render bold.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal bold markers inside comment**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[not a link](https://example.com/inside-comment)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul not a link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Paragraph after comment with \\b real bold\\b0") != null);
}

test "preserves multiline html cdata as inert text" {
    const input =
        \\<![CDATA[
        \\**literal bold markers inside cdata** should not become bold.
        \\[not a link](https://example.com/inside-cdata) should stay literal.
        \\]]>
        \\
        \\After cdata **Markdown resumes** here.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "<![CDATA[") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**literal bold markers inside cdata**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[not a link](https://example.com/inside-cdata)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "not a link <https://example.com/inside-cdata>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After cdata Markdown resumes here.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**literal bold markers inside cdata**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[not a link](https://example.com/inside-cdata)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul not a link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After cdata \\b Markdown resumes\\b0") != null);
}

test "renders ATX closing markers and tilde fenced code" {
    const input =
        \\### Heading with closing hashes ###
        \\
        \\~~~zig
        \\const message = "tilde fence must be code";
        \\~~~
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Heading with closing hashes ###") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Heading with closing hashes") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "---- code ----") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "const message = \"tilde fence must be code\";") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "~~~") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs30 Heading with closing hashes") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 const message") != null);
}

test "keeps fenced code inert inside blockquote and list containers" {
    const input =
        \\> ```zig
        \\> **not bold in quote fence**
        \\> [not link](https://example.com/quote)
        \\> ```
        \\> after quote fence **bold** resumes.
        \\
        \\- ~~~md
        \\  **not bold in list fence**
        \\  [not link](https://example.com/list)
        \\  ~~~
        \\  after list fence **bold** resumes.
        \\
        \\- Loose list before fence
        \\
        \\  ```md
        \\  **not bold in loose list fence**
        \\  [not link](https://example.com/loose-list)
        \\  ```
        \\
        \\  after loose list fence **bold** resumes.
        \\
        \\> - ```
        \\>   **not bold in quoted list fence**
        \\>   [not link](https://example.com/quoted-list)
        \\>   ```
        \\>   after quoted list fence **bold** resumes.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "|     **not bold in quote fence**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|     [not link](https://example.com/quote)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "not link <https://example.com/quote>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "      **not bold in list fence**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "      [not link](https://example.com/list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "not link <https://example.com/list>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* Loose list before fence") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  ---- code ----") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "      **not bold in loose list fence**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "      [not link](https://example.com/loose-list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "not link <https://example.com/loose-list>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|       **not bold in quoted list fence**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|       [not link](https://example.com/quoted-list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "not link <https://example.com/quoted-list>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "after quote fence bold resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "after list fence bold resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "after loose list fence bold resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "after quoted list fence bold resumes.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in quote fence**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[not link](https://example.com/quote)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul not link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in list fence**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[not link](https://example.com/list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in loose list fence**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[not link](https://example.com/loose-list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**not bold in quoted list fence**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[not link](https://example.com/quoted-list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quote fence \\b bold\\b0  resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after list fence \\b bold\\b0  resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after loose list fence \\b bold\\b0  resumes.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after quoted list fence \\b bold\\b0  resumes.") != null);
}

test "strips fenced code content indentation by columns across tabs" {
    const input =
        "# Fence indent tabs\n\n" ++
        "  ```\n" ++
        "  two spaces stripped\n" ++
        "    four spaces becomes two\n" ++
        "\ttab starts content\n" ++
        "  ```\n\n" ++
        "After fence **bold** resumes.\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "    two spaces stripped") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "      four spaces becomes two") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "      tab starts content") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\ttab starts content") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After fence bold resumes.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 two spaces stripped") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2   four spaces becomes two") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2   tab starts content") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\ttab starts content") == null);
}

test "renders empty ATX headings whose marker run ends the line" {
    const input =
        \\#
        \\
        \\###
        \\
        \\### ###
        \\
        \\######
        \\
        \\Normal heading below:
        \\## Filled Heading ##
        \\
        \\#######
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "\n==  ==\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\n#\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\n###\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\n######\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "-- Filled Heading --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "#######") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs44 \\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs30 \\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs24 \\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs36 Filled Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "#######") != null);
}

test "matches fenced code closing marker type and length" {
    const input =
        \\````markdown
        \\This line is code and contains a shorter fence:
        \\```
        \\still code after shorter inner fence
        \\````
        \\
        \\~~~zig
        \\const text = "tilde code";
        \\``` this mismatched backtick fence should stay code
        \\~~~
        \\
        \\Paragraph after fences.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "    ```\n    still code after shorter inner fence") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    ``` this mismatched backtick fence should stay code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph after fences.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 ```\\par") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 still code after shorter inner fence") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 ``` this mismatched backtick fence should stay code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Paragraph after fences.") != null);
}

test "rejects backtick fence info strings containing backticks" {
    const input =
        \\``` aa ```
        \\foo after invalid backtick fence should stay paragraph text.
        \\
        \\~~~ aa ` allowed for tilde info
        \\inside tilde code block
        \\~~~
        \\
        \\After tilde fence.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "foo after invalid backtick fence should stay paragraph text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    foo after invalid backtick fence") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    inside tilde code block") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After tilde fence.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    After tilde fence.") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 foo after invalid backtick fence") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "foo after invalid backtick fence should stay paragraph text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 inside tilde code block") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After tilde fence.") != null);
}

test "does not close fenced code with four-space indented fence" {
    const input =
        \\```
        \\first code line
        \\    ```
        \\still code after four-space pseudo close
        \\```
        \\
        \\After fence paragraph.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "    first code line\n        ```") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    still code after four-space pseudo close") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After fence paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    After fence paragraph.") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 first code line") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2     ```") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 still code after four-space pseudo close") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After fence paragraph.") != null);
}

test "strips opening fence indentation from fenced code content" {
    const input =
        \\  ```
        \\  two spaces should be stripped
        \\ one space should also be stripped
        \\no strip needed here
        \\  ```
        \\
        \\After indented fence.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "    two spaces should be stripped") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    one space should also be stripped") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    no strip needed here") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "      two spaces should be stripped") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After indented fence.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 two spaces should be stripped") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 one space should also be stripped") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 no strip needed here") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2   two spaces should be stripped") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After indented fence.") != null);
}

test "does not let indented code interrupt paragraphs" {
    const input =
        \\   ### three-space heading should render as heading
        \\
        \\    # four-space heading should stay indented code
        \\
        \\Paragraph before four-space pseudo heading
        \\    ## should remain paragraph continuation, not heading.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "three-space heading should render as heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    # four-space heading should stay indented code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph before four-space pseudo heading ## should remain paragraph continuation, not heading.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    ## should remain paragraph continuation") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\fs30 three-space heading should render as heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 # four-space heading should stay indented code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Paragraph before four-space pseudo heading ## should remain paragraph continuation") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 ## should remain paragraph continuation") == null);
}

test "renders ordered paren markers, thematic breaks, and link titles" {
    const input =
        \\1) ordered paren
        \\2) [title link](https://example.com "Example Title")
        \\
        \\* * *
        \\
        \\![Image with title](./image.png "Image Title")
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "1) ordered paren") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "title link <https://example.com>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Example Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "---") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: Image with title] <./image.png>") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "1)\\tab ordered paren") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Example Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "------------------------------") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: Image with title] ./image.png") != null);
}

test "keeps inline links with unbracketed destination spaces literal" {
    const input =
        \\Invalid plain destination with space: [bad space](/my uri) should stay literal.
        \\Invalid image destination with space: ![bad image](images/my icon.png) should stay literal.
        \\Valid angle destination with space: [angle space](</my uri>) should render as a link.
        \\Valid title after plain destination: [title ok](/my-uri "Title") should render as a link.
        \\Valid empty destination: [empty]() should render as a link with empty destination.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "[bad space](/my uri)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "![bad image](images/my icon.png)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "angle space </my uri>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "title ok </my-uri>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "empty <>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "bad space </my>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: bad image] <images/my>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Title") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "[bad space](/my uri)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "![bad image](images/my icon.png)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </my uri>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </my-uri>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "bad space\\ulnone\\cf1 \\cf2 </my>") == null);
}

test "requires link titles to be separated and terminal" {
    const input =
        \\Invalid inline no separator: [bad inline](<bar>(baz)) should stay literal.
        \\Invalid reference no separator: [bad ref][bad-ref] should stay unresolved.
        \\Invalid reference trailing garbage: [garbage ref][garbage-ref] should stay unresolved.
        \\Valid inline with separator: [good inline](<bar> (baz)) should render.
        \\Valid reference with separator: [good ref][good-ref] should render.
        \\
        \\[bad-ref]: <bar>(baz)
        \\[garbage-ref]: /url "title" ok
        \\
        \\[good-ref]: <bar> (baz)
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "[bad inline](<bar>(baz))") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[bad ref][bad-ref] should stay unresolved") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[garbage ref][garbage-ref] should stay unresolved") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "good inline <bar>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "good ref <bar>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[bad-ref]: <bar>(baz)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[garbage-ref]: /url \"title\" ok") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "bad inline <bar>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "bad ref <bar>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "garbage ref </url>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[good-ref]:") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "[bad inline](<bar>(baz))") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[bad ref][bad-ref] should stay unresolved") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[garbage ref][garbage-ref] should stay unresolved") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <bar>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[bad-ref]: <bar>(baz)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[garbage-ref]: /url \"title\" ok") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul bad ref") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul garbage ref") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[good-ref]:") == null);
}

test "renders inline links with quoted title parentheses" {
    const input =
        \\Quoted title paren should resolve: [paren title](/docs/paren "title with ) parenthesis").
        \\Single quoted title paren should resolve: [single title](/docs/single 'single ) parenthesis').
        \\Parenthesized title with escaped paren should resolve: [escaped paren](/docs/escaped (title with \) paren)).
        \\Invalid unescaped parenthesized title should stay literal: [bad title](/docs/bad (title ) breaks)).
        \\After links **real bold** renders.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Quoted title paren should resolve: paren title </docs/paren>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Single quoted title paren should resolve: single title </docs/single>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Parenthesized title with escaped paren should resolve: escaped paren </docs/escaped>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Invalid unescaped parenthesized title should stay literal: [bad title](/docs/bad (title ) breaks)).") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After links real bold renders.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul paren title") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul single title") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul escaped paren") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[bad title](/docs/bad (title ) breaks)).") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After links \\b real bold\\b0") != null);
}

test "preserves ordered list source markers in plain render" {
    const input =
        \\7. starts at seven
        \\8) paren marker should stay paren
        \\123. wide marker should stay 123
        \\
        \\> 42) quoted paren marker
        \\> 43. quoted dot marker
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "7. starts at seven",
        "8) paren marker should stay paren",
        "123. wide marker should stay 123",
        "| 42) quoted paren marker",
        "| 43. quoted dot marker",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }
}

test "renders zero-start ordered sibling lists without lazy nesting" {
    const input =
        \\0. zero-start top-level list item should render.
        \\2. two-start top-level list item should render.
        \\
        \\Paragraph before
        \\0. zero cannot interrupt paragraph and should stay paragraph text.
        \\
        \\Paragraph before one
        \\1. one can interrupt paragraph as ordered list.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "0. zero-start top-level list item should render.\n2. two-start top-level list item should render.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\n  2. two-start top-level list item should render.") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph before 0. zero cannot interrupt paragraph and should stay paragraph text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph before one\n1. one can interrupt paragraph as ordered list.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li520\\fi-300\\tx640\\sa70\\f0\\fs22\\cf1 0.\\tab zero-start") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li520\\fi-300\\tx640\\sa70\\f0\\fs22\\cf1 2.\\tab two-start") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li880\\fi-300\\tx1000\\sa70\\f0\\fs22\\cf1 2.\\tab two-start") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Paragraph before 0. zero cannot interrupt paragraph") != null);
}

test "keeps non-one ordered markers inside quoted paragraphs" {
    const input =
        \\> Quote before
        \\> 0. zero cannot interrupt quoted paragraph and should stay text.
        \\>
        \\> Quote before one
        \\> 1. one can interrupt quoted paragraph as ordered list.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| Quote before 0. zero cannot interrupt quoted paragraph and should stay text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| Quote before\n| 0. zero cannot interrupt quoted paragraph") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| Quote before one\n| 1. one can interrupt quoted paragraph as ordered list.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Quote before 0. zero cannot interrupt quoted paragraph") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Quote before\\i0\\cf1\\par\n\\pard\\li360\\ri240\\sb60\\sa100\\i\\cf2 0.") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "1.\\tab one can interrupt quoted paragraph as ordered list") != null);
}

test "keeps indented non-one ordered markers inside list item paragraphs" {
    const input =
        \\- Item before
        \\  0. zero cannot interrupt list item paragraph and should stay text.
        \\
        \\- Item before one
        \\  1. one can interrupt list item paragraph as nested ordered list.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "* Item before 0. zero cannot interrupt list item paragraph and should stay text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* Item before\n  0. zero cannot interrupt list item paragraph") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* Item before one\n  1. one can interrupt list item paragraph as nested ordered list.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Item before 0. zero cannot interrupt list item paragraph") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "0.\\tab zero cannot interrupt list item paragraph") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "1.\\tab one can interrupt list item paragraph as nested ordered list") != null);
}

test "keeps indented non-one ordered markers inside quoted list item paragraphs" {
    const input =
        \\> - Quote item before
        \\>   0. zero cannot interrupt quoted list item paragraph and should stay text.
        \\>
        \\> - Quote item before one
        \\>   1. one can interrupt quoted list item paragraph as nested ordered list.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * Quote item before 0. zero cannot interrupt quoted list item paragraph and should stay text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * Quote item before\n|   0. zero cannot interrupt quoted list item paragraph") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * Quote item before one\n|   1. one can interrupt quoted list item paragraph as nested ordered list.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Quote item before 0. zero cannot interrupt quoted list item paragraph") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "0.\\tab zero cannot interrupt quoted list item paragraph") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "1.\\tab one can interrupt quoted list item paragraph as nested ordered list") != null);
}

test "starts non-one ordered lists after blank lines in containers" {
    const input =
        \\Paragraph before blank.
        \\
        \\0. zero starts a top-level list after blank.
        \\
        \\> Quote paragraph before blank.
        \\>
        \\> 0. zero starts a quoted list after blank.
        \\
        \\- List paragraph before blank.
        \\
        \\  0. zero starts a nested list after blank in list item.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph before blank.\n\n0. zero starts a top-level list after blank.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| Quote paragraph before blank.\n| \n| 0. zero starts a quoted list after blank.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* List paragraph before blank.\n\n  0. zero starts a nested list after blank in list item.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\n0. zero starts a nested list after blank in list item.") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "0.\\tab zero starts a top-level list after blank") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "0.\\tab zero starts a quoted list after blank") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "0.\\tab zero starts a nested list after blank in list item") != null);
}

test "keeps nested ordered siblings separate in loose list items" {
    const input =
        \\- parent before nested bullet
        \\
        \\  - child bullet with **bold**
        \\  - child bullet with [link](https://example.test/child)
        \\
        \\  after child bullets.
        \\
        \\1. ordered parent before nested ordered
        \\
        \\   1. nested ordered with `code`
        \\   2. nested ordered second
        \\
        \\   after nested ordered.
        \\
        \\- sibling after nested lists.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "* parent before nested bullet") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  * child bullet with bold") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  * child bullet with link <https://example.test/child>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "1. ordered parent before nested ordered") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  1. nested ordered with code\n  2. nested ordered second") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "nested ordered with code 2. nested ordered second") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* sibling after nested lists.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab child bullet with") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "1.\\tab nested ordered with") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "2.\\tab nested ordered second") != null);
}

test "does not over-indent blockquote paragraphs after tab padding" {
    const input =
        "# Tab after container markers\n\n" ++
        "> \tblockquote tab content after marker should render as text.\n\n" ++
        "-\tlist tab content after bullet marker should render as item text.\n\n" ++
        "1.\tordered tab content after marker should render as item text.\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| blockquote tab content after marker should render as text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|     blockquote tab content") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* list tab content after bullet marker should render as item text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "1. ordered tab content after marker should render as item text.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "blockquote tab content after marker should render as text") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li1080\\ri240\\sb60\\sa100\\i\\cf2 blockquote tab content") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab list tab content after bullet marker") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "1.\\tab ordered tab content after marker") != null);
}

test "does not over-indent blockquote list markers after tab padding" {
    const input =
        "# Blockquote tab before list markers\n\n" ++
        "> \t- tab-padded quoted bullet should be a quoted list item without extra nesting.\n" ++
        "> \t1. tab-padded quoted ordered should be a quoted ordered list item without extra nesting.\n\n" ++
        "> \tContinuation after tab-padded marker block should be paragraph text.\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * tab-padded quoted bullet should be a quoted list item without extra nesting.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| 1. tab-padded quoted ordered should be a quoted ordered list item without extra nesting.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|     * tab-padded quoted bullet") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "|     1. tab-padded quoted ordered") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| Continuation after tab-padded marker block should be paragraph text.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab tab-padded quoted bullet") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "1.\\tab tab-padded quoted ordered") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Continuation after tab-padded marker block should be paragraph text") != null);
}

test "limits ordered list markers to nine digits" {
    const input =
        \\123456789. valid nine digit marker should render as a list.
        \\1234567890. ten digit marker should stay paragraph text.
        \\
        \\> 1234567890. quoted ten digit marker should stay quote text.
        \\
        \\1) valid paren marker should still render as a list.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "123456789. valid nine digit marker should render as a list.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "1234567890. ten digit marker should stay paragraph text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| 1234567890. quoted ten digit marker should stay quote text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "1) valid paren marker should still render as a list.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "123456789. \\tab valid nine digit marker") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "1234567890.\\tab") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "1)\\tab valid paren marker") != null);
}

test "ordered lists interrupt paragraphs only when starting at one" {
    const input =
        \\Paragraph before non-one marker
        \\2. should stay in the paragraph, not become a list.
        \\
        \\Paragraph before one marker
        \\1. should become a list after interrupting the paragraph.
        \\
        \\Blank before non-one marker should allow list:
        \\
        \\2. starts a list after a blank.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph before non-one marker 2. should stay in the paragraph, not become a list.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph before one marker\n1. should become a list after interrupting the paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Blank before non-one marker should allow list:\n\n2. starts a list after a blank.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Paragraph before non-one marker 2. should stay in the paragraph") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "2.\\tab should stay in the paragraph") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "1.\\tab should become a list") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "2.\\tab starts a list after a blank") != null);
}

test "renders inline links and images with balanced or escaped destination parentheses" {
    const input =
        \\Link with parens: [spec](docs/api(v1).md) should keep whole destination.
        \\Image with parens: ![diagram](assets/flow(chart).png "Flow Chart") should keep whole path.
        \\Escaped paren link: [escaped](docs/file\)name.md) should keep escaped right paren.
        \\Normal link: [plain](https://example.com/plain) still works.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "spec <docs/api(v1).md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: diagram] <assets/flow(chart).png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Flow Chart") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "escaped <docs/file)name.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "plain <https://example.com/plain>") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/api(v1).md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: diagram] assets/flow(chart).png") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Flow Chart") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/file)name.md>") != null);
}

test "renders angle bracket link destinations with inner parens" {
    const input =
        \\Angle space: [space dest](<https://example.com/a b> "Space Title") should strip title.
        \\Angle paren: [paren dest](<https://example.com/a)b>) should keep paren in destination.
        \\Image angle paren: ![image paren](<assets/a)b.png> "Image Title") should be readable.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "space dest <https://example.com/a b>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "paren dest <https://example.com/a)b>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: image paren] <assets/a)b.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Space Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Image Title") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/a b>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/a)b>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: image paren] assets/a)b.png") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Space Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Image Title") == null);
}

test "renders inline links and images with escaped or nested label brackets" {
    const input =
        \\Escaped label: [literal \] bracket](docs/escaped.md) should show one closing bracket.
        \\Nested label: [outer [inner] label](docs/nested.md) should keep the full label.
        \\Escaped image alt: ![diagram \] alt](assets/diagram.png) should show the escaped bracket.
        \\Reference escaped: [ref \] label][bracket-ref] should resolve.
        \\
        \\[bracket-ref]: docs/reference.md
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "literal ] bracket <docs/escaped.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "outer [inner] label <docs/nested.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: diagram ] alt] <assets/diagram.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "ref ] label <docs/reference.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[bracket-ref]:") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul literal ] bracket") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul outer [inner] label") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: diagram ] alt] assets/diagram.png") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul ref ] label") != null);
}

test "renders inline markdown inside link labels" {
    const input =
        \\Inline formatted label: [**bold label** and `code`](https://example.com/inline).
        \\Reference formatted label: [*italic ref* and ~~strike ref~~][fmt-ref].
        \\Escaped label still works: [literal \] bracket](docs/escaped.md).
        \\
        \\[fmt-ref]: https://example.com/ref "Hidden Title"
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Inline formatted label: bold label and code <https://example.com/inline>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Reference formatted label: italic ref and strike ref <https://example.com/ref>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**bold label**") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "`code`") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "literal ] bracket <docs/escaped.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hidden Title") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul \\b bold label\\b0  and \\f1\\fs20\\highlight4 code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul \\i italic ref\\i0  and \\strike strike ref\\strike0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul literal ] bracket") != null);
}

test "renders nested emphasis and strong inside reference labels" {
    const input =
        \\Paragraph with [**strong *em* label**][ref] and [*em **strong** label*][ref].
        \\Nested image alt: ![**bold *em* alt** and `code`][img].
        \\
        \\[ref]: https://example.test/ref
        \\[img]: assets/nested.png
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "strong em label <https://example.test/ref>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "em strong label <https://example.test/ref>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: bold em alt and code] <assets/nested.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**strong* label*") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul \\b strong \\i em\\i0  label\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul \\i em \\b strong\\b0  label\\i0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**strong* label*") == null);
}

test "renders inline markdown inside image alt text" {
    const input =
        \\Inline formatted alt: ![**bold alt** and `code`](images/inline.png "Hidden Title").
        \\Reference formatted alt: ![*italic alt* and ~~strike alt~~][img-ref].
        \\Escaped alt still works: ![literal \] alt](images/escaped.png).
        \\
        \\[img-ref]: images/ref.png "Hidden Title"
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: bold alt and code] <images/inline.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: italic alt and strike alt] <images/ref.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**bold alt**") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "`code`") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "~~strike alt~~") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: literal ] alt] <images/escaped.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hidden Title") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: bold alt and code] images/inline.png") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: italic alt and strike alt] images/ref.png") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b bold alt\\b0") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\highlight4 code") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\strike strike alt") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: literal ] alt] images/escaped.png") != null);
}

test "does not promote link labels containing nested links" {
    const input =
        \\Inline nested link label: [outer [inner](https://inner.example) label](https://outer.example) should keep the outer link literal.
        \\Reference nested link label: [ref [inner](https://inner.example) label][outer-ref] should keep the outer label literal.
        \\Image nested link alt: ![alt [inner](https://inner.example) label](image.png) should hide the nested destination in alt text.
        \\
        \\[outer-ref]: https://outer-ref.example
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "[outer inner <https://inner.example> label](https://outer.example)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[ref inner <https://inner.example> label]outer-ref <https://outer-ref.example>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: alt inner label] <image.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "label <https://outer.example>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: alt inner <https://inner.example> label]") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: alt inner label] image.png") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://outer.example>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: alt inner \\cf2 <https://inner.example>") == null);
}

test "preserves invalid punctuation-adjacent strong delimiters" {
    const input =
        \\Invalid strong after alnum before punctuation: a**"foo"** and a__"bar"__ stay literal.
        \\Valid punctuation context: foo-**(bar)** and foo-__(baz)__ render.
        \\Invalid closing before punctuation then alnum: **foo "**bar and __foo "__bar stay literal.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "a**\"foo\"**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "a__\"bar\"__") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "foo-(bar)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "foo-(baz)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**foo \"**bar") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "__foo \"__bar") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "a\"foo\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "a\"bar\"") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "a**\"foo\"**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "a__\"bar\"__") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "foo-\\b (bar)\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "foo-\\b (baz)\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "**foo \"**bar") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "__foo \"__bar") != null);
}

test "searches past invalid soft-line emphasis closers" {
    const input =
        \\Trailing space invalid: *not italic * should keep markers.
        \\Intraword underscore invalid: foo_bar_baz should keep underscores.
        \\Intraword asterisk valid: foo*bar*baz should emphasize bar.
        \\Punctuation around asterisk: a*"b"* should stay literal.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Trailing space invalid: not italic * should keep markers.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Intraword asterisk valid: foobarbaz should emphasize bar.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Punctuation around asterisk: a\"b\"* should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Trailing space invalid: *not italic *") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Trailing space invalid: \\i not italic * should keep markers.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Intraword asterisk valid: foo\\i0 bar\\i baz") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Punctuation around asterisk: a\\i0 \"b\"* should stay literal.") != null);
}

test "preserves intraword underscore runs inside single emphasis spans" {
    const input =
        \\Mixed punctuation boundaries: a_b_ c_d_ _e_f g__h__ i__j k__.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Mixed punctuation boundaries: a_b_ c_d_ e_f g__h_ i__j k__.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "e_f gh_") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Mixed punctuation boundaries: a_b_ c_d_ \\i e_f g__h\\i0 _ i__j k__.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "e_f gh_") == null);
}

test "renders escaped strong closers as nested emphasis leftovers" {
    const input =
        \\Escaped asterisk strong closer: **foo \** bar**.
        \\Escaped underscore strong closer: __foo \__ bar__.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Escaped asterisk strong closer: foo * bar*.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Escaped underscore strong closer: foo _ bar_.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "foo ** bar") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "foo __ bar") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Escaped asterisk strong closer: \\i foo * bar\\i0 *.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Escaped underscore strong closer: \\i foo _ bar\\i0 _.") != null);
}

test "renders reference links, reference images, and basic entities" {
    const input =
        \\Reference link: [Reference Link][ref]
        \\Collapsed reference: [Collapsed Ref][]
        \\Shortcut reference: [Shortcut Ref]
        \\Reference image: ![Ref Image][img]
        \\Shortcut reference image: ![Shortcut Image]
        \\Missing shortcut image: ![Missing Image]
        \\Entity text: AT&amp;T &lt;viewer&gt; &#x2713; &#10003;.
        \\
        \\[ref]: https://example.com/ref "Ref Title"
        \\[collapsed ref]: https://example.com/collapsed
        \\[shortcut ref]: https://example.com/shortcut
        \\[img]: ./ref-image.png "Image Title"
        \\[shortcut image]: ./shortcut-image.png
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Reference Link <https://example.com/ref>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Collapsed Ref <https://example.com/collapsed>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Shortcut Ref <https://example.com/shortcut>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: Ref Image] <./ref-image.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: Shortcut Image] <./shortcut-image.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "![Missing Image]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "!Shortcut Image <./shortcut-image.png>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "AT&T <viewer> ✓ ✓") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[ref]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Ref Title") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul Reference Link") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/ref>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 [image: Ref Image] ./ref-image.png") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 [image: Shortcut Image] ./shortcut-image.png") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "![Missing Image]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "AT&T <viewer> \\u10003? \\u10003?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[ref]:") == null);
}

test "strips UTF-8 BOM and escapes NUL replacement glyphs for RTF" {
    const input = "\xef\xbb\xbf# BOM and NUL\r\n\r\nA\x00B\r\n\r\n```\r\ncode \x00 line\r\n```\r\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "\u{feff}") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "== BOM and NUL ==") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "A\u{fffd}B") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "code \u{fffd} line") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\u{feff}") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\u{fffd}") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "A\\'ef\\'bf\\'bdB") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "code \\'ef\\'bf\\'bd line") != null);
}

test "replaces malformed UTF-8 input bytes with replacement characters" {
    const input = "# Invalid UTF-8\n\nBad: \xc3( \xe2(\xa1 \xf0(\x8c\xbc \xff.\n\n```\ncode \xc0\x80\xed\xa0\x80\n```\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.unicode.utf8ValidateSlice(rendered));
    try std.testing.expect(std.mem.indexOf(u8, rendered, "== Invalid UTF-8 ==") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Bad: \u{fffd}( \u{fffd}(\u{fffd} \u{fffd}(\u{fffd}\u{fffd} \u{fffd}.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "code \u{fffd}\u{fffd}\u{fffd}\u{fffd}\u{fffd}") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.unicode.utf8ValidateSlice(rtf));
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Bad: \\'ef\\'bf\\'bd( \\'ef\\'bf\\'bd(\\'ef\\'bf\\'bd") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "code \\'ef\\'bf\\'bd\\'ef\\'bf\\'bd\\'ef\\'bf\\'bd\\'ef\\'bf\\'bd\\'ef\\'bf\\'bd") != null);
}

test "replaces unsafe ASCII controls while preserving tab and line endings" {
    const input = "# ASCII controls\n\nBEL\x07 ESC\x1b BS\x08 DEL\x7f tab\tkept\n\n```\ncode\x01\tok\x7f\n```\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "BEL\u{fffd} ESC\u{fffd} BS\u{fffd} DEL\u{fffd} tab\tkept") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "code\u{fffd}\tok\u{fffd}") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, rendered, 0x07) == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, rendered, 0x1b) == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, rendered, 0x7f) == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "BEL\\'ef\\'bf\\'bd ESC\\'ef\\'bf\\'bd BS\\'ef\\'bf\\'bd DEL\\'ef\\'bf\\'bd tab\\tab kept") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "code\\'ef\\'bf\\'bd\\tab ok\\'ef\\'bf\\'bd") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, rtf, 0x07) == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, rtf, 0x1b) == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, rtf, 0x7f) == null);
}

test "unescapes punctuation in reference destinations" {
    const input =
        \\Reference escaped destination: [Escaped Dest][escaped].
        \\Reference escaped image: ![Diagram][escaped].
        \\
        \\[escaped]: docs/file\*name\(v1\).md "Hidden Title"
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Escaped Dest <docs/file*name(v1).md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: Diagram] <docs/file*name(v1).md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "docs/file\\*name\\(v1\\).md") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hidden Title") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/file*name(v1).md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: Diagram] docs/file*name(v1).md") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "docs/file\\*name\\(v1\\).md") == null);
}

test "handles escaped and nested angle-bracketed link destinations" {
    const input =
        \\Valid escaped angle destination: [escaped](<docs/a\>b.md>) should decode to a > in the URL.
        \\
        \\Invalid nested angle destination: [bad nested](<docs/<bad>.md>) should stay literal.
        \\
        \\Reference escaped angle: [ref escaped][ok].
        \\
        \\Reference nested angle: [ref nested][bad] should stay unresolved.
        \\
        \\[ok]: <docs/ref\>ok.md>
        \\[bad]: <docs/<bad>.md>
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Valid escaped angle destination: escaped <docs/a>b.md> should decode to a > in the URL.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Invalid nested angle destination: [bad nested](<docs/<bad>.md>) should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Reference escaped angle: ref escaped <docs/ref>ok.md>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Reference nested angle: [ref nested][bad] should stay unresolved.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[bad]: <docs/<bad>.md>") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul escaped") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<docs/a>b.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[bad nested](<docs/<bad>.md>)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul ref escaped") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "<docs/ref>ok.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[ref nested][bad]") != null);
}

test "decodes entities in link and image destinations" {
    const input =
        \\Inline amp destination: [inline amp](docs?a=1&amp;b=2).
        \\Inline escaped/entity destination: [inline mix](docs/file\*name&amp;v=1).
        \\Inline numeric destination: [inline numeric](docs/check&#x2713;.md).
        \\Angle entity destination: [angle amp](<docs/path?a=1&amp;b=2>).
        \\Reference amp destination: [ref amp][amp-ref].
        \\Reference image amp destination: ![img amp][img-ref].
        \\Invalid entity destination: [invalid entity](docs?x=&MadeUpEntity;).
        \\
        \\[amp-ref]: docs/ref?a=1&amp;b=2 "hidden title"
        \\[img-ref]: assets/img&amp;icon&#x2713;.png "hidden title"
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "inline amp <docs?a=1&b=2>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "inline mix <docs/file*name&v=1>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "inline numeric <docs/check✓.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "angle amp <docs/path?a=1&b=2>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "ref amp <docs/ref?a=1&b=2>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: img amp] <assets/img&icon✓.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "invalid entity <docs?x=&MadeUpEntity;>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&amp;b=2") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&#x2713;") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "hidden title") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs?a=1&b=2>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/file*name&v=1>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/check\\u10003?.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/path?a=1&b=2>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/ref?a=1&b=2>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: img amp] assets/img&icon\\u10003?.png") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "docs?x=&MadeUpEntity;") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&amp;b=2") == null);
}

test "matches reference labels with collapsed internal whitespace" {
    const input =
        \\Shortcut collapsed: [Multi   Space   Ref] should resolve despite whitespace.
        \\Explicit collapsed: [visible explicit][Multi   Space Ref] should also resolve.
        \\Angle destination: [angle reference][angle-ref] should keep spaces in angle destination.
        \\
        \\[Multi Space Ref]: <https://example.com/ref path> "Hidden Title"
        \\[angle-ref]: <https://example.com/a)b path> 'Angle Hidden Title'
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Multi   Space   Ref <https://example.com/ref path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "visible explicit <https://example.com/ref path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "angle reference <https://example.com/a)b path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[Multi Space Ref]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hidden Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Angle Hidden Title") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul Multi   Space   Ref") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul visible explicit") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/ref path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/a)b path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Hidden Title") == null);
}

test "resolves multiline reference definitions inside blockquote and list containers" {
    const input =
        \\> [quote
        \\> label]: https://quote.example/path
        \\
        \\- [list
        \\  label]: https://list.example/path
        \\
        \\Quote use: [quote label]
        \\
        \\List use: [list label]
        \\
        \\Multiline shortcut use: [quote
        \\label]
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Quote use: quote label <https://quote.example/path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "List use: list label <https://list.example/path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Multiline shortcut use: quote label <https://quote.example/path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[quote label]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[list label]:") == null);
}

test "preserves list markers after hidden reference definitions" {
    const input =
        "> [quoted-ref]:\n" ++
        "> \t/quoted-dest\n" ++
        "> \t\"Quoted Title\"\n" ++
        "> quoted link: [quoted label][quoted-ref]\n" ++
        "\n" ++
        "> - [nested-ref]:\n" ++
        ">   \t/nested-dest\n" ++
        ">   \t\"Nested Title\"\n" ++
        ">   nested link: [nested label][nested-ref]\n" ++
        "\n" ++
        "- [list-ref]:\n" ++
        "  \t/list-dest\n" ++
        "  \t\"List Title\"\n" ++
        "  list link: [list label][list-ref]\n" ++
        "\n" ++
        "1. [ordered-ref]: /ordered-dest\n" ++
        "   ordered link: [ordered label][ordered-ref]\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| quoted link: quoted label </quoted-dest>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * nested link: nested label </nested-dest>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* list link: list label </list-dest>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "1. ordered link: ordered label </ordered-dest>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[list-ref]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[ordered-ref]:") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "quoted link:") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab nested link:") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab list link:") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "1.\\tab ordered link:") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "List Title") == null);
}

test "preserves hidden reference list markers across blank continuations" {
    const input =
        "- [blank-ref]: /blank-dest\n" ++
        "\n" ++
        "  after blank link: [blank label][blank-ref]\n" ++
        "\n" ++
        "> - [qblank]: /qblank-dest\n" ++
        ">\n" ++
        ">   after quoted blank link: [qblank label][qblank]\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "* after blank link: blank label </blank-dest>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * after quoted blank link: qblank label </qblank-dest>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  after blank link: blank label </blank-dest>") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab after blank link:") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab after quoted blank link:") != null);
}

test "preserves hidden reference list markers before heading continuations" {
    const input =
        "- [head-ref]: /head-dest\n" ++
        "\n" ++
        "  ## heading link [head label][head-ref]\n" ++
        "\n" ++
        "> - [qhead]: /qhead-dest\n" ++
        ">\n" ++
        ">   ### quoted heading link [qhead label][qhead]\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "* -- heading link head label </head-dest> --") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * quoted heading link qhead label </qhead-dest>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\n-- heading link head label </head-dest> --") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab \\b\\fs36 heading link") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab \\b\\fs30 quoted heading link") != null);
}

test "preserves hidden reference list markers before fenced code continuations" {
    const input =
        "- [code-ref]: /code-dest\n" ++
        "\n" ++
        "  ```zig\n" ++
        "  const label = \"[code-ref]\";\n" ++
        "  ```\n" ++
        "\n" ++
        "> - [qcode]: /qcode-dest\n" ++
        ">\n" ++
        ">   ```text\n" ++
        ">   [qcode] should stay literal inside code\n" ++
        ">   ```\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "* ---- code ----") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "      const label = \"[code-ref]\";") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * ---- code ----") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[qcode] should stay literal inside code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "qcode </qcode-dest> should stay literal inside code") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab \\i0\\f1\\fs20\\cf2 ---- code ----") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[qcode] should stay literal inside code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </qcode-dest>") == null);
}

test "preserves hidden reference list markers before raw html continuations" {
    const input =
        "- [html-ref]: /html-dest\n" ++
        "\n" ++
        "  <div>\n" ++
        "  html [html-ref] stays raw\n" ++
        "  </div>\n" ++
        "\n" ++
        "> - [qhtml]: /qhtml-dest\n" ++
        ">\n" ++
        ">   <section>\n" ++
        ">   quoted [qhtml] stays raw\n" ++
        ">   </section>\n";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "* <div>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "html [html-ref] stays raw") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * <section>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "quoted [qhtml] stays raw") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "html-ref </html-dest>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "qhtml </qhtml-dest>") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab <div>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "quoted [qhtml] stays raw") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </html-dest>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </qhtml-dest>") == null);
}

test "hides following reference titles inside nested containers" {
    const input =
        \\> - [nested quote list]: https://nested.example/path
        \\>   "Nested Quote List Title"
        \\
        \\- [list title]: https://list.example/path
        \\  'List Title'
        \\
        \\Nested use: [nested quote list]
        \\
        \\List use: [list title]
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Nested use: nested quote list <https://nested.example/path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "List use: list title <https://list.example/path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Nested Quote List Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "List Title") == null);
}

test "matches reference labels with common Unicode case folding" {
    const input =
        \\Accented shortcut: [Über] should resolve.
        \\Sharp-s shortcut: [STRASSE] should resolve.
        \\Explicit accented: [visible][ÄPFEL] should resolve.
        \\Accent-sensitive control: [visible][CAFÉ] should stay literal.
        \\
        \\[über]: https://example.com/umlaut
        \\[straße]: https://example.com/strasse
        \\[äpfel]: https://example.com/apples
        \\[cafe]: https://example.com/plain
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Über <https://example.com/umlaut>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "STRASSE <https://example.com/strasse>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "visible <https://example.com/apples>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[visible][CAFÉ] should stay literal") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[Über]") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[STRASSE]") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[visible][ÄPFEL]") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/umlaut>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/strasse>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/apples>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[visible][CAF") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "https://example.com/plain") == null);
}

test "matches reference labels with special Unicode case folds" {
    const input =
        \\Kelvin shortcut: [Kelvin] should resolve.
        \\Long-s shortcut: [ſcript] should resolve.
        \\Ohm shortcut: [Ωmega] should resolve.
        \\Angstrom shortcut: [Ångstrom] should resolve.
        \\Dotted-I shortcut: [İstanbul] should resolve.
        \\Dcaron shortcut: [Ďcaron] should resolve.
        \\Greek tonos shortcut: [Όmicron] should resolve.
        \\Latin Extended-A shortcut: [Āmacron] [Ődouble] [Ŋeng] should resolve.
        \\
        \\[kelvin]: https://example.com/kelvin
        \\[script]: https://example.com/script
        \\[ωmega]: https://example.com/omega
        \\[ångstrom]: https://example.com/angstrom
        \\[i̇stanbul]: https://example.com/istanbul
        \\[ďcaron]: https://example.com/dcaron
        \\[όmicron]: https://example.com/omicron-tonos
        \\[āmacron]: https://example.com/amacron
        \\[ődouble]: https://example.com/odouble
        \\[ŋeng]: https://example.com/eng
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Kelvin <https://example.com/kelvin>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "ſcript <https://example.com/script>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Ωmega <https://example.com/omega>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Ångstrom <https://example.com/angstrom>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "İstanbul <https://example.com/istanbul>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Ďcaron <https://example.com/dcaron>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Όmicron <https://example.com/omicron-tonos>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Āmacron <https://example.com/amacron>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Ődouble <https://example.com/odouble>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Ŋeng <https://example.com/eng>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[Kelvin]") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[İstanbul]") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/kelvin>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/script>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/omega>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/angstrom>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/istanbul>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/dcaron>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/omicron-tonos>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/amacron>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/odouble>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/eng>") != null);
}

test "matches reference labels with ligature and extended special case folds" {
    const input =
        \\DZ fold: [ǆungla] should resolve.
        \\Ligature fold: [ffi] should resolve.
        \\Micro fold: [μ-label] should resolve.
        \\Kelvin control: [k-label] should still resolve.
        \\
        \\[ǅungla]: /dz-caron
        \\[ﬃ]: /ffi-ligature
        \\[µ-label]: /micro-sign
        \\[K-label]: /kelvin
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "ǆungla </dz-caron>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "ffi </ffi-ligature>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "μ-label </micro-sign>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "k-label </kelvin>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[ǆungla]") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[ffi]") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </dz-caron>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </ffi-ligature>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </micro-sign>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </kelvin>") != null);
}

test "limits reference labels to 999 bytes" {
    var label999: [999]u8 = undefined;
    var label1000: [1000]u8 = undefined;
    @memset(label999[0..], 'a');
    @memset(label1000[0..], 'b');

    const input = try std.fmt.allocPrint(
        std.testing.allocator,
        "Valid 999-char reference: [ok][{s}] should resolve.\n" ++
            "Invalid 1000-char reference: [too long][{s}] should stay unresolved.\n\n" ++
            "[{s}]: docs/ok.md\n\n" ++
            "[{s}]: docs/too-long.md\n",
        .{ label999[0..], label1000[0..], label999[0..], label1000[0..] },
    );
    defer std.testing.allocator.free(input);

    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "ok <docs/ok.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[too long][") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "too long <docs/too-long.md>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "docs/too-long.md") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/ok.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[too long][") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul too long") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "docs/too-long.md") != null);
}

test "resolves reference definitions inside blockquote and list containers" {
    const input =
        \\Blockquote-defined reference: [quote ref] should resolve.
        \\List-defined reference: [list ref] should resolve.
        \\First container definition wins: [precedence] should use the quote destination.
        \\Code-block definition stays inert: [code ref] should remain unresolved.
        \\
        \\> [quote ref]: docs/quote.md "hidden quote title"
        \\> Visible quote after hidden definition.
        \\
        \\- [list ref]: docs/list.md "hidden list title"
        \\- Visible list item after hidden definition.
        \\
        \\> [precedence]: docs/first.md
        \\> [precedence]: docs/second.md
        \\
        \\    [code ref]: docs/code.md
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "quote ref <docs/quote.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "list ref <docs/list.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "precedence <docs/first.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[code ref] should remain unresolved") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    [code ref]: docs/code.md") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[quote ref]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[list ref]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[precedence]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "docs/second.md") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "hidden quote title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "hidden list title") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/quote.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/list.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/first.md>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[code ref] should remain unresolved") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[quote ref]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[list ref]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[precedence]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "docs/second.md") == null);
}

test "resolves reference definitions with destination on the following line" {
    const input =
        \\[split]
        \\
        \\[split]:
        \\  /split-destination
        \\
        \\[split-title]
        \\
        \\[split-title]:
        \\  <https://example.com/a b>
        \\  "Hidden Title"
        \\
        \\[bad]
        \\
        \\[bad]:
        \\
        \\  /not-a-definition-after-blank
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "split </split-destination>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "split-title <https://example.com/a b>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[split]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hidden Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[bad]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[bad]:") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "not-a-definition-after-blank") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "bad </not-a-definition-after-blank>") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </split-destination>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/a b>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[split]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Hidden Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[bad]:") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </not-a-definition-after-blank>") == null);
}

test "hides reference definition titles on following lines without indentation" {
    const input =
        \\[plain-title]
        \\
        \\[plain-title]: /plain-target
        \\'Hidden plain title'
        \\
        \\[paren-title]
        \\
        \\[paren-title]: /paren-target
        \\(Paren Hidden Title)
        \\
        \\[not-title]
        \\
        \\[not-title]: /visible-target
        \\"title" ok
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "plain-title </plain-target>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "paren-title </paren-target>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "not-title </visible-target>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hidden plain title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paren Hidden Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\"title\" ok") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </plain-target>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </paren-target>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 </visible-target>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Hidden plain title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Paren Hidden Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\"title\" ok") != null);
}

test "keeps quoted paragraphs after complete same-line reference titles" {
    const input =
        \\Complete one-line definition: [inline-title] should resolve.
        \\"quoted paragraph after inline title must remain visible"
        \\
        \\Following-line title definition: [following-title] should resolve.
        \\
        \\[inline-title]: https://inline.example "Inline Title"
        \\"visible quoted paragraph after complete definition"
        \\
        \\[following-title]: https://following.example
        \\"Hidden Following Title"
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "inline-title <https://inline.example>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\"quoted paragraph after inline title must remain visible\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\"visible quoted paragraph after complete definition\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "following-title <https://following.example>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hidden Following Title") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://inline.example>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\"visible quoted paragraph after complete definition\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://following.example>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Hidden Following Title") == null);
}

test "keeps malformed following-line reference titles visible" {
    const input =
        \\Valid following title: [valid-title] should resolve.
        \\Invalid nested paren title: [paren-bad] should resolve.
        \\Invalid inner quote title: [quote-bad] should resolve.
        \\
        \\[valid-title]: https://valid.example
        \\"Hidden Valid Title"
        \\
        \\[paren-bad]: https://paren.example
        \\(Bad (Nested) Title)
        \\
        \\[quote-bad]: https://quote.example
        \\"Bad "Inner" Title"
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "valid-title <https://valid.example>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hidden Valid Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "paren-bad <https://paren.example>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "(Bad (Nested) Title)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "quote-bad <https://quote.example>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\"Bad \"Inner\" Title\"") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://valid.example>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Hidden Valid Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "(Bad (Nested) Title)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\"Bad \"Inner\" Title\"") != null);
}

test "resolves link reference definitions with multiline labels" {
    const input =
        \\Multiline reference should resolve: [foo].
        \\Broken candidate should stay visible: [broken].
        \\
        \\[
        \\foo
        \\]: https://example.com/multiline "Multiline Label Title"
        \\
        \\[
        \\broken
        \\] trailing text: https://example.com/broken
        \\
        \\After definitions **real bold** still renders.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Multiline reference should resolve: foo <https://example.com/multiline>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "]: https://example.com/multiline") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Multiline Label Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[ broken ] trailing text: https://example.com/broken") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After definitions real bold still renders.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul foo") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/multiline>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Multiline Label Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[ broken ] trailing text: https://example.com/broken") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After definitions \\b real bold\\b0") != null);
}

test "hides multiline label reference definitions with following-line destinations" {
    const input =
        \\Following-line destination should resolve: [split].
        \\
        \\[
        \\split
        \\]:
        \\  <https://example.com/split path>
        \\  'Hidden Split Title'
        \\
        \\After definition **real bold** renders.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Following-line destination should resolve: split <https://example.com/split path>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hidden Split Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "After definition real bold renders.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul split") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <https://example.com/split path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Hidden Split Title") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "After definition \\b real bold\\b0") != null);
}

test "does not let reference definitions interrupt paragraphs" {
    const input =
        \\Paragraph starts here
        \\[interrupt]: docs/interrupt.md
        \\
        \\[interrupt] should remain unresolved because the definition line was paragraph text.
        \\
        \\[real]: docs/real.md
        \\
        \\After a blank-separated definition, [real] should resolve.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph starts here [interrupt]: docs/interrupt.md") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[interrupt] should remain unresolved") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "interrupt <docs/interrupt.md>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[real]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "real <docs/real.md>") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Paragraph starts here [interrupt]: docs/interrupt.md") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[interrupt] should remain unresolved") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/interrupt.md>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[real]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf2 <docs/real.md>") != null);
}

test "ignores reference definitions inside inert blocks" {
    const input =
        \\Outside code should stay unresolved: [ghost][ghost].
        \\Outside comment should stay unresolved: [comment-ref][comment-ref].
        \\Outside cdata should stay unresolved: [cdata-ref][cdata-ref].
        \\Real reference should resolve: [real][real].
        \\
        \\```md
        \\[ghost]: https://evil.example/code
        \\```
        \\
        \\<!--
        \\[comment-ref]: https://evil.example/comment
        \\-->
        \\
        \\<![CDATA[
        \\[cdata-ref]: https://evil.example/cdata
        \\]]>
        \\
        \\[real]: https://example.com/real
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "[ghost][ghost]",
        "[comment-ref][comment-ref]",
        "[cdata-ref][cdata-ref]",
        "real <https://example.com/real>",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }
    try std.testing.expect(std.mem.indexOf(u8, rendered, "ghost <https://evil.example/code>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "comment-ref <https://evil.example/comment>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "cdata-ref <https://evil.example/cdata>") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "[ghost][ghost]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[comment-ref][comment-ref]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[cdata-ref][cdata-ref]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul real") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "https://evil.example/code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul ghost") == null);
}

test "ignores reference definitions inside container fenced code blocks" {
    const input =
        \\Before inert refs: [quote fence][quote-fence], [list fence][list-fence], [quoted list fence][quoted-list-fence].
        \\Real control: [real ref][real].
        \\
        \\> ```
        \\> [quote-fence]: https://example.com/quote-fence
        \\> **literal quote fence def**
        \\> ```
        \\
        \\- ```
        \\  [list-fence]: https://example.com/list-fence
        \\  **literal list fence def**
        \\  ```
        \\
        \\> - ~~~
        \\>   [quoted-list-fence]: https://example.com/quoted-list-fence
        \\>   **literal quoted list fence def**
        \\>   ~~~
        \\
        \\[real]: https://example.com/real
        \\
        \\After inert refs: [quote fence][quote-fence], [list fence][list-fence], [quoted list fence][quoted-list-fence].
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "[quote fence][quote-fence]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[list fence][list-fence]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[quoted list fence][quoted-list-fence]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "real ref <https://example.com/real>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[quote-fence]: https://example.com/quote-fence") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "quote fence <https://example.com/quote-fence>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "list fence <https://example.com/list-fence>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "quoted list fence <https://example.com/quoted-list-fence>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[real]: https://example.com/real") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "[quote fence][quote-fence]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[list fence][list-fence]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[quoted list fence][quoted-list-fence]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul real ref") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[quote-fence]: https://example.com/quote-fence") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul quote fence") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul list fence") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul quoted list fence") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[real]: https://example.com/real") == null);
}

test "ignores reference definitions inside container html blocks" {
    const input =
        \\Before inert html refs: [quote html][quote-html], [list html][list-html], [quoted list html][quoted-list-html].
        \\Real control: [real html ref][real-html].
        \\
        \\> <div>
        \\> [quote-html]: https://example.com/quote-html
        \\> **literal quote html def**
        \\> </div>
        \\>
        \\
        \\- <section>
        \\  [list-html]: https://example.com/list-html
        \\  **literal list html def**
        \\  </section>
        \\
        \\> - <article>
        \\>   [quoted-list-html]: https://example.com/quoted-list-html
        \\>   **literal quoted list html def**
        \\>   </article>
        \\>
        \\
        \\[real-html]: https://example.com/real-html
        \\
        \\After inert html refs: [quote html][quote-html], [list html][list-html], [quoted list html][quoted-list-html].
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "[quote html][quote-html]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[list html][list-html]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[quoted list html][quoted-list-html]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "real html ref <https://example.com/real-html>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[quote-html]: https://example.com/quote-html") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "quote html <https://example.com/quote-html>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "list html <https://example.com/list-html>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "quoted list html <https://example.com/quoted-list-html>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[real-html]: https://example.com/real-html") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "[quote html][quote-html]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[list html][list-html]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[quoted list html][quoted-list-html]") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul real html ref") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[quote-html]: https://example.com/quote-html") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul quote html") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul list html") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul quoted list html") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[real-html]: https://example.com/real-html") == null);
}

test "hides reference definition titles continued on the next line" {
    const input =
        \\Reference link: [continued title][ref-title]
        \\Reference image: ![continued image][img-title]
        \\
        \\[ref-title]: https://example.com/ref
        \\  "Reference Title On Next Line"
        \\[img-title]: assets/ref-image.png
        \\  'Image Title On Next Line'
        \\
        \\Paragraph after definitions should remain visible.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "continued title <https://example.com/ref>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: continued image] <assets/ref-image.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Reference Title On Next Line") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Image Title On Next Line") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph after definitions should remain visible.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul continued title") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: continued image] assets/ref-image.png") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Reference Title On Next Line") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Image Title On Next Line") == null);
}

test "renders reference labels containing escaped brackets" {
    const input =
        \\Explicit escaped reference: [escaped explicit][ref \] id] should resolve.
        \\Shortcut escaped reference: [ref \] id] should resolve too.
        \\Image escaped reference: ![escaped image][img \] id] should resolve.
        \\
        \\[ref \] id]: https://example.com/escaped-ref
        \\[img \] id]: assets/escaped-image.png
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "escaped explicit <https://example.com/escaped-ref>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "ref ] id <https://example.com/escaped-ref>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[image: escaped image] <assets/escaped-image.png>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[ref ] id]:") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[img ] id]:") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul escaped explicit") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul ref ] id") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[image: escaped image] assets/escaped-image.png") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[ref ] id]:") == null);
}

test "rejects reference definition labels containing unescaped nested brackets" {
    const input =
        \\Escaped label [a\]b] should resolve.
        \\Nested label [outer [inner]] should remain literal.
        \\
        \\[a\]b]: https://example.com/escaped
        \\[outer [inner]]: https://example.com/nested
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "a]b <https://example.com/escaped>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Nested label [outer [inner]] should remain literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[outer [inner]]: https://example.com/nested") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul a]b") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Nested label [outer [inner]] should remain literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "[outer [inner]]: https://example.com/nested") != null);
}

test "decodes common named html entities" {
    const input =
        \\Named entities: A&nbsp;B &copy; 2026 &reg; &trade; dash&mdash;trail ellipsis&hellip;
        \\Math-ish: 2 &le; 3 &ge; 1 &ne; 0, arrows &larr; &rarr; &harr;
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "&nbsp;",
        "&copy;",
        "&reg;",
        "&trade;",
        "&mdash;",
        "&hellip;",
        "&le;",
        "&ge;",
        "&ne;",
        "&larr;",
        "&rarr;",
        "&harr;",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) == null);
    }
    try std.testing.expect(std.mem.indexOf(u8, rendered, "© 2026") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "® ™") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "dash—trail") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "ellipsis…") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "2 ≤ 3 ≥ 1 ≠ 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "arrows ← → ↔") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "A\\u160?B \\u169? 2026 \\u174? \\u8482?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "dash\\u8212?trail ellipsis\\u8230?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "2 \\u8804? 3 \\u8805? 1 \\u8800? 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "arrows \\u8592? \\u8594? \\u8596?") != null);
}

test "decodes common Latin-1 named html entities" {
    const input =
        \\Legal-ish: &sect; 1 &para; 2, &copy; kept, &reg; kept.
        \\Math-ish: &plusmn; 3, &sup1; &sup2; &sup3;, &frac12; &frac14;.
        \\Currency: &cent; &pound; &yen; &euro;.
        \\Typography: &middot; &bull; &dagger; &Dagger;.
        \\Link destination: [money](docs?currency=&pound;&yen;&cent;).
        \\Code literal: `&sect; &frac12;` should stay literal.
        \\Unknown literal: &NotInTinyCatalog; should stay literal.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Legal-ish: § 1 ¶ 2, © kept, ® kept.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Math-ish: ± 3, ¹ ² ³, ½ ¼.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Currency: ¢ £ ¥ €.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Typography: · • † ‡.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "money <docs?currency=£¥¢>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code literal: &sect; &frac12; should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&NotInTinyCatalog;") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&sect; 1") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&pound;&yen;&cent;") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u167? 1 \\u182? 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u177? 3, \\u185? \\u178? \\u179?, \\u189? \\u188?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u162? \\u163? \\u165? \\u8364?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u183? \\u8226? \\u8224? \\u8225?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "docs?currency=\\u163?\\u165?\\u162?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&sect; &frac12;") != null);
}

test "decodes common Greek and math named html entities" {
    const input =
        \\Greek lower: &alpha; &beta; &gamma; &pi; &omega;.
        \\Greek upper: &Gamma; &Delta; &Theta; &Lambda; &Omega;.
        \\Math operators: &sum; &prod; &int; &radic; &infin; &approx; &equiv;.
        \\Logic/set: &forall; &exist; &nabla; &part; &empty; &isin; &notin;.
        \\Link destination: [math](docs?symbol=&alpha;&sum;&infin;).
        \\Code literal: `&alpha; &sum;` should stay literal.
        \\Unknown literal: &NoSuchMathEntity; should stay literal.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Greek lower: α β γ π ω.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Greek upper: Γ Δ Θ Λ Ω.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Math operators: ∑ ∏ ∫ √ ∞ ≈ ≡.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Logic/set: ∀ ∃ ∇ ∂ ∅ ∈ ∉.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "math <docs?symbol=α∑∞>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code literal: &alpha; &sum; should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&NoSuchMathEntity;") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&alpha; &beta;") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&alpha;&sum;&infin;") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u945? \\u946? \\u947? \\u960? \\u969?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u915? \\u916? \\u920? \\u923? \\u937?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u8721? \\u8719? \\u8747? \\u8730? \\u8734? \\u8776? \\u8801?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u8704? \\u8707? \\u8711? \\u8706? \\u8709? \\u8712? \\u8713?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "docs?symbol=\\u945?\\u8721?\\u8734?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&alpha; &sum;") != null);
}

test "decodes CommonMark named character reference examples" {
    const input =
        \\Spec sample entities: &nbsp; &amp; &copy; &AElig; &Dcaron;
        \\Spec math entities: &frac34; &HilbertSpace; &DifferentialD; &ClockwiseContourIntegral; &ngE;
        \\URL/title entity example: [umlaut](/f&ouml;&ouml; "f&ouml;&ouml;").
        \\Code literal entity: `&AElig;` should stay raw.
        \\Invalid entity: &DefinitelyNotAnEntity; should stay literal.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Spec sample entities: \u{00a0} & © Æ Ď") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Spec math entities: ¾ ℋ ⅆ ∲ ≧̸") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "umlaut </föö>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code literal entity: &AElig; should stay raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Invalid entity: &DefinitelyNotAnEntity; should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Spec sample entities: \u{00a0} & © &AElig;") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Spec math entities: &frac34;") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u160? & \\u169? \\u198? \\u270?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u190? \\u8459? \\u8518? \\u8754? \\u8807?\\u824?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "/f\\u246?\\u246?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&AElig;") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Invalid entity: &DefinitelyNotAnEntity;") != null);
}

test "decodes broader CommonMark named character references" {
    const input =
        \\Core controls: &quot;quoted&quot; &apos;single&apos; &lt;tag&gt; &amp; amp.
        \\Math names: &NotGreaterLess; &NotEqualTilde; &CounterClockwiseContourIntegral; &DoubleLongLeftRightArrow;.
        \\Diacritics/symbols: &DiacriticalGrave; &Hacek; &VerticalSeparator; &UnderBar;.
        \\Invalid controls: &notanentity; &copycat; &ampwithoutsemicolon should stay literal-ish.
        \\Code inert: `&NotGreaterLess;` should stay raw in code.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Core controls: \"quoted\" 'single' <tag> & amp.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Math names: ≹ ≂̸ ∳ ⟺.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Diacritics/symbols: ` ˇ ❘ _.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&notanentity;") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&copycat;") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&ampwithoutsemicolon") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code inert: &NotGreaterLess; should stay raw in code.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&NotGreaterLess; &NotEqualTilde;") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Core controls: \"quoted\" 'single' <tag> & amp.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u8825? \\u8770?\\u824? \\u8755? \\u10234?.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "` \\u711? \\u10072? _.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&notanentity;") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&copycat;") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&ampwithoutsemicolon") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&NotGreaterLess;") != null);
}

test "decodes selected rare named character references" {
    const input =
        \\Rare math entities: &NotSubsetEqual; &nsube; &LeftArrowBar; &DownBreve;.
        \\Rare ligature/entity names: &fjlig; &angmsd; should decode, while &notarealentity; stays literal.
        \\Destination entity: [entity dest](https://example.com/?q=&NotSubsetEqual;&fjlig;) should expose decoded URL.
        \\Code span inert: `&NotSubsetEqual; &fjlig;` stays literal.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Rare math entities: ⊈ ⊈ ⇤ ̑.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Rare ligature/entity names: fj ∡ should decode") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&notarealentity; stays literal") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "entity dest <https://example.com/?q=⊈fj>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code span inert: &NotSubsetEqual; &fjlig; stays literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&NotSubsetEqual; &nsube;") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u8840? \\u8840? \\u8676? \\u785?.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "fj \\u8737? should decode") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "https://example.com/?q=\\u8840?fj") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&NotSubsetEqual; &fjlig;") != null);
}

test "decodes selected HTML5 named entity cluster" {
    const input =
        \\Symbols: &mapsto; &there4; &NotLessLess; &nGg; &acE; &NotNestedGreaterGreater; &TildeFullEqual; &RightTeeArrow; &NotRightTriangleBar; &nvlt;.
        \\Inside link: [entity href](https://example.com/?a=&mapsto;&b=&there4;).
        \\Code inert: `&mapsto; &there4;` stays raw.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Symbols: ↦ ∴ ≪̸ ⋙̸ ∾̳ ⪢̸ ≅ ↦ ⧐̸ <⃒.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Inside link: entity href <https://example.com/?a=↦&b=∴>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code inert: &mapsto; &there4; stays raw.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&NotLessLess;") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u8614? \\u8756? \\u8810?\\u824? \\u8921?\\u824? \\u8766?\\u819? \\u10914?\\u824? \\u8773? \\u8614? \\u10704?\\u824? <\\u8402?.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "https://example.com/?a=\\u8614?&b=\\u8756?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&mapsto; &there4;") != null);
}

test "decodes common typography and symbol named html entities" {
    const input =
        \\Typography: &ldquo;smart&rdquo; quote, rock&rsquo;n&rsquo;roll, &laquo;angle&raquo;.
        \\Math and symbols: 2 &times; 3 &divide; 1, &micro; service, 10&deg;C, price &euro;5.
        \\Destination entity: [entity dest](/docs/&micro;&times; "hidden title").
        \\Unknown stays literal: &NotARealCommonEntity;.
        \\Code stays raw: `&ldquo; &times;`.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Typography: “smart” quote, rock’n’roll, «angle».") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Math and symbols: 2 × 3 ÷ 1, µ service, 10°C, price €5.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Destination entity: entity dest </docs/µ×>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Unknown stays literal: &NotARealCommonEntity;.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code stays raw: &ldquo; &times;.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u8220?smart\\u8221?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "rock\\u8217?n\\u8217?roll") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u171?angle\\u187?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "2 \\u215? 3 \\u247? 1, \\u181? service, 10\\u176?C, price \\u8364?5") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "/docs/\\u181?\\u215?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&NotARealCommonEntity;") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&ldquo; &times;") != null);
}

test "decodes numeric entities and replaces invalid codepoints" {
    const input =
        \\Valid rockets: &#x1F680; and &#128640; should both render as rockets.
        \\Invalid numeric refs: &#0; and &#xD800; and &#x110000; should render replacement characters.
        \\Overflow numeric refs: &#9999999; and &#xFFFFFF; should also render replacement characters.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Valid rockets: 🚀 and 🚀") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Invalid numeric refs: � and � and �") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Overflow numeric refs: � and �") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&#0;") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&#xD800;") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&#x110000;") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&#9999999;") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "&#xFFFFFF;") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Valid rockets: 🚀 and 🚀") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Invalid numeric refs: \\'ef\\'bf\\'bd and \\'ef\\'bf\\'bd and \\'ef\\'bf\\'bd") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Overflow numeric refs: \\'ef\\'bf\\'bd and \\'ef\\'bf\\'bd") != null);
}

test "remaps HTML5 C1 numeric character references" {
    const input =
        \\C1 remap text: euro &#x80;, quote &#x82;, ellipsis &#x85;, trade &#x99;.
        \\C1 remap link: [currency](docs?price=&#x80;99&tm=&#153;).
        \\Code span literal: `&#x80; &#153;` should stay literal.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "C1 remap text: euro €, quote ‚, ellipsis …, trade ™.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "currency <docs?price=€99&tm=™>") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code span literal: &#x80; &#153; should stay literal.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\xc2\x80") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\xc2\x99") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "euro \\u8364?, quote \\u8218?, ellipsis \\u8230?, trade \\u8482?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "docs?price=\\u8364?99&tm=\\u8482?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&#x80; &#153;") != null);
}

test "preserves numeric character references outside CommonMark digit limits" {
    const input =
        \\Valid decimal refs: &#35; &#1234; &#992; &#0;
        \\Valid hex refs: &#X22; &#XD06; &#xcab;
        \\Too-long numeric refs stay literal: &#87654321; and &#xabcdef0; and &#00000001;.
        \\Malformed numeric refs stay literal: &#; and &#x; and &hi?;.
        \\Code literal numeric: `&#35;` should stay raw.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Valid decimal refs: # Ӓ Ϡ �") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Valid hex refs: \" ആ ಫ") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Too-long numeric refs stay literal: &#87654321; and &#xabcdef0; and &#00000001;.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Malformed numeric refs stay literal: &#; and &#x; and &hi?;.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code literal numeric: &#35; should stay raw.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Valid decimal refs: # \\u1234? \\u992? \\'ef\\'bf\\'bd") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Valid hex refs: \" \\u3334? \\u3243?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Too-long numeric refs stay literal: &#87654321; and &#xabcdef0; and &#00000001;.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Malformed numeric refs stay literal: &#; and &#x; and &hi?;.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "&#35;") != null);
}

test "escapes raw unicode text as rtf unicode units" {
    const input =
        \\Korean: 한글 문서 뷰어 테스트
        \\CJK: 漢字かなカナ
        \\Emoji and symbols: 🚀 ✅ Ω ≈ 𝄞
        \\Mixed inline: **굵은 한글** and `코드 한글` and [링크](https://example.com/한글)
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "한글 문서 뷰어 테스트") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "漢字かなカナ") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "🚀 ✅ Ω ≈ 𝄞") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "링크 <https://example.com/한글>") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u-10916?\\u-20992?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u28450?\\u23383?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "🚀") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u9989?") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "𝄞") != null);
}

test "preserves literal inline delimiters and intraword underscores" {
    const input =
        \\Literal identifiers: snake_case, foo_bar_baz, path_with_many_parts.
        \\Intraword stars: a*b*c should render without marker leakage.
        \\Valid emphasis: *italic star*, _italic underscore_, **bold star**, __bold underscore__.
        \\Unmatched markers: *literal star, _literal underscore, `literal tick, ~~literal strike.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "snake_case",
        "foo_bar_baz",
        "path_with_many_parts",
        "Intraword stars: abc should render without marker leakage.",
        "italic star",
        "italic underscore",
        "bold star",
        "bold underscore",
        "*literal star",
        "_literal underscore",
        "`literal tick",
        "~~literal strike",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "snake_case") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "foo_bar_baz") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "a\\i b\\i0 c") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\i italic star\\i0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\i italic underscore\\i0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b bold star\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b bold underscore\\b0") != null);
}

test "preserves unicode intraword underscores" {
    const input =
        \\Korean intraword: 한_글_테스트 should keep underscores.
        \\CJK strong intraword: 漢__字__かな should keep underscores.
        \\Separated emphasis: 한글 _기울임_ 테스트 should render emphasis.
        \\ASCII control: snake_case and foo__bar__baz still literal.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "한_글_테스트",
        "漢__字__かな",
        "한글 기울임 테스트",
        "snake_case",
        "foo__bar__baz",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "_\\u-20992?_") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u28450?__\\u23383?__") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\i \\u-20944?\\u-14664?\\u-14460?\\i0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "foo__bar__baz") != null);
}

test "renders intraword asterisk emphasis while preserving intraword underscores" {
    const input =
        \\Intraword star emphasis: foo*bar*baz should render bar without marker leakage.
        \\Intraword star strong: foo**bar**baz should render bar without marker leakage.
        \\Intraword triple star: abc***def***ghi should render def without marker leakage.
        \\Intraword underscores stay literal: foo_bar_baz and foo__bar__baz should stay unchanged.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Intraword star emphasis: foobarbaz should render bar without marker leakage.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Intraword star strong: foobarbaz should render bar without marker leakage.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Intraword triple star: abcdefghi should render def without marker leakage.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Intraword underscores stay literal: foo_bar_baz and foo__bar__baz should stay unchanged.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "foo*bar*baz") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "foo**bar**baz") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "abc***def***ghi") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "foo\\i bar\\i0 baz") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "foo\\b bar\\b0 baz") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "abc\\b\\i def\\i0\\b0 ghi") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "foo_bar_baz and foo__bar__baz") != null);
}

test "preserves strikethrough delimiter boundary literals" {
    const input =
        \\Valid strike: ~~deleted text~~ should render.
        \\ASCII intraword: abc~~def~~ghi should keep tildes.
        \\Unicode intraword: 한~~글~~테스트 should keep tildes.
        \\Unmatched: ~~starts only should keep markers.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "Valid strike: deleted text should render.",
        "abc~~def~~ghi",
        "한~~글~~테스트",
        "~~starts only should keep markers.",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }

    try std.testing.expect(std.mem.indexOf(u8, rendered, "~~deleted text~~") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "abcdefghi") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "한글테스트") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\strike deleted text\\strike0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "abc~~def~~ghi") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "~~starts only should keep markers") != null);
}

test "renders triple emphasis and nested strong italic without delimiter leakage" {
    const input =
        \\Triple stars: ***bold italic stars*** should not leave literal marker characters.
        \\Triple underscores: ___bold italic underscores___ should not leave literal marker characters.
        \\Nested mixed: **bold with *inner italic*** should render without marker leakage.
        \\Intraword triple stars: abc***def***ghi should render without marker leakage.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Triple stars: bold italic stars should not leave literal marker characters.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Triple underscores: bold italic underscores should not leave literal marker characters.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Nested mixed: bold with inner italic should render without marker leakage.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Intraword triple stars: abcdefghi should render without marker leakage.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "*bold italic stars") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "_bold italic underscores") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "abc***def***ghi") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\i bold italic stars\\i0\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b\\i bold italic underscores\\i0\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b bold with \\i inner italic\\i0 \\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "abc\\b\\i def\\i0\\b0 ghi") != null);
}

test "renders multi-backtick code spans as a single literal span" {
    const input =
        \\Single span: `plain **not bold** code` stays literal.
        \\Double span: ``literal ` tick and **not bold** inside`` should keep raw markers.
        \\Triple span: ```two `` ticks and [not link](x)``` should stay one code span.
        \\Unclosed span: `literal unclosed marker should stay readable.
        \\
        \\Unmatched double run: ``no matching closer ` should keep both opening ticks and the trailing tick.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "plain **not bold** code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "literal ` tick and **not bold** inside") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "two `` ticks and [not link](x)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "not link <x>") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "`literal unclosed marker") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "``no matching closer `") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\highlight4 plain **not bold** code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\highlight4 literal ` tick and **not bold** inside") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\highlight4 two `` ticks and [not link](x)") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul not link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "``no matching closer `") != null);
}

test "normalizes code span line endings to spaces" {
    const input =
        "Inline hard-break code span: `foo  \n" ++
        "bar` should show one code span.\n\n" ++
        "Inline soft-break code span: `alpha\n" ++
        "beta` should normalize too.\n\n" ++
        "Only spaces stay spaces: `   ` end.";

    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Inline hard-break code span: foo   bar should show one code span.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "foo\nbar") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Inline soft-break code span: alpha beta should normalize too.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Only spaces stay spaces:     end.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "foo   bar") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "alpha beta") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "foo\\line bar") == null);
}

test "preserves trailing spaces inside multiline code spans" {
    const input =
        "Code span with trailing backslash line: ``alpha\\\n" ++
        "beta`` after text.\n\n" ++
        "Code span with two trailing spaces line: ``gamma  \n" ++
        "delta`` after text.\n\n" ++
        "Normal paragraph hard break for control\\\n" ++
        "next line should break.";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code span with trailing backslash line: alpha\\ beta after text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Code span with two trailing spaces line: gamma   delta after text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Normal paragraph hard break for control\nnext line should break.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "gamma delta") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "alpha\\\\ beta") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "gamma   delta") != null);
}

test "honors hard breaks after multiline code spans close" {
    const input =
        "Closing line with trailing two spaces: ``alpha\n" ++
        "beta``  \n" ++
        "next line should break.\n\n" ++
        "Closing line with trailing backslash: ``gamma\n" ++
        "delta``\\\n" ++
        "next line should also break.\n\n" ++
        "Open middle line keeps spaces: ``theta  \n" ++
        "iota`` after text.";

    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Closing line with trailing two spaces: alpha beta\nnext line should break.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Closing line with trailing backslash: gamma delta\nnext line should also break.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Open middle line keeps spaces: theta   iota after text.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "alpha beta   next line") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "gamma delta\\ next line") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Closing line with trailing two spaces: ") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "alpha beta\\highlight0\\f0\\fs22 \\line next line should break.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "gamma delta\\highlight0\\f0\\fs22 \\line next line should also break.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "theta   iota") != null);
}

test "honors hard breaks after multiline code spans close in containers" {
    const input =
        "> Quote closing: ``alpha\n" ++
        "> beta``  \n" ++
        "> next quote line.\n\n" ++
        "- List closing: ``gamma\n" ++
        "  delta``\\\n" ++
        "  next list line.\n\n" ++
        "> - Quote-list closing: ``theta\n" ++
        ">   iota``  \n" ++
        ">   next nested line.";

    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| Quote closing: alpha beta\nnext quote line.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* List closing: gamma delta\nnext list line.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * Quote-list closing: theta iota\nnext nested line.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "alpha beta   next quote") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "gamma delta\\ next list") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "alpha beta\\highlight0\\f0\\fs22 \\line next quote line.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "gamma delta\\highlight0\\f0\\fs22 \\line next list line.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "theta iota\\highlight0\\f0\\fs22 \\line next nested line.") != null);
}

test "tracks long backtick code span delimiters exactly" {
    const long = "````````````````";
    const short = "```````````````";
    const longer = "`````````````````";
    const input =
        "Long run code span with shorter literal run and spaces: " ++ long ++ "alpha\n" ++
        "middle " ++ short ++ " keeps two spaces  \n" ++
        "omega" ++ long ++ " after text.\n\n" ++
        "Long run code span with longer literal run: " ++ long ++ "start\n" ++
        "middle " ++ longer ++ " stays literal inside\n" ++
        "end" ++ long ++ " after text.\n\n" ++
        "Simple long run code span: " ++ long ++ "short" ++ long ++ " done.";

    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "alpha middle " ++ short ++ " keeps two spaces   omega") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "start middle " ++ longer ++ " stays literal inside end") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Simple long run code span: short done.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "keeps two spaces omega") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "alpha middle " ++ short ++ " keeps two spaces   omega") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "start middle " ++ longer ++ " stays literal inside end") != null);
}

test "trims code span boundary spaces after line-ending conversion" {
    const input =
        "Boundary hard-break span: `  \n" ++
        "edge  \n" ++
        "` should render as edge.\n\n" ++
        "Tab counts as non-space: ` \t ` should trim surrounding spaces.";

    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "  edge  ") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Boundary hard-break span: edge should render as edge.") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Tab counts as non-space: \t should trim surrounding spaces.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Tab counts as non-space:  \t  should") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Boundary hard-break span: ") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "edge") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "  edge  ") != null);
}

test "keeps whitespace-only multiline code spans inside the paragraph" {
    const input =
        "Blank hard-break span: `  \n" ++
        "  ` should hide source markers and leave a blank inline code span.";

    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Blank hard-break span: `") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "` should hide source markers") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "should hide source markers and leave a blank inline code span.") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Blank hard-break span: `") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "` should hide source markers") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "should hide source markers and leave a blank inline code span.") != null);
}

test "coalesces soft paragraph lines and keeps hard line breaks" {
    const input =
        "Soft line one\n" ++
        "soft line two should be same paragraph.\n\n" ++
        "Hard break by two spaces  \n" ++
        "next visual line should stay in same paragraph.\n\n" ++
        "Hard break by backslash\\\n" ++
        "next visual line should also stay in same paragraph.\n\n" ++
        "- list item\n" ++
        "  continuation should remain list continuation.";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Soft line one soft line two should be same paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hard break by two spaces\nnext visual line should stay in same paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hard break by backslash\nnext visual line should also stay in same paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* list item continuation should remain list continuation.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "backslash\\\n") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Soft line one soft line two should be same paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Hard break by two spaces\\line next visual line should stay in same paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Hard break by backslash\\line next visual line should also stay in same paragraph.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab list item continuation should remain list continuation.") != null);
}

test "handles trailing backslash hard break edge cases" {
    const input =
        "Single trailing backslash should hard break\\\n" ++
        "next line after single.\n\n" ++
        "Double trailing backslash keeps one visible without hard break\\\\\n" ++
        "next line after double.\n\n" ++
        "Backslash before spaces keeps visible slash while spaces hard break\\   \n" ++
        "next line after spaces.";
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Single trailing backslash should hard break\nnext line after single.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Double trailing backslash keeps one visible without hard break\\ next line after double.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Backslash before spaces keeps visible slash while spaces hard break\\\nnext line after spaces.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "without hard break\\\\") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "Single trailing backslash should hard break\\line next line after single.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Double trailing backslash keeps one visible without hard break\\\\ next line after double.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "Backslash before spaces keeps visible slash while spaces hard break" ++ "\\\\" ++ "\\line next line after spaces.") != null);
}

test "hides trailing backslash hard break markers inside containers" {
    const input =
        \\- list hard break\
        \\  second list line
        \\> quote hard break\
        \\> second quote line
        \\- [ ] task hard break\
        \\  second task line
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "* list hard break\nsecond list line") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| quote hard break\nsecond quote line") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* [ ] task hard break\nsecond task line") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "list hard break\\\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "quote hard break\\\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "task hard break\\\n") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "list hard break\\\\") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "quote hard break\\\\") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "task hard break\\\\") == null);
}

test "renders inline spans across container soft line continuations" {
    const input =
        \\Paragraph **strong
        \\across soft line** should render strong.
        \\
        \\- List **strong
        \\  across soft line** should render strong too.
        \\
        \\> Quote *emphasis
        \\> across soft line* should render emphasis too.
        \\
        \\- List `code
        \\  span` should normalize inside code too.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph strong across soft line should render strong.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* List strong across soft line should render strong too.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| Quote emphasis across soft line should render emphasis too.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* List code span should normalize inside code too.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**strong") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "*emphasis") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "`code") == null);
}

test "preserves trailing backslash inside multiline code spans" {
    const input =
        \\Paragraph `code before newline\
        \\still code` should keep the slash.
        \\
        \\- List `code before newline\
        \\  still code` should keep the slash too.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Paragraph code before newline\\ still code should keep the slash.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* List code before newline\\ still code should keep the slash too.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "code before newline still code") == null);
}

test "keeps task item hard breaks when inline spans cross lines" {
    const input =
        \\- [ ] Task **strong across hard break\
        \\  still strong** should keep checkbox and line break.
        \\
        \\- [x] Done task `code across newline\
        \\  still code` should keep literal slash inside code.
    ;
    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u9744?\\tab Task \\b strong across hard break\\line still strong\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\u9745?\\tab Done task \\f1\\fs20\\highlight4 code across newline\\\\ still code") != null);
}

test "renders inline spans across quoted list continuations" {
    const input =
        \\> - Quoted list **strong
        \\>   across soft line** should render strong.
        \\>
        \\> 1. Quoted ordered `code
        \\>    span` should normalize code.
        \\>
        \\> - Quoted list *emphasis across hard break\
        \\>   still emphasis* should keep visual break.
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * Quoted list strong across soft line should render strong.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| 1. Quoted ordered code span should normalize code.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * Quoted list emphasis across hard break\nstill emphasis should keep visual break.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "**strong") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "`code") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "*emphasis") == null);
}

test "renders multiline link and image labels across container continuations" {
    const input =
        \\- List [link
        \\  label](https://example.com) should render as a link.
        \\
        \\> Quote [ref
        \\> label][multi ref] should resolve reference link.
        \\
        \\> ![image
        \\> alt](img.png) should render image alt across line.
        \\
        \\[multi ref]: https://example.org
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "* List link label <https://example.com> should render as a link.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| Quote ref label <https://example.org> should resolve reference link.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| [image: image alt] <img.png> should render image alt across line.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "[link") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "![image") == null);
}

test "renders blockquote and list continuation indentation" {
    const input =
        \\> quoted first line
        \\> - quoted list item
        \\>   continuation inside quoted list
        \\
        \\- parent item
        \\  continuation paragraph
        \\  - nested bullet
        \\    nested continuation
        \\
        \\- parent before nested quote
        \\
        \\  > quoted **bold** line
        \\  > [quoted link](https://example.com/quoted)
        \\
        \\  after nested quote **bold** paragraph
        \\
        \\1. ordered parent
        \\   ordered continuation
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "| quoted first line",
        "| * quoted list item continuation inside quoted list",
        "* parent item continuation paragraph",
        "  * nested bullet nested continuation",
        "* parent before nested quote",
        "  | quoted bold line",
        "  | quoted link <https://example.com/quoted>",
        "  after nested quote bold paragraph",
        "1. ordered parent ordered continuation",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab quoted list item") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "continuation inside quoted list") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab quoted list item continuation inside quoted list") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "quoted \\b bold\\b0  line") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul quoted link") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "after nested quote \\b bold\\b0") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li720\\sa60") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab nested bullet nested continuation") != null);
}

test "renders independent three-space list markers at top level" {
    const input =
        \\Three-space bullet after blank:
        \\
        \\   - top-level bullet despite leading spaces
        \\
        \\Three-space ordered after blank:
        \\
        \\   1. top-level ordered despite leading spaces
        \\
        \\Four-space markers stay code:
        \\
        \\    - four-space bullet is code
        \\    1. four-space ordered is code
        \\
        \\Nested child still indents:
        \\
        \\- parent
        \\  - child
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "* top-level bullet despite leading spaces") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  * top-level bullet despite leading spaces") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "1. top-level ordered despite leading spaces") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  1. top-level ordered despite leading spaces") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    - four-space bullet is code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    1. four-space ordered is code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* parent\n  * child") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li480\\fi-240\\tx600\\sa70\\f0\\fs22\\cf1 \\bullet\\tab top-level bullet despite leading spaces") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li520\\fi-300\\tx640\\sa70\\f0\\fs22\\cf1 1.\\tab top-level ordered despite leading spaces") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 - four-space bullet is code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li840\\fi-240\\tx960\\sa70\\f0\\fs22\\cf1 \\bullet\\tab child") != null);
}

test "renders tab-indented list marker boundaries by CommonMark tab stops" {
    const input =
        "Three spaces before bullet:\n\n" ++
        "   - three-space bullet\n\n" ++
        "Tab before bullet is indented code:\n\n" ++
        "\t- tab bullet literal code\n\n" ++
        "Space plus tab before bullet is indented code:\n\n" ++
        " \t- space-tab bullet literal code\n\n" ++
        "- parent item\n" ++
        "\t- tab child item\n";

    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "* three-space bullet") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    - tab bullet literal code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    - space-tab bullet literal code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* parent item\n  * tab child item") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* parent item\n    * tab child item") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 - tab bullet literal code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2 - space-tab bullet literal code") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li840\\fi-240\\tx960\\sa70\\f0\\fs22\\cf1 \\bullet\\tab tab child item") != null);
}

test "renders blockquote lazy paragraph continuations" {
    const input =
        \\> quoted paragraph first
        \\lazy continuation should stay in quote
        \\> quoted paragraph after lazy
        \\
        \\> quoted list item
        \\- this unquoted list starts outside quote
        \\
        \\> quoted paragraph before thematic
        \\---
        \\> quoted paragraph after rule
        \\
        \\> quoted paragraph before indented lazy
        \\    - indented lazy line should stay paragraph text in quote
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "| quoted paragraph first lazy continuation should stay in quote quoted paragraph after lazy",
        "| quoted list item",
        "* this unquoted list starts outside quote",
        "| quoted paragraph before thematic",
        "---",
        "| quoted paragraph after rule",
        "| quoted paragraph before indented lazy",
        "| - indented lazy line should stay paragraph text in quote",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\nlazy continuation should stay in quote") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| * this unquoted list starts outside quote") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| ---") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    - indented lazy line") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "quoted paragraph first lazy continuation should stay in quote quoted paragraph after lazy") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li360\\ri240\\sb60\\sa100\\i\\cf2 - indented lazy line should stay paragraph text in quote") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li360\\ri240\\sb60\\sa100\\i\\cf2 \\bullet\\tab this unquoted list") == null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "------------------------------") != null);
}

test "renders list item lazy paragraph continuations" {
    const input =
        \\1. ordered item first line
        \\ordered lazy continuation should stay in list item
        \\
        \\- bullet item first line
        \\bullet lazy continuation should stay in list item
        \\
        \\- bullet before outside list
        \\- new bullet remains a separate item
        \\
        \\1. ordered before thematic
        \\---
        \\2. ordered after thematic starts new list item
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "1. ordered item first line ordered lazy continuation should stay in list item",
        "* bullet item first line bullet lazy continuation should stay in list item",
        "* bullet before outside list",
        "* new bullet remains a separate item",
        "1. ordered before thematic",
        "---",
        "2. ordered after thematic starts new list item",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\nordered lazy continuation should stay in list item") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\nbullet lazy continuation should stay in list item") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  new bullet remains a separate item") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  ---") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "ordered item first line ordered lazy continuation should stay in list item") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab bullet item first line bullet lazy continuation should stay in list item") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab new bullet remains a separate item") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "------------------------------") != null);
}

test "renders nested blockquotes without leaking raw markers" {
    const input =
        \\> outer first line
        \\>> inner compact quote with **bold inner**
        \\> > inner spaced quote with `code`
        \\> > - nested quoted bullet
        \\> >   nested quoted continuation
        \\> back to outer quote
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    for ([_][]const u8{
        "| outer first line",
        "| | inner compact quote with bold inner inner spaced quote with code",
        "| | * nested quoted bullet nested quoted continuation",
        "| back to outer quote",
    }) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, needle) != null);
    }
    try std.testing.expect(std.mem.indexOf(u8, rendered, "| >") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li720\\ri240\\sb60\\sa100\\i\\cf2 inner compact quote") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "inner spaced quote") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li720\\ri240\\sb60\\sa100\\i\\cf2 \\bullet\\tab nested quoted bullet") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab nested quoted bullet nested quoted continuation") != null);
}

test "renders top-level indented code blocks as code without stealing list continuations" {
    const input =
        \\Paragraph before code.
        \\
        \\    const value = 42;
        \\    if (value > 0) {
        \\        print("ok");
        \\    }
        \\
        \\- parent list item
        \\  continuation remains list text
        \\  - nested item remains list item
        \\    nested continuation remains list text
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "    const value = 42;") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "        print(\"ok\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "* parent list item continuation remains list text") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  * nested item remains list item nested continuation remains list text") != null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li360\\ri240\\sa0\\f1\\fs20\\cf2 const value = 42;") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab parent list item continuation remains list text") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\pard\\li840\\fi-240\\tx960\\sa70\\f0\\fs22\\cf1 \\bullet\\tab nested item remains list item") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\bullet\\tab nested item remains list item nested continuation remains list text") != null);
}

test "keeps indented code inert inside loose list items" {
    const input =
        \\- list item before code
        \\
        \\        code inside list **not bold**
        \\    paragraph continuation in list with [link](https://example.test/list).
    ;
    const rendered = try render(std.testing.allocator, input);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "        code inside list **not bold**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "    paragraph continuation in list with link <https://example.test/list>.") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "        code inside list not bold") == null);

    const rtf = try renderRtf(std.testing.allocator, input);
    defer std.testing.allocator.free(rtf);

    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\f1\\fs20\\cf2   code inside list **not bold**") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\cf3\\ul link\\ulnone") != null);
    try std.testing.expect(std.mem.indexOf(u8, rtf, "\\b not bold\\b0") == null);
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
