const std = @import("std");
const Io = std.Io;
const zmd = @import("zmd");

const max_image_file_bytes = 16 * 1024 * 1024;
const max_total_image_bytes = 32 * 1024 * 1024;
const max_image_dimension = 100_000;

pub const LoadedImages = struct {
    items: []zmd.RtfImage,
    allocations: [][]u8,

    pub fn deinit(self: *LoadedImages, allocator: std.mem.Allocator) void {
        for (self.allocations) |allocation| allocator.free(allocation);
        allocator.free(self.allocations);
        allocator.free(self.items);
        self.* = undefined;
    }
};

pub fn loadLocalRtfImages(
    allocator: std.mem.Allocator,
    io: Io,
    document_path: []const u8,
    sources: []const []const u8,
) !LoadedImages {
    var images: std.ArrayList(zmd.RtfImage) = .empty;
    errdefer images.deinit(allocator);
    var allocations: std.ArrayList([]u8) = .empty;
    errdefer {
        for (allocations.items) |allocation| allocator.free(allocation);
        allocations.deinit(allocator);
    }

    var total_bytes: usize = 0;
    for (sources) |source| {
        const path_source = localPathSource(source) orelse continue;
        const decoded_path = try percentDecodePath(allocator, path_source) orelse continue;
        defer allocator.free(decoded_path);

        const image_path = try resolveImagePath(allocator, document_path, decoded_path);
        defer allocator.free(image_path);

        const bytes = readImageFile(allocator, io, image_path) catch continue;
        const info = inspectImage(bytes) orelse {
            allocator.free(bytes);
            continue;
        };
        if (total_bytes + bytes.len > max_total_image_bytes) {
            allocator.free(bytes);
            continue;
        }

        try allocations.append(allocator, bytes);
        try images.append(allocator, .{
            .source = source,
            .data = info.data,
            .width = info.width,
            .height = info.height,
            .format = info.format,
        });
        total_bytes += bytes.len;
    }

    const owned_images = try images.toOwnedSlice(allocator);
    errdefer allocator.free(owned_images);
    const owned_allocations = try allocations.toOwnedSlice(allocator);
    return .{ .items = owned_images, .allocations = owned_allocations };
}

fn localPathSource(source: []const u8) ?[]const u8 {
    if (source.len == 0 or source[0] == '#') return null;
    if (std.mem.startsWith(u8, source, "//") or std.mem.startsWith(u8, source, "\\\\")) return null;

    if (std.mem.indexOfScalar(u8, source, ':')) |colon| {
        const windows_drive = colon == 1 and std.ascii.isAlphabetic(source[0]);
        const first_separator = firstPathSeparator(source) orelse source.len;
        if (!windows_drive and colon < first_separator) return null;
    }

    var end = source.len;
    if (std.mem.indexOfScalar(u8, source, '?')) |query| end = @min(end, query);
    if (std.mem.indexOfScalar(u8, source, '#')) |fragment| end = @min(end, fragment);
    return if (end == 0) null else source[0..end];
}

fn firstPathSeparator(path: []const u8) ?usize {
    const slash = std.mem.indexOfScalar(u8, path, '/');
    const backslash = std.mem.indexOfScalar(u8, path, '\\');
    if (slash) |left| return if (backslash) |right| @min(left, right) else left;
    return backslash;
}

fn percentDecodePath(allocator: std.mem.Allocator, source: []const u8) !?[]u8 {
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);

    var index: usize = 0;
    while (index < source.len) {
        if (source[index] != '%') {
            try decoded.append(allocator, source[index]);
            index += 1;
            continue;
        }
        if (index + 2 >= source.len) {
            decoded.deinit(allocator);
            return null;
        }
        const high = hexValue(source[index + 1]) orelse {
            decoded.deinit(allocator);
            return null;
        };
        const low = hexValue(source[index + 2]) orelse {
            decoded.deinit(allocator);
            return null;
        };
        const byte = (high << 4) | low;
        if (byte == 0) {
            decoded.deinit(allocator);
            return null;
        }
        try decoded.append(allocator, byte);
        index += 3;
    }

    return try decoded.toOwnedSlice(allocator);
}

