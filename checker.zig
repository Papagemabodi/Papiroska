const std = @import("std");
const runit = @import("runit.zig");

pub fn getCacheDir(alloc: std.mem.Allocator) ![]u8 {
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
    return try std.fmt.allocPrint(alloc, "{s}/.cache/papiroska", .{home});
}

// Get png path
pub fn getOrConvertImage(alloc: std.mem.Allocator, picpth: []const u8) ![]u8 {
    // Check for conversion req
    const needs_convert = std.mem.endsWith(u8, picpth, ".jpg") or
        std.mem.endsWith(u8, picpth, ".jpeg") or
        std.mem.endsWith(u8, picpth, ".webp");

    if (!needs_convert) {
        // Return path
        return try alloc.dupe(u8, picpth);
    }

    // Get cache dir
    const cache_dir = try getCacheDir(alloc);
    defer alloc.free(cache_dir);

    std.fs.makeDirAbsolute(cache_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // Hash orig path to be used as a filename
    var hasher = std.crypto.hash.Blake3.init(.{});
    hasher.update(picpth);
    var hash_out: [32]u8 = undefined;
    hasher.final(&hash_out);

    // Convert hash to hex string
    const hashed_name = try std.fmt.allocPrint(
        alloc,
        "{s}",
        .{std.fmt.fmtSliceHexLower(&hash_out)},
    );
    defer alloc.free(hashed_name);

    // Build destination path
    const dest_path = try std.fmt.allocPrint(
        alloc,
        "{s}/{s}.png",
        .{ cache_dir, hashed_name },
    );

    // Check if cached file exists
    const cache_exists = blk: {
        std.fs.accessAbsolute(dest_path, .{}) catch {
            break :blk false;
        };
        break :blk true;
    };

    if (!cache_exists) {
        //std.debug.print("Converting {s} to PNG...\n", .{picpth});
        try runit.runAndWait(alloc, &[_][]const u8{ "vips", "copy", picpth, dest_path });
        //std.debug.print("Cached at: {s}\n", .{dest_path});
    } else {
        //std.debug.print("Using cached PNG: {s}\n", .{dest_path});
    }

    return dest_path;
}
