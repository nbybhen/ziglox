const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Token = @import("scanner.zig").Token;
const TokenType = @import("scanner.zig").TokenType;
const Value = @import("value.zig").Value;
const VM = @import("vm.zig").VM;
const Obj = @import("object.zig");

pub const Precedence = enum {
    prec_none,
    prec_assignment, // =
    prec_or, // or
    prec_and, // and
    prec_equality, // == !=
    prec_comparison, // < > <= >=
    prec_term, // + -
    prec_factor, // * /
    prec_unary, // ! -
    prec_call, // . ()
    prec_primary,
};

const Combined = std.fmt.ParseFloatError || std.mem.Allocator.Error;

pub const ParseRule = struct {
    prefix: ?*const fn (*Compiler) Combined!void,
    infix: ?*const fn (*Compiler) Combined!void,
    precedence: Precedence,
};

pub const Compiler = struct {
    const Self = @This();

    const rules = std.EnumArray(TokenType, ParseRule).init(.{
        .left_paren = ParseRule{ .prefix = &grouping, .infix = null, .precedence = .prec_none },
        .right_paren = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .left_brace = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .right_brace = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .comma = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .dot = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .minus = .{ .prefix = &Self.unary, .infix = &Self.binary, .precedence = .prec_term },
        .plus = .{ .prefix = null, .infix = &Self.binary, .precedence = .prec_term },
        .semicolon = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .slash = .{ .prefix = null, .infix = &Self.binary, .precedence = .prec_factor },
        .star = .{ .prefix = null, .infix = &Self.binary, .precedence = .prec_factor },
        .bang = .{ .prefix = &Self.unary, .infix = null, .precedence = .prec_none },
        .bang_equal = .{ .prefix = null, .infix = &Self.binary, .precedence = .prec_equality },
        .equal = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .equal_equal = .{ .prefix = null, .infix = &Self.binary, .precedence = .prec_equality },
        .greater = .{ .prefix = null, .infix = &Self.binary, .precedence = .prec_comparison },
        .greater_equal = .{ .prefix = null, .infix = &Self.binary, .precedence = .prec_comparison },
        .less = .{ .prefix = null, .infix = &Self.binary, .precedence = .prec_comparison },
        .less_equal = .{ .prefix = null, .infix = &Self.binary, .precedence = .prec_comparison },
        .identifier = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .string = .{ .prefix = &Self.string, .infix = null, .precedence = .prec_none },
        .number = .{ .prefix = &Self.number, .infix = null, .precedence = .prec_none },
        .kand = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .class = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .kelse = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .kfalse = .{ .prefix = &Self.literal, .infix = null, .precedence = .prec_none },
        .kfor = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .fun = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .kif = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .nil = .{ .prefix = &Self.literal, .infix = null, .precedence = .prec_none },
        .kor = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .print = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .kreturn = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .super = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .this = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .ktrue = .{ .prefix = &Self.literal, .infix = null, .precedence = .prec_none },
        .kvar = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .kwhile = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .kerror = .{ .prefix = null, .infix = null, .precedence = .prec_none },
        .eof = .{ .prefix = null, .infix = null, .precedence = .prec_none },
    });

    chunk: *Chunk,
    scanner: *Scanner,
    current: Token,
    previous: Token,
    hadError: bool,
    panicMode: bool,
    vm: *VM,

    pub fn init(scanner: *Scanner, vm: *VM) Self {
        return Self{
            .previous = undefined,
            .current = undefined,
            .hadError = false,
            .panicMode = false,
            .scanner = scanner,
            .chunk = undefined,
            .vm = vm,
        };
    }

    pub fn getRule(_: Self, t: TokenType) ParseRule {
        return rules.get(t);
    }

    pub fn advance(self: *Self) void {
        self.previous = self.current;

        while (true) {
            self.current = self.scanner.scanToken();

            var line: usize = std.math.maxInt(usize);

            if (self.current.line != line) {
                //std.debug.print("Line: {d:0>4} ", .{self.current.line});
                line = self.current.line;
            } else {
                std.debug.print("   | ", .{});
            }
            //std.debug.print("Type: {any}, Len: {d}\n", .{ self.current.type, self.current.len });

            if (self.current.type != .kerror) break;

            if (self.current.type == .eof) return;

            self.errorAtCurrent(self.current.start[0..self.current.len]);
        }
    }

    pub fn err(self: *Self, message: []const u8) void {
        self.errorAt(self.previous, message);
    }

    fn errorAtCurrent(self: *Self, message: []const u8) void {
        self.errorAt(self.current, message);
    }

    // TODO: Fix error handling (e.g. 1+[word])
    fn errorAt(self: *Self, token: Token, message: []const u8) void {
        if (self.panicMode) return;
        self.panicMode = true;
        std.debug.print("[line {d}] Error", .{token.line});

        switch (token.type) {
            .eof => std.debug.print(" at end", .{}),
            .kerror => {},
            else => std.debug.print(" at '{s}'", .{token.start[0..token.len]}),
        }

        std.debug.print(": {s}", .{message});
        self.hadError = true;
    }

    // Functions for Pratt-parsing rules
    pub fn grouping(self: *Self) !void {
        try self.expression();
        self.consume(.right_paren, "Expect ')' after expression.");
    }

    fn number(self: *Self) Combined!void {
        const value = try std.fmt.parseFloat(f64, self.previous.start[0..self.previous.len]);
        try self.emitConstant(Value.fromNumber(value));
    }

    // TODO: Change import
    fn string(self: *Self) !void {
        try self.emitConstant(Value{ .obj = &Obj.ObjString.copy(self.previous.start[0..self.previous.len], self.vm).obj });
    }

    fn literal(self: *Self) !void {
        try switch (self.previous.type) {
            .kfalse => self.emitOpCode(.op_false),
            .ktrue => self.emitOpCode(.op_true),
            .nil => self.emitOpCode(.op_nil),
            else => unreachable(),
        };
    }

    pub fn binary(self: *Self) Combined!void {
        const op_type = self.previous.type;
        const rule = self.getRule(op_type);
        try self.parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

        try switch (op_type) {
            .plus => self.emitOpCode(.op_add),
            .minus => self.emitOpCode(.op_sub),
            .star => self.emitOpCode(.op_mul),
            .slash => self.emitOpCode(.op_div),
            .bang_equal => self.emitOpCodes(.op_equal, .op_not),
            .equal_equal => self.emitOpCode(.op_equal),
            .greater => self.emitOpCode(.op_greater),
            .greater_equal => self.emitOpCodes(.op_less, .op_not),
            .less => self.emitOpCode(.op_less),
            .less_equal => self.emitOpCodes(.op_greater, .op_not),
            else => return,
        };
    }

    pub fn unary(self: *Self) !void {
        const op_type = self.previous.type;
        // Compiles the operand
        try self.parsePrecedence(.prec_unary);

        // Emits the operator instruction
        try switch (op_type) {
            .bang => self.emitOpCode(.op_not),
            .minus => self.emitOpCode(.op_negate),
            else => return,
        };
    }

    pub fn consume(self: *Self, t: TokenType, message: []const u8) void {
        if (self.current.type == t) {
            self.advance();
            return;
        }

        self.errorAtCurrent(message);
    }

    pub fn emitByte(self: Self, byte: u8) !void {
        try self.chunk.write(byte, self.previous.line);
    }

    pub fn emitOpBytes(self: Self, b1: OpCode, b2: u8) !void {
        try self.emitOpCode(b1);
        try self.emitByte(b2);
    }

    pub fn emitConstant(self: Self, value: Value) !void {
        try self.emitOpBytes(.op_constant, try self.makeConstant(value));
    }

    pub fn parsePrecedence(self: *Self, precedence: Precedence) !void {
        self.advance();
        const prefix_rule = self.getRule(self.previous.type).prefix;

        if (prefix_rule) |rule| {
            try rule(self);
        } else {
            self.err("Expected expression.\n");
            return;
        }

        while (@intFromEnum(precedence) <= @intFromEnum(self.getRule(self.current.type).precedence)) {
            self.advance();
            if (self.getRule(self.previous.type).infix) |infix_rule| {
                try infix_rule(self);
            }
        }
    }

    pub fn emitOpCode(self: Self, byte: OpCode) !void {
        try self.chunk.writeOp(byte, self.previous.line);
    }

    pub fn endCompiler(self: Self) !void {
        try self.emitReturn();
    }

    pub fn emitReturn(self: Self) !void {
        try self.emitOpCode(.op_return);
    }

    pub fn emitBytes(self: Self, b1: u8, b2: u8) void {
        self.emitByte(b1);
        self.emitByte(b2);
    }

    pub fn emitOpCodes(self: Self, op1: OpCode, op2: OpCode) !void {
        try self.emitOpCode(op1);
        try self.emitOpCode(op2);
    }

    pub fn expression(self: *Self) !void {
        try self.parsePrecedence(.prec_assignment);
    }

    fn makeConstant(self: Self, value: Value) !u8 {
        const constant = try self.chunk.addConstant(value);
        if (constant > std.math.maxInt(u8)) {
            self.err("Too many constants in one chunk.");
            return 0;
        }

        return @as(u8, constant);
    }

    pub fn compile(self: *Self, chunk: *Chunk) !bool {
        self.chunk = chunk;
        self.advance();
        try self.expression();

        self.consume(.eof, "Expected end of expression.\n");
        try self.endCompiler();
        return !self.hadError;
    }
};