fn hexValue(byte: u8) ?u8 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        'A'...'F' => byte - 'A' + 10,
        else => null,
    };
}

fn resolveImagePath(allocator: std.mem.Allocator, document_path: []const u8, image_path: []const u8) ![]u8 {
    if (std.fs.path.isAbsolute(image_path)) return allocator.dupe(u8, image_path);
    const document_dir = std.fs.path.dirname(document_path) orelse ".";
    return std.fs.path.join(allocator, &.{ document_dir, image_path });
}

fn readImageFile(allocator: std.mem.Allocator, io: Io, path: []const u8) ![]u8 {
    var file = try Io.Dir.cwd().openFile(io, path, .{ .allow_directory = false });
    defer file.close(io);

    var file_buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &file_buffer);
    return reader.interface.allocRemaining(allocator, .limited(max_image_file_bytes));
}

const ImageInfo = struct {
    data: []const u8,
    width: u32,
    height: u32,
    format: zmd.RtfImageFormat,
};

fn inspectImage(bytes: []const u8) ?ImageInfo {
    if (pngInfo(bytes)) |info| return info;
    if (jpegInfo(bytes)) |info| return info;
    if (bmpInfo(bytes)) |info| return info;
    return null;
}

fn pngInfo(bytes: []const u8) ?ImageInfo {
    const signature = "\x89PNG\r\n\x1a\n";
    if (bytes.len < 24 or !std.mem.eql(u8, bytes[0..8], signature)) return null;
    if (!std.mem.eql(u8, bytes[12..16], "IHDR")) return null;
    const width = readU32Be(bytes[16..20]);
    const height = readU32Be(bytes[20..24]);
    if (!validDimensions(width, height)) return null;
    return .{ .data = bytes, .width = width, .height = height, .format = .png };
}

fn jpegInfo(bytes: []const u8) ?ImageInfo {
    if (bytes.len < 4 or bytes[0] != 0xff or bytes[1] != 0xd8) return null;
    var index: usize = 2;
    while (index + 1 < bytes.len) {
        while (index < bytes.len and bytes[index] != 0xff) : (index += 1) {}
        while (index < bytes.len and bytes[index] == 0xff) : (index += 1) {}
        if (index >= bytes.len) return null;
        const marker = bytes[index];
        index += 1;

        if (marker == 0xd9 or marker == 0xda) return null;
        if (marker == 0x01 or (marker >= 0xd0 and marker <= 0xd7)) continue;
        if (index + 2 > bytes.len) return null;
        const segment_length = readU16Be(bytes[index .. index + 2]);
        if (segment_length < 2 or index + segment_length > bytes.len) return null;

        if (isJpegStartOfFrame(marker)) {
            if (segment_length < 7) return null;
            const height: u32 = readU16Be(bytes[index + 3 .. index + 5]);
            const width: u32 = readU16Be(bytes[index + 5 .. index + 7]);
            if (!validDimensions(width, height)) return null;
            return .{ .data = bytes, .width = width, .height = height, .format = .jpeg };
        }
        index += segment_length;
    }
    return null;
}

fn isJpegStartOfFrame(marker: u8) bool {
    return switch (marker) {
        0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf => true,
        else => false,
    };
}

fn bmpInfo(bytes: []const u8) ?ImageInfo {
    if (bytes.len < 54 or bytes[0] != 'B' or bytes[1] != 'M') return null;
    const dib_header_size = readU32Le(bytes[14..18]);
    if (dib_header_size < 40 or 14 + dib_header_size > bytes.len) return null;

    const signed_width: i32 = @bitCast(readU32Le(bytes[18..22]));
    const signed_height: i32 = @bitCast(readU32Le(bytes[22..26]));
    if (signed_width <= 0 or signed_height == 0) return null;
    const width: u32 = @intCast(signed_width);
    const height: u32 = @intCast(if (signed_height < 0) -@as(i64, signed_height) else signed_height);
    if (!validDimensions(width, height)) return null;
    return .{ .data = bytes[14..], .width = width, .height = height, .format = .dib };
}

