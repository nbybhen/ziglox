const std = @import("std");

const Value = @import("value.zig").Value;
const VM = @import("vm.zig").VM;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// AS_OBJ == Value.obj

pub const Obj = struct {
    obj_type: ObjType,
    next: ?*Obj,

    pub fn allocateObj(vm: *VM, obj_type: ObjType, T: type) *Obj {
        const obj = allocator.create(T) catch {
            std.debug.print("Can't allocate object.\n", .{});
            std.process.exit(200);
        };

        obj.obj = Obj{ .obj_type = obj_type, .next = vm.objects };

        return &obj.obj;
    }

    pub fn free(_: *Obj) void {}

    pub fn asObjString(self: *Obj) *ObjString {
        return @alignCast(@fieldParentPtr("obj", self));
    }
};

pub fn isObjType(val: Value, obj_type: ObjType) bool {
    return val.isObj() and val.obj.obj_type == obj_type;
}

pub const ObjType = enum { obj_string };

// TODO: Fix strings containing ""
pub const ObjString = struct {
    obj: Obj,
    length: usize,
    chars: []const u8,

    pub fn allocateString(chars: []const u8, vm: *VM) *ObjString {
        const tmp = Obj.allocateObj(vm, .obj_string, ObjString);
        const string = tmp.asObjString();

        string.length = chars.len;
        string.chars = chars;

        return string;
    }

    pub fn free(self: *ObjString) void {
        allocator.free(self.chars);
        allocator.destroy(self);
    }

    pub fn copy(src: []const u8, vm: *VM) *ObjString {
        const dest = allocator.alloc(u8, src.len) catch {
            std.debug.print("Error allocating string!\n", .{});
            std.process.exit(200);
        };
        std.mem.copyForwards(u8, dest, src);
        return allocateString(dest, vm);
    }
};
