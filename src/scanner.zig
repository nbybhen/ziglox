const std = @import("std");

pub const Scanner = struct {
    start: [*]u8,
    current: [*]u8,
    line: usize,

    pub fn init(source: []u8) Scanner {
        return Scanner{ .start = source.ptr, .current = source.ptr, .line = 1 };
    }

    pub fn skipWhitespace(self: *Scanner) void {
        while (true) {
            _ = switch (self.peek()) {
                ' ', '\r', '\t' => self.advance(),
                '\n' => {
                    self.line += 1;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peekNext() == '/') {
                        while (self.peek() != '\n' and !self.isAtEnd()) _ = self.advance();
                    } else {
                        return;
                    }
                },
                else => return,
            };
        }
    }

    pub fn scanToken(self: *Scanner) Token {
        self.skipWhitespace();
        self.start = self.current;

        if (self.isAtEnd()) return self.makeToken(.eof);

        const c = self.advance();

        switch (c) {
            '(' => return self.makeToken(.left_paren),
            ')' => return self.makeToken(.right_paren),
            '{' => return self.makeToken(.left_brace),
            '}' => return self.makeToken(.right_brace),
            ';' => return self.makeToken(.semicolon),
            ',' => return self.makeToken(.comma),
            '.' => return self.makeToken(.dot),
            '-' => return self.makeToken(.slash),
            '+' => return self.makeToken(.plus),
            '/' => return self.makeToken(.slash),
            '*' => return self.makeToken(.star),
            '!' => return self.makeToken(if (self.match('=')) .bang_equal else .bang),
            '=' => return self.makeToken(if (self.match('=')) .equal_equal else .equal),
            '<' => return self.makeToken(if (self.match('=')) .less_equal else .less),
            '>' => return self.makeToken(if (self.match('=')) .greater_equal else .greater),
            '"' => return self.string(),
            '0'...'9' => return self.number(),
            else => {
                if (isAlpha(c)) {
                    return self.identifier();
                }
            },
        }

        std.debug.print("Unexpected char: {c}", .{c});
        return self.errorToken("Unexpected character.");
    }

    fn identifier(self: *Scanner) Token {
        while (isAlpha(self.peek()) and isDigit(self.peek())) _ = self.advance();
        return self.makeToken(self.identifierType());
    }

    fn identifierType(self: Scanner) TokenType {
        return switch (self.start[0]) {
            'a' => self.checkKeyword(1, 2, "nd", .kand),
            'c' => self.checkKeyword(1, 4, "lass", .class),
            'e' => self.checkKeyword(1, 3, "lse", .kelse),
            'i' => self.checkKeyword(1, 1, "f", .kif),
            'n' => self.checkKeyword(1, 2, "il", .nil),
            'o' => self.checkKeyword(1, 1, "r", .kor),
            'p' => self.checkKeyword(1, 4, "rint", .print),
            'r' => self.checkKeyword(1, 5, "eturn", .kreturn),
            's' => self.checkKeyword(1, 4, "uper", .super),
            'v' => self.checkKeyword(1, 2, "ar", .kvar),
            'w' => self.checkKeyword(1, 4, "hile", .kwhile),
            'f' => {
                if (@intFromPtr(self.current) - @intFromPtr(self.start) > 1) {
                    return switch (self.start[1]) {
                        'a' => self.checkKeyword(2, 3, "lse", .kfalse),
                        'o' => self.checkKeyword(2, 1, "r", .kfor),
                        'u' => self.checkKeyword(2, 1, "n", .fun),
                        else => .identifier,
                    };
                } else {
                    return .identifier;
                }
            },
            't' => {
                if (@intFromPtr(self.current) - @intFromPtr(self.start) > 1) {
                    return switch (self.start[1]) {
                        'h' => self.checkKeyword(2, 2, "is", .this),
                        'r' => self.checkKeyword(2, 2, "ue", .ktrue),
                        else => .identifier,
                    };
                } else {
                    return .identifier;
                }
            },
            else => .identifier,
        };
    }

    fn checkKeyword(self: Scanner, start: usize, len: usize, _: []const u8, t: TokenType) TokenType {
        //const tmp = [1]u8{self.current[0]};
        if (@intFromPtr(self.current) - @intFromPtr(self.start) == start + len) {
            return t; 
        }

        return .identifier;
    }

    fn number(self: *Scanner) Token {
        while (isDigit(self.peek())) _ = self.advance();

        // Looks for fractional part.
        if (self.peek() == '.' and isDigit(self.peekNext())) {
            // Consume the '.'
            _ = self.advance();

            while (isDigit(self.peek())) _ = self.advance();
        }

        return self.makeToken(.number);
    }

    fn string(self: *Scanner) Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }

        if (self.isAtEnd()) return self.errorToken("Unterminated string");

        // Closing quote
        _ = self.advance();
        return self.makeToken(.string);
    }

    fn makeToken(self: Scanner, t: TokenType) Token {
        return Token{ 
            .start = self.start, 
            .type = t, 
            .len = (@intFromPtr(self.current) - @intFromPtr(self.start)), 
            .line = self.line 
        };
    }

    fn errorToken(self: Scanner, msg: []const u8) Token {
        return Token{
            .type = .kerror,
            .start = msg.ptr,
            .len = msg.len,
            .line = self.line,
        };
    }

    //
    // Helper Functions
    //

    fn isDigit(c: u8) bool {
        return switch (c) {
            '0'...'9' => true,
            else => false,
        };
    }

    fn isAlpha(c: u8) bool {
        return switch (c) {
            'a'...'z', 'A'...'Z', '_' => true,
            else => false,
        };
    }

    fn advance(self: *Scanner) u8 {
        self.current += 1;
        return (self.current - 1)[0];
    }

    fn peekNext(self: *Scanner) u8 {
        if (self.isAtEnd()) return '\x00';
        return self.current[0];
    }

    fn isAtEnd(self: Scanner) bool {
        return self.current[0] == '\x00';
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.current[0] != expected) return false;
        self.current += 1;
        return true;
    }

    fn peek(self: Scanner) u8 {
        return self.current[0];
    }
};

pub const Token = struct {
    type: TokenType,
    start: [*]const u8,
    len: usize,
    line: usize,
};

pub const TokenType = enum {
    // SC Tokens
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    comma,
    dot,
    minus,
    plus,
    semicolon,
    slash,
    star,

    // One or two char tokens
    bang,
    bang_equal,
    equal,
    equal_equal,
    greater,
    greater_equal,
    less,
    less_equal,

    // Literals
    identifier,
    string,
    number,

    // Keywords (k-[name] if keyword exists)
    kand,
    class,
    kelse,
    kfalse,
    kfor,
    fun,
    kif,
    nil,
    kor,
    print,
    kreturn,
    super,
    this,
    ktrue,
    kvar,
    kwhile,

    kerror,
    eof,
};
