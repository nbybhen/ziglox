const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const builtin = @import("builtin");
const InterpretResult = @import("vm.zig").InterpretResult;
const VM = @import("vm.zig").VM;

const allocator = std.heap.page_allocator;
const DELIMITER = if (builtin.os.tag == .windows) '\r' else '\n';

fn interpret(source: []u8) Error!void{
    std.debug.print("Source: {s}\n", .{source});
}

const Error = InterpretResult || std.fs.File.WriteError;

fn repl() Error!void {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();

    while (true) {
        var input = std.ArrayList(u8).init(allocator);
        defer input.deinit();

        try stdout.writeAll(
            "> "
        );

        stdin.reader().streamUntilDelimiter(input.writer(), DELIMITER, null) catch |e| switch (e) {
                    error.EndOfStream => break,
                    else => unreachable,
        };

        const line = if (builtin.os.tag == .windows)
            std.mem.trimLeft(u8, input.items, "\n")
        else
            input;

        // Quits REPL
        if (std.mem.eql(u8, line.items, ":q")) {
            break;
        }

        try interpret(input.items);
    }
}

fn runFile(path: []u8) !void {
    const handle = std.fs.cwd().openFile(path, .{}) catch |e| switch (e) {
        error.FileNotFound => {
            std.debug.print("Error: Could not open file {s}.\n", .{path});
            std.process.exit(74);
        },
        else => unreachable
    };
    defer handle.close();

    var buffer: [64]u8 = undefined;
    _ = try handle.readAll(&buffer);

    var vm = VM.init();

    _ = vm.interpret(&buffer) catch |e| switch(e) {
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

pub fn main() !void {
    var chunk = Chunk.init();
    defer chunk.free();

    var vm = VM.init();
    defer vm.free();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try switch (args.len) {
        1 => repl(),
        2 => runFile(args[1]),
        else => {
            std.debug.print("Usage: zlox [path]\n", .{});
            std.process.exit(64);
        },
    };

    // std.debug.print("Arguments: {s}", .{args});

    // var constant = try chunk.addConstant(1.2);
    // try chunk.writeOp(.op_constant, 123);
    // try chunk.write(constant, 123);

    // constant = try chunk.addConstant(3.4);
    // try chunk.writeOp(.op_constant, 123);
    // try chunk.write(constant, 123);

    // try chunk.writeOp(.op_add, 123);

    // constant = try chunk.addConstant(5.6);
    // try chunk.writeOp(.op_constant, 123);
    // try chunk.write(constant, 123);

    // try chunk.writeOp(.op_div, 123);
    // try chunk.writeOp(.op_negate, 123);
    // try chunk.writeOp(.op_return, 123);

    // chunk.disassemble("test");
    // try vm.interpret(chunk);
}
