const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const builtin = @import("builtin");
const InterpretResult = @import("vm.zig").InterpretResult;
const VM = @import("vm.zig").VM;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const DELIMITER = if (builtin.os.tag == .windows) '\r' else '\n';

const Error = InterpretResult || std.fs.File.WriteError || std.mem.Allocator.Error;

fn repl(vm: *VM) !void {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();
    var input = try std.ArrayList(u8).initCapacity(allocator, 1);
    defer input.deinit();

    while (true) {
        try stdout.writeAll("> ");

        stdin.reader().streamUntilDelimiter(input.writer(), DELIMITER, null) catch |e| switch (e) {
            error.EndOfStream => break,
            else => unreachable,
        };

        const line = if (builtin.os.tag == .windows)
            std.mem.trimLeft(u8, input.toOwnedSliceSentinel(0), "\n")
        else
            try input.toOwnedSliceSentinel(0);

        // Quits REPL
        if (std.mem.eql(u8, line, ":q")) break;

        _ = vm.interpret(line) catch |e| switch (e) {
            error.CompileErr => {
                std.debug.print("COMPILE_ERR\n", .{});
                std.process.exit(65);
            },
            error.RuntimeErr => {
                std.debug.print("RUNTIME_ERR\n", .{});
                std.process.exit(70);
            },
            else => unreachable,
        };
    }
}

// TODO: Fix "unexpecteed char" bug
fn runFile(path: []u8, vm: *VM) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch |e| switch (e) {
        error.FileNotFound => {
            std.debug.print("Error: Could not open file {s}.\n", .{path});
            std.process.exit(74);
        },
        else => unreachable,
    };
    defer file.close();

    const size = (try file.stat()).size;
    const buffer = try allocator.allocSentinel(u8, size, 0);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    _ = vm.interpret(buffer) catch |e| switch (e) {
        error.CompileErr => {
            std.debug.print("COMPILE_ERR\n", .{});
            std.process.exit(65);
        },
        error.RuntimeErr => {
            std.debug.print("RUNTIME_ERR\n", .{});
            std.process.exit(70);
        },
        else => return e,
    };
}

pub fn main() !void {
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status != .ok) {
            @panic("LEAK!");
        }
    }
    var chunk = Chunk.init();
    defer chunk.free();

    var vm = VM.init();
    defer vm.free();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try switch (args.len) {
        1 => repl(&vm),
        2 => runFile(args[1], &vm),
        else => {
            std.debug.print("Usage: zlox [path]\n", .{});
            std.process.exit(64);
        },
    };
}
