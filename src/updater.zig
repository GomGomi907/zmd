const std = @import("std");
pub const releases_url = "https://api.github.com/repos/GomGomi907/zmd/releases/latest";
pub const installer_asset_name = "zmd-setup-windows-x86_64.exe";
pub const checksum_asset_name = installer_asset_name ++ ".sha256";

pub const InstallKind = enum { installed, portable };

pub const AvailableUpdate = struct {
    version: []u8,
    installer_url: []u8,
    checksum_url: []u8,

    pub fn deinit(update: *AvailableUpdate, allocator: std.mem.Allocator) void {
        allocator.free(update.version);
        allocator.free(update.installer_url);
        allocator.free(update.checksum_url);
        update.* = undefined;
    }
};

const Asset = struct {
    name: []const u8,
    browser_download_url: []const u8,
};

const ApiRelease = struct {
    tag_name: []const u8,
    draft: bool,
    prerelease: bool,
    assets: []const Asset,
};

const Candidate = struct {
    version: []u8,
    installer_url: []u8,
    checksum_url: []u8,
};

pub fn installKind(current_exe: []const u8, local_app_data: ?[]const u8) InstallKind {
    const base = local_app_data orelse return .portable;
    if (base.len == 0) return .portable;
    var expected_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const expected = std.fmt.bufPrint(&expected_buffer, "{s}\\Programs\\zmd\\zmd.exe", .{std.mem.trimEnd(u8, base, "\\/")}) catch return .portable;
    return if (pathEqlIgnoreCase(current_exe, expected)) .installed else .portable;
}

pub fn parseLatestRelease(allocator: std.mem.Allocator, metadata: []const u8, current_version: []const u8) !?AvailableUpdate {
    const candidate = try parseCandidate(allocator, metadata, current_version);
    return if (candidate) |release| .{
        .version = release.version,
        .installer_url = release.installer_url,
        .checksum_url = release.checksum_url,
    } else null;
}

fn parseCandidate(allocator: std.mem.Allocator, json: []const u8, current_version: []const u8) !?Candidate {
    var parsed = try std.json.parseFromSlice(ApiRelease, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const release = parsed.value;
    if (release.draft or release.prerelease) return null;

    const version_text = std.mem.trimStart(u8, release.tag_name, "vV");
    const latest = std.SemanticVersion.parse(version_text) catch return error.InvalidReleaseVersion;
    const current = std.SemanticVersion.parse(std.mem.trimStart(u8, current_version, "vV")) catch return error.InvalidCurrentVersion;
    if (latest.order(current) != .gt) return null;

    var installer_url: ?[]const u8 = null;
    var checksum_url: ?[]const u8 = null;
    for (release.assets) |asset| {
        if (std.mem.eql(u8, asset.name, installer_asset_name)) installer_url = asset.browser_download_url;
        if (std.mem.eql(u8, asset.name, checksum_asset_name)) checksum_url = asset.browser_download_url;
    }
    const installer = installer_url orelse return error.UpdateAssetMissing;
    const checksum = checksum_url orelse return error.UpdateChecksumMissing;
    const version_copy = try allocator.dupe(u8, version_text);
    errdefer allocator.free(version_copy);
    const installer_copy = try allocator.dupe(u8, installer);
    errdefer allocator.free(installer_copy);
    return .{
        .version = version_copy,
        .installer_url = installer_copy,
        .checksum_url = try allocator.dupe(u8, checksum),
    };
}

pub fn verifyChecksum(data: []const u8, checksum_file: []const u8) !void {
    const expected = std.mem.sliceTo(std.mem.trim(u8, checksum_file, " \t\r\n"), ' ');
    if (expected.len != 64) return error.InvalidUpdateChecksum;
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &digest, .{});
    const actual = std.fmt.bytesToHex(digest, .lower);
    if (!std.ascii.eqlIgnoreCase(expected, &actual)) return error.UpdateChecksumMismatch;
}

fn pathEqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |left, right| {
        const l = if (left == '/') '\\' else std.ascii.toLower(left);
        const r = if (right == '/') '\\' else std.ascii.toLower(right);
        if (l != r) return false;
    }
    return true;
}

test "selects only a newer stable release with both assets" {
    const json =
        \\{"tag_name":"v0.2.4","draft":false,"prerelease":false,"assets":[
        \\{"name":"zmd-setup-windows-x86_64.exe","browser_download_url":"https://example.test/zmd.exe"},
        \\{"name":"zmd-setup-windows-x86_64.exe.sha256","browser_download_url":"https://example.test/zmd.sha256"}]}
    ;
    const candidate = (try parseCandidate(std.testing.allocator, json, "0.2.3")).?;
    defer {
        std.testing.allocator.free(candidate.version);
        std.testing.allocator.free(candidate.installer_url);
        std.testing.allocator.free(candidate.checksum_url);
    }
    try std.testing.expectEqualStrings("0.2.4", candidate.version);
    try std.testing.expect((try parseCandidate(std.testing.allocator, json, "0.2.4")) == null);
}

test "rejects prereleases and incomplete release assets" {
    const prerelease =
        \\{"tag_name":"v0.3.0-beta.1","draft":false,"prerelease":true,"assets":[]}
    ;
    try std.testing.expect((try parseCandidate(std.testing.allocator, prerelease, "0.2.3")) == null);
    const incomplete =
        \\{"tag_name":"v0.2.4","draft":false,"prerelease":false,"assets":[]}
    ;
    try std.testing.expectError(error.UpdateAssetMissing, parseCandidate(std.testing.allocator, incomplete, "0.2.3"));
}

test "verifies release checksum before staging" {
    const data = "zmd update";
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &digest, .{});
    const expected = std.fmt.bytesToHex(digest, .lower);
    try verifyChecksum(data, &expected);
    try std.testing.expectError(error.UpdateChecksumMismatch, verifyChecksum("altered", &expected));
}

test "distinguishes installed and portable paths" {
    const local = "C:\\Users\\zmd\\AppData\\Local";
    try std.testing.expectEqual(InstallKind.installed, installKind("c:/users/zmd/appdata/local/programs/ZMD/zmd.exe", local));
    try std.testing.expectEqual(InstallKind.portable, installKind("D:\\Tools\\zmd.exe", local));
    try std.testing.expectEqual(InstallKind.portable, installKind("D:\\Tools\\zmd.exe", null));
}
