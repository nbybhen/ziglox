const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const VM = @import("vm.zig").VM;

pub fn main() !void {
    var chunk = Chunk.init();
    defer chunk.free();

    var vm = VM.init();
    defer vm.free();

    var constant = try chunk.addConstant(1.2);
    try chunk.writeOp(.op_constant, 123);
    try chunk.write(constant, 123);

    constant = try chunk.addConstant(3.4);
    try chunk.writeOp(.op_constant, 123);
    try chunk.write(constant, 123);

    try chunk.writeOp(.op_add, 123);

    constant = try chunk.addConstant(5.6);
    try chunk.writeOp(.op_constant, 123);
    try chunk.write(constant, 123);

    try chunk.writeOp(.op_div, 123);
    try chunk.writeOp(.op_negate, 123);
    try chunk.writeOp(.op_return, 123);

    chunk.disassemble("test");
    try vm.interpret(chunk);
}
