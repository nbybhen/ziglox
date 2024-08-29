const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Token = @import("scanner.zig").Token;
const TokenType = @import("scanner.zig").TokenType;
const Value = @import("value.zig").Value;

pub const Precedence = enum {
    none,
    assignment, // =
    por, // or
    pand, // and
    equality, // == !=
    comparison, // < > <= >=
    term, // + -
    factor, // * /
    unary, // ! -
    call, // . ()
    primary,
};

const Combined = std.fmt.ParseFloatError || std.mem.Allocator.Error;

pub const ParseRule = struct {
    prefix: *const fn (*Compiler) Combined!void,
    infix: *const fn (*Compiler) Combined!void,
    precedence: Precedence,
};

pub const Compiler = struct {
    const Self = @This();

    const rules = std.EnumArray(TokenType, ParseRule).init(.{
        .left_paren = ParseRule{ .prefix = &grouping, .infix = undefined, .precedence = .none },
        .right_paren = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .left_brace = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .right_brace = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .comma = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .dot = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .minus = .{ .prefix = &Self.unary, .infix = &Self.binary, .precedence = .term },
        .plus = .{ .prefix = undefined, .infix = &Self.binary, .precedence = .term },
        .semicolon = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .slash = .{ .prefix = undefined, .infix = &Self.binary, .precedence = .factor },
        .star = .{ .prefix = undefined, .infix = &Self.binary, .precedence = .factor },
        .bang = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .bang_equal = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .equal = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .equal_equal = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .greater = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .greater_equal = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .less = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .less_equal = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .identifier = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .string = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .number = .{ .prefix = &Self.number, .infix = undefined, .precedence = .none },
        .kand = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .class = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .kelse = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .kfalse = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .kfor = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .fun = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .kif = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .nil = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .kor = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .print = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .kreturn = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .super = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .this = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .ktrue = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .kvar = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .kwhile = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .kerror = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
        .eof = .{ .prefix = undefined, .infix = undefined, .precedence = .none },
    });

    chunk: *Chunk,
    scanner: *Scanner,
    current: Token,
    previous: Token,
    hadError: bool,
    panicMode: bool,

    pub fn init(scanner: *Scanner) Self {
        return Self{
            .previous = undefined,
            .current = undefined,
            .hadError = false,
            .panicMode = false,
            .scanner = scanner,
            .chunk = undefined,
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
                std.debug.print("Line: {d:0>4} ", .{self.current.line});
                line = self.current.line;
            } else {
                std.debug.print("   | ", .{});
            }
            std.debug.print("Type: {any}, Len: {d}\n", .{ self.current.type, self.current.len });

            if (self.current.type != .kerror) break;

            if (self.current.type == .eof) return;

            self.errorAtCurrent(self.current.start[0..self.current.len]);
        }
    }

    pub fn err(self: *Self, message: []const u8) void {
        self.errorAt(self.previous, message);
    }

    fn errorAtCurrent(self: *Self, message: []const u8) void {
        self.errorAt(self.previous, message);
    }

    fn errorAt(self: *Self, token: Token, message: []const u8) void {
        if (self.panicMode) return;
        self.panicMode = true;
        std.debug.print("[line {d}] Error:", .{token.line});

        switch (token.type) {
            .eof => std.debug.print(" at end", .{}),
            .kerror => std.debug.print(" at '{d} {any}'", .{ token.line, token.start }),
            else => {},
        }

        std.debug.print(": {s}", .{message});
        self.hadError = true;
    }

    pub fn grouping(self: *Self) !void {
        try self.expression();
        self.consume(.right_paren, "Expect ')' after expression.");
    }

    fn number(self: *Self) Combined!void {
        const value: Value = try std.fmt.parseFloat(Value, self.previous.start[0..self.previous.len]);
        try self.emitConstant(value);
    }

    pub fn binary(self: *Self) Combined!void {
        const op_type = self.previous.type;
        const rule = self.getRule(op_type);
        try self.parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

        try switch (op_type) {
            .plus => self.emitOpByte(.op_add),
            .minus => self.emitOpByte(.op_sub),
            .star => self.emitOpByte(.op_mul),
            .slash => self.emitOpByte(.op_div),
            else => return,
        };
    }

    pub fn unary(self: *Self) !void {
        const op_type = self.previous.type;
        // Compiles the operand
        try self.parsePrecedence(.unary);

        // Emits the operator instruction
        try switch (op_type) {
            .minus => self.emitOpByte(.op_negate),
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
        try self.emitOpByte(b1);
        try self.emitByte(b2);
    }

    pub fn emitConstant(self: Self, value: Value) !void {
        try self.emitOpBytes(.op_constant, try self.makeConstant(value));
    }

    pub fn parsePrecedence(self: *Self, precedence: Precedence) !void {
        self.advance();
        const prefix_rule = self.getRule(self.previous.type).prefix;
        if (prefix_rule == undefined) {
            self.err("Expected expression");
            return;
        }

        try prefix_rule(self);

        while (@intFromEnum(precedence) <= @intFromEnum(self.getRule(self.current.type).precedence)) {
            self.advance();
            try self.getRule(self.previous.type).infix(self);
        }
    }

    pub fn emitOpByte(self: Self, byte: OpCode) !void {
        try self.chunk.writeOp(byte, self.previous.line);
    }

    pub fn endCompiler(self: Self) !void {
        try self.emitReturn();
    }

    pub fn emitReturn(self: Self) !void {
        try self.emitOpByte(.op_return);
    }

    pub fn emitBytes(self: Self, b1: u8, b2: u8) void {
        self.emitByte(b1);
        self.emitByte(b2);
    }

    pub fn expression(self: *Self) !void {
        try self.parsePrecedence(.assignment);
    }

    fn makeConstant(self: Self, value: Value) !u8 {
        const constant = try self.chunk.addConstant(value);
        if (constant > std.math.maxInt(u8)) {
            self.err("Too many constants in one chunk.");
            return 0;
        }

        return @as(u8, constant);
    }

    pub fn compile(self: *Self, chunk: *Chunk) !void {
        self.chunk = chunk;
        self.advance();
        try self.expression();

        self.consume(.eof, "Expected end of expression.");
        try self.endCompiler();
        //return !self.hadError;
    }
};
