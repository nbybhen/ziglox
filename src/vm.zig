const std = @import("std");
const obj = @import("object.zig");

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

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var debug = false;

pub const VM = struct {
    chunk: Chunk,
    ip: [*]u8,
    stack: std.ArrayList(Value),
    objects: ?*obj.Obj,

    pub fn init() VM {
        return VM{
            .chunk = Chunk.init(),
            .ip = undefined,
            .stack = std.ArrayList(Value).init(allocator),
            .objects = null,
        };
    }

    pub fn interpret(self: *VM, source: []u8) !void {
        var chunk = Chunk.init();
        defer chunk.free();

        var scanner = Scanner.init(source);

        var compiler = Compiler.init(&scanner, self);
        if (!(compiler.compile(&chunk) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            return InterpretResult.CompileErr;
        })) {
            return InterpretResult.CompileErr;
        }

        self.chunk = chunk;
        self.ip = chunk.code.items.ptr;

        _ = try self.run();
    }

    pub fn freeObjects(self: *VM) void {
        var object = self.objects;
        while (object != null) {
            const next = object.?.next;
            object = next;
        }
    }

    pub fn free(self: *VM) void {
        self.stack.deinit();
        self.freeObjects();
    }

    pub fn run(self: *VM) !void {
        self.resetStack();

        // TODO: Create debugging flag
        while (true) {
            if (false) {
                for (self.stack.items) |value| {
                    value.printValue();
                }
                std.debug.print("\n", .{});
                _ = self.chunk.disassembleInstruction(@intFromPtr(self.ip) - @intFromPtr(self.chunk.code.items.ptr));
            }

            const instruction = self.readByte();
            switch (@as(OpCode, @enumFromInt(instruction))) {
                .op_constant => {
                    const constant = self.readConstant();
                    try self.stack.append(constant);
                },
                .op_return => {
                    self.stack.pop().printValue();
                    std.debug.print("\n", .{});
                    return;
                },
                .op_negate => {
                    if (self.peek(0).isNumber()) {
                        try self.stack.append(Value.fromNumber(-self.stack.pop().number));
                    }
                    self.runtimeError("Operand must be a number.", .{});
                    return InterpretResult.RuntimeErr;
                },
                .op_add => {
                    if (obj.isObjType(self.peek(0), .obj_string) and obj.isObjType(self.peek(1), .obj_string)) {
                        try self.concatenate();
                    } else if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                        const b = self.stack.pop();
                        const a = self.stack.pop();
                        try self.stack.append(Value.fromNumber(a.number + b.number));
                    } else {
                        self.runtimeError("Operands must both be numbers or strings.\nItems: [{any}]", .{self.peek(0)});
                        return InterpretResult.RuntimeErr;
                    }
                },
                .op_sub => {
                    if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                        const b = self.stack.pop();
                        const a = self.stack.pop();
                        try self.stack.append(Value.fromNumber(a.number - b.number));
                    } else {
                        self.runtimeError("Operands must both be numbers", .{});
                        return InterpretResult.RuntimeErr;
                    }
                },
                .op_mul => {
                    if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                        const b = self.stack.pop();
                        const a = self.stack.pop();
                        try self.stack.append(Value.fromNumber(a.number * b.number));
                    } else {
                        self.runtimeError("Operands must both be numbers", .{});
                        return InterpretResult.RuntimeErr;
                    }
                },
                .op_div => {
                    if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                        const b = self.stack.pop();
                        const a = self.stack.pop();
                        try self.stack.append(Value.fromNumber(a.number / b.number));
                    } else {
                        self.runtimeError("Operands must both be numbers", .{});
                        return InterpretResult.RuntimeErr;
                    }
                },
                .op_nil => try self.stack.append(Value{ .nil = undefined }),
                .op_false => try self.stack.append(Value.fromBoolean(false)),
                .op_true => try self.stack.append(Value.fromBoolean(true)),
                .op_not => try self.stack.append(Value.fromBoolean(self.stack.pop().isFalsey())),
                .op_equal => {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    try self.stack.append(Value.fromBoolean(a.equal(b)));
                },
                .op_greater => {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    try self.stack.append(Value.fromBoolean(a.number > b.number));
                },
                .op_less => {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    try self.stack.append(Value.fromBoolean(a.number < b.number));
                },
            }
        }
    }

    pub fn concatenate(self: *VM) !void {
        const str_b = self.stack.pop().obj.asObjString();
        const str_a = self.stack.pop().obj.asObjString();

        const chars = obj.ObjString.allocateString(try std.mem.concat(gpa.allocator(), u8, &.{ str_a.chars, str_b.chars }), self);
        try self.stack.append(Value{ .obj = &chars.obj });
    }

    fn runtimeError(self: *VM, msg: []const u8, args: anytype) void {
        std.debug.print("{s} {any}\n", .{ msg, args });

        const instruction: usize = @intFromPtr(self.ip) - @intFromPtr(self.chunk.code.items.ptr) - 1;
        std.debug.print("[line {d}] in script\n", .{self.chunk.lines.items[instruction]});

        self.resetStack();
    }

    fn resetStack(self: *VM) void {
        self.stack.clearAndFree();
    }

    fn readConstant(self: *VM) Value {
        return self.chunk.constants.values.items[self.readByte()];
    }

    fn peek(self: *VM, dist: usize) Value {
        if (self.stack.items.len == 0) {
            std.debug.panic("STACK IS EMPTY", .{});
        }
        return self.stack.items[self.stack.items.len - dist - 1];
    }

    pub fn readByte(self: *VM) u8 {
        self.ip += 1;
        return (self.ip - 1)[0];
    }
};
