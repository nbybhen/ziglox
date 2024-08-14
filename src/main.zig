const std = @import("std");
const chunk = @import("chunk.zig").Chunk;
const opcode = @import("chunk.zig").OpCode;

pub fn main() !void {
    var tmp = chunk.init();

    defer tmp.free();

    const constant = try tmp.addConstant(1.2);
    try tmp.write(@intFromEnum(opcode.OP_CONSTANT), 123);
    try tmp.write(@intCast(constant), 123);

    try tmp.write(@intFromEnum(opcode.OP_RETURN), 123);

    try tmp.disassemble("test");
}
