const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;

pub fn compile(source: []u8) void {
    var scanner = Scanner.init(source);
    var line: usize = std.math.maxInt(usize);

    while (true) {
        const token = scanner.scanToken();
        if (token.line != line) {
            std.debug.print("Line: {d:0>4} ", .{token.line});
            line = token.line;
        } else {
            std.debug.print("   | ", .{});
        }
        std.debug.print("Type: {any}, Len: {d}\n", .{ token.type, token.len });

        if (token.type == .eof) break;
    }
}
