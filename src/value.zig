const std = @import("std");

const allocator = std.heap.page_allocator;

pub const Value = union(enum) {
    boolean: bool,
    number: f64,
    nil,

    // Creates a new Value based on a bool / f64
    pub fn fromNumber(value: f64) Value {
        return Value{ .number = value };
    }

    pub fn fromBoolean(value: bool) Value {
        return Value{ .boolean = value };
    }

    // Checks if the current Value is a bool, num, or nil
    pub fn isBoolean(self: Value) bool {
        return switch (self) {
            .boolean => true,
            else => false,
        };
    }

    pub fn isNumber(self: Value) bool {
        return switch (self) {
            .number => true,
            else => false,
        };
    }

    pub fn isNil(self: Value) bool {
        return switch (self) {
            .nil => true,
            else => false,
        };
    }

    pub fn isFalsey(self: Value) bool {
        return self.isNil() or (self.isBoolean() and !self.boolean);
    }

    pub fn printValue(self: Value) void {
        switch (self) {
            .boolean => std.debug.print("value = {}\n", .{self.boolean}),
            .number => std.debug.print("value = {d}\n", .{self.number}),
            else => std.debug.print("value = nil\n", .{}),
        }
    }

    pub fn equal(self: Value, right: Value) bool {
        return switch (self) {
            .boolean => |a| {
                switch (right) {
                    .boolean => |b| return b == a,
                    else => return false,
                }
            },
            .number => |a| {
                switch (right) {
                    .number => |b| return b == a,
                    else => return false,
                }
            },
            .nil => {
                switch (right) {
                    .nil => return true,
                    else => return false,
                }
            },
        };
    }
};

pub const ValueArray = struct {
    values: std.ArrayList(Value),

    pub fn init() ValueArray {
        return ValueArray{ .values = std.ArrayList(Value).init(allocator) };
    }

    pub fn write(self: *ValueArray, value: Value) std.mem.Allocator.Error!void {
        try self.values.append(value);
    }

    pub fn free(self: *ValueArray) void {
        self.values.deinit();
    }

    pub fn printValue(_: ValueArray, value: Value) void {
        std.debug.print("-> {d}\n", .{value.number});
    }
};
