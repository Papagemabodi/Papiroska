const std = @import("std");

pub fn runAndWait(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
) !void {
    var child = std.process.Child.init(argv, allocator);
    try child.spawn();
    _ = try child.wait();
}
