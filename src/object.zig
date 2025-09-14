const std = @import("std");

const Value = @import("value.zig").Value;
const VM = @import("vm.zig").VM;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const hashFn = std.hash.Fnv1a_32.hash;

// AS_OBJ == Value.obj
pub const Obj = struct {
    obj_type: ObjType,
    next: ?*Obj,
    hash: u32,

    pub fn allocateObj(vm: *VM, obj_type: ObjType, T: type, hash: u32) *Obj {
        const obj = allocator.create(T) catch {
            std.debug.print("Can't allocate object.\n", .{});
            std.process.exit(200);
        };

        obj.obj = Obj{ .obj_type = obj_type, .next = vm.objects, .hash=hash };

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

const AdaptedCtx = struct {
    const Self = @This();

    chars: []const u8,
    chars_hash: u32,

    pub fn init(chars: []const u8, c_hash: u32) Self {
        return AdaptedCtx {
            .chars_hash = c_hash, .chars = chars
        };
    }

    pub fn hash(self: AdaptedCtx, _: @TypeOf(void)) u64 {
        return self.chars_hash;
    }

    pub fn eql(self: Self, _: @TypeOf(void), key: *ObjString) bool {
        return self.chars_hash == key.*.hash and std.mem.eql(u8, key.*.chars, self.chars);
    }
};

// TODO: Fix strings containing ""
pub const ObjString = struct {
    obj: Obj,
    length: usize,
    chars: []const u8,
    hash: u32,

    pub fn allocateString(chars: []const u8, vm: *VM, hash: u32) *ObjString {
        const tmp = Obj.allocateObj(vm, .obj_string, ObjString, hash);
        const string = tmp.asObjString();

        string.length = chars.len;
        string.chars = chars;

        vm.strings.put(string, .nil) catch {
            std.debug.print("Error: Out of Memory\n",.{});
            std.process.exit(200);
        };

        return string;
    }

    pub fn free(self: *ObjString) void {
        allocator.free(self.chars);
        allocator.destroy(self);
    }

    pub fn copy(src: []const u8, vm: *VM) *ObjString {
        const hash = hashFn(src);

        const dest = allocator.alloc(u8, src.len) catch {
            std.debug.print("Error allocating string!\n", .{});
            std.process.exit(200);
        };
        std.mem.copyForwards(u8, dest, src);
        
        if (vm.strings.getKeyAdapted(void, AdaptedCtx.init(src, hash))) |interned| {
            allocator.free(src);
            return interned;
        }
        
        return allocateString(dest, vm, hash);
    }
};
