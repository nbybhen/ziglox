const std = @import("std");
const value = @import("value.zig");

const allocator = std.heap.page_allocator;

pub const OpCode = enum {
    op_return,
    op_constant,
    op_negate,
    op_add,
    op_sub,
    op_mul,
    op_div,

    pub fn toString(self: OpCode) []const u8 {
        return switch (self) {
            .op_return => "OP_RETURN",
            .op_constant => "OP_CONSTANT",
            .op_negate => "OP_NEGATE",
            .op_add => "OP_ADD",
            .op_sub => "OP_SUB",
            .op_mul => "OP_MULTIPLY",
            .op_div => "OP_DIVIDE",
        };
    }
};

pub const Chunk = struct {
    code: std.ArrayList(u8),
    constants: value.ValueArray,
    lines: std.ArrayList(usize),

    pub fn init() Chunk {
        return Chunk{
            .code = std.ArrayList(u8).init(allocator),
            .constants = value.ValueArray.init(),
            .lines = std.ArrayList(usize).init(allocator),
        };
    }

    pub fn write(self: *Chunk, byte: u8, line: usize) std.mem.Allocator.Error!void {
        try self.code.append(byte);
        try self.lines.append(line);
    }

    pub fn writeOp(self: *Chunk, op: OpCode, line: usize) std.mem.Allocator.Error!void {
        try self.code.append(@intFromEnum(op));
        try self.lines.append(line);
    }

    pub fn free(self: *Chunk) void {
        self.constants.free();
        self.code.deinit();
        self.lines.deinit();
    }

    pub fn addConstant(self: *Chunk, val: value.Value) std.mem.Allocator.Error!u8 {
        try self.constants.write(val);
        return @intCast(self.constants.values.items.len - 1);
    }

    pub fn disassemble(self: Chunk, name: []const u8) void {
        std.debug.print("=== {s} ===\n", .{name});
        var offset: usize = 0;

        while (offset < self.code.items.len) : (offset = self.disassembleInstruction(offset)) {}
    }

    pub fn disassembleInstruction(self: Chunk, offset: usize) usize {
        std.debug.print("{d:0>4} ", .{offset});
        if (offset > 0 and self.lines.items[offset] == self.lines.items[offset - 1]) {
            std.debug.print("   | ", .{});
        } else {
            std.debug.print("{d:>4} ", .{self.lines.items[offset]});
        }

        const instruction: OpCode = @enumFromInt(self.code.items[offset]);
        return switch (instruction) {
            .op_return, .op_negate, .op_add, .op_sub, .op_mul, .op_div => self.simpleInstruction(instruction.toString(), offset),
            .op_constant => self.constantInstruction("OP_CONSTANT", offset),
        };
    }

    pub fn simpleInstruction(_: Chunk, name: []const u8, offset: usize) usize {
        std.debug.print("{s}\n", .{name});
        return offset + 1;
    }

    pub fn constantInstruction(self: Chunk, name: []const u8, offset: usize) usize {
        const constant: u8 = self.code.items[offset + 1];
        std.debug.print("{s} | {d} ", .{ name, constant });
        self.constants.printValue(self.constants.values.items[constant]);
        return offset + 2;
    }
};
