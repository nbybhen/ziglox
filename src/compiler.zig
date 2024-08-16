const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;

pub fn compile(source: []u8) void{
    var scanner = Scanner.init(source);
    var line: usize = std.math.maxInt(usize);

    while (true) {
        const token = scanner.scanToken();
        if (token.line != line) {
            std.debug.print("{d:>4} ", .{token.line});
            line = token.line;
        }
        else {
            std.debug.print("   | ", .{});
        }
        std.debug.print("{any} {d} {any}", .{token.type, token.len, token.start});

        if (token.type == .eof or token.type == .kerror) break;
    }
}
