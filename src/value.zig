const std = @import("std");

const allocator = std.heap.page_allocator;

pub const Value = f32;

pub const ValueArray = struct {
    values: std.ArrayList(Value),

    pub fn init() ValueArray {
        return ValueArray{ .values = std.ArrayList(Value).init(allocator) };
    }

    pub fn write(self: *ValueArray, value: Value) std.mem.Allocator.Error!void {
        try self.values.append(value);
    }

    pub fn free(self: *ValueArray) !void {
        self.values.deinit();
    }

    pub fn printValue(_: ValueArray, value: Value) void {
        std.debug.print("-> {d}\n", .{value});
    }
};
