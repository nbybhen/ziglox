const Value = @import("value.zig").Value;
const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// AS_OBJ == Value.obj

pub const Obj = struct {
    obj_type: ObjType,

    pub fn allocateObj(obj_type: ObjType, T: type) *Obj {
        const obj = allocator.create(T) catch {
            std.debug.print("Can't allocate object.\n", .{});
            std.process.exit(200);
        };

        obj.obj = Obj{ .obj_type = obj_type };

        return &obj.obj;
    }

    pub fn asObjString(self: *Obj) *ObjString {
        return @alignCast(@fieldParentPtr("obj", self));
    }
};

pub fn isObjType(val: Value, obj_type: ObjType) bool {
    return val.isObj() and val.obj.obj_type == obj_type;
}

pub const ObjType = enum { obj_string };

pub const ObjString = struct {
    obj: Obj,
    length: usize,
    chars: []const u8,

    pub fn allocateString(chars: []const u8) *ObjString {
        const tmp = Obj.allocateObj(.obj_string, ObjString);
        const string = tmp.asObjString();

        string.length = chars.len;
        string.chars = chars;

        return string;
    }

    pub fn copy(src: []const u8) *ObjString {
        const dest = allocator.alloc(u8, src.len) catch {
            std.debug.print("Error allocating string!\n", .{});
            std.process.exit(200);
        };
        std.mem.copyForwards(u8, dest, src);
        return allocateString(dest);
    }
};
