const std = @import("std");
const stdin = std.io.getStdIn();
const stdout = std.io.getStdOut();
const debug = std.debug;
const mibu = @import("mibu/src/main.zig");
const zigimg = @import("zigimg-zigimg_zig_0.14.1/zigimg.zig");
const runit = @import("runit.zig");
const checker = @import("checker.zig");

var scaledh: u16 = 0;
var scaledw: u16 = 0;

var xcoord: i32 = 0;
var ycoord: i32 = 0;
var wh: [2]i32 = undefined;
var xdrag: i32 = 0;
var ydrag: i32 = 0;
var zoomw: f32 = 0;
var zoomh: f32 = 0;
var amplify: i32 = 1;

//turn path into arr
pub fn getpath() []const u8 {
    const argums: []const u8 = std.mem.span(std.os.argv[1]);
    return argums;
}

pub fn tobase64(alloc: std.mem.Allocator, pth: []const u8) ![]u8 {
    const base64_encoder = std.base64.standard.Encoder;
    const enc_len = std.base64.Base64Encoder.calcSize(&base64_encoder, pth.len);
    const encalloc = try alloc.alloc(u8, enc_len);
    _ = std.base64.Base64Encoder.encode(&base64_encoder, encalloc, pth);
    return encalloc;
}

pub fn getwh(alloc: std.mem.Allocator, path: []const u8) ![]i32 {
    //get dimensions
    var image = try zigimg.Image.fromFilePath(alloc, path);
    defer image.deinit();

    //cast to int dims
    wh[0] = @intCast(image.width);
    wh[1] = @intCast(image.height);
    //return it
    return &wh;
}

pub fn redraw() !void {
    try mibu.cursor.goTo(stdout.writer(), xcoord, ycoord);
    try stdout.writer().print("\x1b_Ga=d,d=i,i=17;\x1b\\", .{});
    try stdout.writer().print("\x1b_Ga=p,i=17,r={d},c={d},w={d},h={d},x={d},y={d}\x1b\\", .{ scaledh, scaledw, zoomw, zoomh, xdrag, ydrag });
}

pub fn main() !void {
    var gp = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gp.deinit();
    const alloc = gp.allocator();

    //get orig image
    const orig_path = getpath();

    //get thy image
    const img_path = try checker.getOrConvertImage(alloc, orig_path);
    defer alloc.free(img_path);

    //get image dimensions
    const imgdim: []i32 = try getwh(alloc, img_path);
    //print dimensions
    debug.print("{}x{}\n", .{ imgdim[0], imgdim[1] });
    //fetching width and height of term
    const size = try mibu.term.getSize(0);

    //hide cursor
    try mibu.cursor.hide(stdout.writer());
    defer mibu.cursor.show(stdout.writer()) catch unreachable;
    //wh fetch
    const termw: i32 = size.width;
    const termh: i32 = size.height;

    //calculate thy thingymabob to fit in da center
    const cellw: i32 = 10;
    const cellh: i32 = 20;
    const imgw = @divFloor(imgdim[0], cellw);
    const imgh = @divFloor(imgdim[1], cellh);

    const scalew: f32 = @as(f32, @floatFromInt(termw)) / @as(f32, @floatFromInt(imgw));
    const scaleh: f32 = @as(f32, @floatFromInt(termh)) / @as(f32, @floatFromInt(imgh));

    const scale: f32 = @min(1.0, scalew, scaleh);

    scaledw = @intFromFloat(@floor(@as(f32, @floatFromInt(imgw)) * scale));
    scaledh = @intFromFloat(@floor(@as(f32, @floatFromInt(imgh)) * scale));

    xcoord = @divTrunc(termw - scaledw, 2);
    ycoord = @divTrunc(termh - scaledh, 2);

    //debug printing
    debug.print("imgw: {}\nimgh: {}\n", .{ imgw, imgh });
    debug.print("scalew: {}\nscaleh: {}\n", .{ scalew, scaleh });
    debug.print("scale: {}\nscaledw: {}\nscaledh: {}\nxcoord: {}\nycoord: {}\n", .{ scale, scaledw, scaledh, xcoord, ycoord });

    //init rawmode , mouse tracking and altterm
    try stdout.writer().print("{s}", .{mibu.utils.enable_mouse_tracking});
    defer stdout.writer().print("{s}", .{mibu.utils.disable_mouse_tracking}) catch {};
    var term = try mibu.term.enableRawMode(stdin.handle);
    defer term.disableRawMode() catch {};

    try mibu.term.enterAlternateScreen(stdout.writer());
    defer mibu.term.exitAlternateScreen(stdout.writer()) catch unreachable;

    const path = try tobase64(alloc, img_path);
    defer alloc.free(path);

    //set cursor to center
    try mibu.cursor.goTo(stdout.writer(), xcoord, ycoord);
    //preload image
    try stdout.writer().print("\x1b_Ga=t,f=100,t=f,i=17;{s}\x1b\\", .{path});
    //render image
    try stdout.writer().print("\x1b_Ga=p,i=17,r={d},c={d}\x1b\\", .{ scaledh, scaledw });
    //input handling
    zoomw = @floatFromInt(imgdim[0]);
    zoomh = @floatFromInt(imgdim[1]);
    const staticw: f32 = @floatFromInt(imgdim[0]);
    const statich: f32 = @floatFromInt(imgdim[1]);
    const aspect_ratio = statich / staticw;
    const ten: f32 = 10;

    while (true) {
        const next = try mibu.events.nextWithTimeout(stdin, 1000);
        switch (next) {
            .mouse => |m| {
                switch (m.button) {
                    .scroll_up => {
                        zoomw -= staticw / ten;
                        zoomh -= (staticw / ten) * aspect_ratio;
                        if (zoomw < 0) zoomw = 0;
                        if (zoomh < 0) zoomh = 0;
                        try redraw();
                    },
                    .scroll_down => {
                        zoomw += staticw / ten;
                        zoomh += (staticw / ten) * aspect_ratio;

                        if (zoomw >= staticw) {
                            xdrag = 0;
                            ydrag = 0;
                        }

                        try redraw();
                    },
                    else => {},
                }
            },
            .key => |k| {
                switch (k) {
                    .char => |c| {
                        if (c == 'q') break;
                        if (c == 'w') {
                            ydrag -= 4 * amplify;
                            if (ydrag < 0) ydrag = 0;
                            try redraw();
                        }
                        if (c == 's') {
                            ydrag += 4 * amplify;
                            const max_ydrag = @max(0, @as(i32, @intFromFloat(zoomh)) - (scaledh * cellh));
                            if (ydrag > max_ydrag) ydrag = max_ydrag;
                            try redraw();
                        }
                        if (c == 'a') {
                            xdrag -= 4 * amplify;
                            if (xdrag < 0) xdrag = 0;
                            try redraw();
                        }
                        if (c == 'd') {
                            xdrag += 4 * amplify;
                            const max_xdrag = @max(0, @as(i32, @intFromFloat(zoomw)) - (scaledw * cellw));
                            if (xdrag > max_xdrag) xdrag = max_xdrag;
                            try redraw();
                        }
                    },
                    .ctrl => |c| {
                        if (c == 'c') break;
                    },
                    .shift_down => |c| {
                        c;
                        amplify = 10;
                    },
                    .shift_up => |c| {
                        c;
                        amplify = 1;
                    },

                    else => {},
                }
            },
            else => {},
        }
    }
}
