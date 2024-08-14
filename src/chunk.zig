const std = @import("std");
const value = @import("value.zig");

const allocator = std.heap.page_allocator;

pub const OpCode = enum {
    OP_RETURN,
    OP_CONSTANT,
};

pub const Chunk = struct {
    code: std.ArrayList(u8),
    constants: value.ValueArray,
    lines: std.ArrayList(u8),

    pub fn init() Chunk {
        return Chunk{ .code = std.ArrayList(u8).init(allocator), .constants = value.ValueArray.init(), .lines = std.ArrayList(u8).init(allocator) };
    }

    pub fn write(self: *Chunk, byte: u8, line: u8) std.mem.Allocator.Error!void {
        try self.code.append(byte);
        try self.lines.append(line);
    }

    pub fn free(self: *Chunk) void {
        try self.constants.free();
        self.code.deinit();
        self.lines.deinit();
    }

    pub fn addConstant(self: *Chunk, val: value.Value) std.mem.Allocator.Error!usize {
        try self.constants.write(val);
        return self.constants.values.items.len - 1;
    }

    pub fn disassemble(self: Chunk, name: []const u8) !void {
        std.debug.print("=== {s} ===\n", .{name});
        var offset: usize = 0;

        while (offset < self.code.items.len) {
            offset = self.disassembleInstruction(offset);
        }
    }

    pub fn disassembleInstruction(self: Chunk, offset: usize) usize {
        std.debug.print("{d:0>4} ", .{offset});
        if (offset > 0 and self.lines.items[offset] == self.lines.items[offset - 1]) {
            std.debug.print("   |  ", .{});
        } else {
            std.debug.print("{d:0>4} ", .{self.lines.items[offset]});
        }

        const instruction: OpCode = @enumFromInt(self.code.items[offset]);
        return switch (instruction) {
            .OP_RETURN => self.simpleInstruction("OP_RETURN", offset),
            .OP_CONSTANT => self.constantInstruction("OP_CONSTANT", offset),
        };
    }

    pub fn simpleInstruction(_: Chunk, name: []const u8, offset: usize) usize {
        std.debug.print("{s}", .{name});
        return offset + 1;
    }

    pub fn constantInstruction(self: Chunk, name: []const u8, offset: usize) usize {
        const constant: u8 = self.code.items[offset + 1];
        std.debug.print("{s} | {d} ", .{ name, constant });
        self.constants.printValue(self.constants.values.items[constant]);
        return offset + 2;
    }
};
