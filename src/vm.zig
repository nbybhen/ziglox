const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const Compiler = @import("compiler.zig").Compiler;
const Scanner = @import("scanner.zig").Scanner;

const Error = InterpretResult || std.fs.File.WriteError;

pub const InterpretResult = error{
    CompileErr,
    RuntimeErr,
};

const allocator = std.heap.page_allocator;

var debug = false;

pub const VM = struct {
    chunk: Chunk,
    ip: [*]u8,
    stack: std.ArrayList(Value),

    pub fn init() VM {
        return VM{
            .chunk = Chunk.init(),
            .ip = undefined,
            .stack = std.ArrayList(Value).init(allocator),
        };
    }

    pub fn interpret(self: *VM, source: []u8) !void {
        std.debug.print("Source: {s}\n", .{source});

        var chunk = Chunk.init();
        defer chunk.free();

        var scanner = Scanner.init(source);

        var compiler = Compiler.init(&scanner);
        compiler.compile(&chunk) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            return InterpretResult.CompileErr;
        };

        self.chunk = chunk;
        self.ip = chunk.code.items.ptr;

        _ = try self.run();
    }

    pub fn free(self: *VM) void {
        self.stack.deinit();
    }

    pub fn run(self: *VM) !void {
        while (true) {
            if (true) {
                for (self.stack.items) |value| {
                    std.debug.print("[{d}]\n", .{value});
                }
                std.debug.print("\n", .{});
                _ = self.chunk.disassembleInstruction(@intFromPtr(self.ip) - @intFromPtr(self.chunk.code.items.ptr));
            }

            const instruction = self.readByte();
            switch (@as(OpCode, @enumFromInt(instruction))) {
                .op_constant => {
                    const constant = self.readConstant();
                    try self.stack.append(constant);
                    std.debug.print("{d}\n", .{constant});
                },
                .op_return => {
                    std.debug.print("{d}", .{self.stack.pop()});
                    std.debug.print("\n", .{});
                    return;
                },
                .op_negate => try self.stack.append(-self.stack.pop()),
                .op_add => {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    try self.stack.append(a + b);
                },
                .op_sub => {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    try self.stack.append(a - b);
                },
                .op_mul => {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    try self.stack.append(a * b);
                },
                .op_div => {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    try self.stack.append(a / b);
                },
            }
        }
    }

    fn readConstant(self: *VM) Value {
        return self.chunk.constants.values.items[self.readByte()];
    }

    pub fn readByte(self: *VM) u8 {
        self.ip += 1;
        return (self.ip - 1)[0];
    }
};