fn validDimensions(width: u32, height: u32) bool {
    return width > 0 and height > 0 and width <= max_image_dimension and height <= max_image_dimension;
}

fn readU16Be(bytes: []const u8) u16 {
    return (@as(u16, bytes[0]) << 8) | @as(u16, bytes[1]);
}

fn readU32Be(bytes: []const u8) u32 {
    return (@as(u32, bytes[0]) << 24) |
        (@as(u32, bytes[1]) << 16) |
        (@as(u32, bytes[2]) << 8) |
        @as(u32, bytes[3]);
}

fn readU32Le(bytes: []const u8) u32 {
    return @as(u32, bytes[0]) |
        (@as(u32, bytes[1]) << 8) |
        (@as(u32, bytes[2]) << 16) |
        (@as(u32, bytes[3]) << 24);
}

test "detects supported image dimensions and RTF formats" {
    const png = "\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR\x00\x00\x02\x80\x00\x00\x01\x68";
    const png_info = pngInfo(png).?;
    try std.testing.expectEqual(@as(u32, 640), png_info.width);
    try std.testing.expectEqual(@as(u32, 360), png_info.height);
    try std.testing.expectEqual(zmd.RtfImageFormat.png, png_info.format);

    const jpeg = "\xff\xd8\xff\xe0\x00\x04xx\xff\xc0\x00\x07\x08\x01\x2c\x02\x58";
    const jpeg_info = jpegInfo(jpeg).?;
    try std.testing.expectEqual(@as(u32, 600), jpeg_info.width);
    try std.testing.expectEqual(@as(u32, 300), jpeg_info.height);
    try std.testing.expectEqual(zmd.RtfImageFormat.jpeg, jpeg_info.format);

    var bmp = [_]u8{0} ** 54;
    bmp[0] = 'B';
    bmp[1] = 'M';
    bmp[14] = 40;
    bmp[18] = 0x20;
    bmp[19] = 0x03;
    bmp[22] = 0x58;
    bmp[23] = 0x02;
    const bmp_info = bmpInfo(&bmp).?;
    try std.testing.expectEqual(@as(u32, 800), bmp_info.width);
    try std.testing.expectEqual(@as(u32, 600), bmp_info.height);
    try std.testing.expectEqual(zmd.RtfImageFormat.dib, bmp_info.format);
    try std.testing.expectEqual(@as(usize, 40), bmp_info.data.len);
}

test "normalizes local image URL paths without accepting remote sources" {
    const decoded = (try percentDecodePath(std.testing.allocator, "images/my%20plot.png")).?;
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings("images/my plot.png", decoded);
    try std.testing.expectEqualStrings("images/p.png", localPathSource("images/p.png?raw=1#preview").?);
    try std.testing.expect(localPathSource("https://example.com/image.png") == null);
    try std.testing.expect(localPathSource("data:image/png;base64,AAAA") == null);
    try std.testing.expect(localPathSource("//example.com/image.png") == null);
}

test "loads an image relative to the Markdown document path" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const png = "\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR\x00\x00\x00\x20\x00\x00\x00\x10";
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "my plot.png", .data = png });

    var directory_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const directory_length = try tmp.dir.realPath(std.testing.io, &directory_buffer);
    const document_path = try std.fs.path.join(std.testing.allocator, &.{ directory_buffer[0..directory_length], "document.md" });
    defer std.testing.allocator.free(document_path);

    const sources = [_][]const u8{"my%20plot.png"};
    var loaded = try loadLocalRtfImages(std.testing.allocator, std.testing.io, document_path, &sources);
    defer loaded.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), loaded.items.len);
    try std.testing.expectEqualStrings(sources[0], loaded.items[0].source);
    try std.testing.expectEqual(@as(u32, 32), loaded.items[0].width);
    try std.testing.expectEqual(@as(u32, 16), loaded.items[0].height);
    try std.testing.expectEqual(zmd.RtfImageFormat.png, loaded.items[0].format);
}
