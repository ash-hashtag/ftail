const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    var args = std.process.args();
    _ = args.skip();
    var number_of_lines: usize = 10;
    const file_or_option_nullable = args.next();
    if (file_or_option_nullable == null) {
        try print_help();
        return;
    }
    const file_or_option = file_or_option_nullable.?;
    var stdout_enum: u8 = 0;
    if (file_or_option.len > 0 and file_or_option[0] == '-') {
        for (file_or_option[1..]) |option| {
            switch (option) {
                'n' => {
                    number_of_lines = try std.fmt.parseInt(usize, args.next().?, 10);
                },
                'c' => {
                    stdout_enum = stdout_enum | @intFromEnum(StdOutEnum.ClearConsole);
                },
                'o' => {
                    stdout_enum = stdout_enum | @intFromEnum(StdOutEnum.StdOut);
                },
                'h' => {
                    try print_help();
                    return;
                },
                'f' => {
                    stdout_enum = stdout_enum | @intFromEnum(StdOutEnum.ToFile);
                },
                else => {
                    try print_help();
                    return;
                },
            }
        }
        // file_or_option_nullable = args.next();
        // if (file_or_option_nullable == null) {
        //     _ = try std.io.getStdErr().write("Missing Output File\n");
        //     return;
        // } else {
        //     file_path = file_or_option_nullable;
        // }
    }

    const file_path = if ((stdout_enum & @intFromEnum(StdOutEnum.ToFile)) == 0) null else args.next();

    var subprocess_args = std.ArrayList([]const u8).init(allocator);
    defer subprocess_args.deinit();
    while (true) {
        const arg = args.next();
        if (arg != null) {
            try subprocess_args.append(arg.?);
        } else {
            break;
        }
    }

    if (subprocess_args.items.len > 0) {
        try spawnProcessAndTailLines(subprocess_args.items.ptr[0..subprocess_args.items.len], allocator, number_of_lines, file_path, stdout_enum);
    } else {
        try tailLines2(allocator, std.io.getStdIn().reader(), file_path, number_of_lines, stdout_enum);
    }
}

fn print_help() !void {
    try std.io.getStdOut().writeAll(
        \\ftail -[OPTION(s)] [OUTPUT_FILE] [SUBPROCESS args]
        \\Description
        \\ Tail a long running process into a file, supports stdin
        \\Options
        \\ n  xx     number of lines (xx) 
        \\           shows all incoming stdin lines,
        \\           default is -n 10
        \\
        \\ c         clears stdout, only shows last n lines
        \\           should be used along with o flag 
        \\ 
        \\ o         output to stdout
        \\
        \\ f         write to file
        \\
        \\ h         print help
        \\ 
        \\ Example Usage:
        \\ echo 'Hello World' | ftail -nc 5 
        \\ echo 'Hello World' | ftail -nof 50 /tmp/out
        \\ ftail -nf 5 /tmp/out printf 'Hello\nWorld\nFoo\nBar\nBaz'
        \\ 
    );
}

fn shiftElementsUp(list: *std.ArrayList([]u8)) []u8 {
    const first_element = list.items[0];
    for (0..list.items.len - 1) |i| {
        list.items[i] = list.items[i + 1];
    }
    _ = list.pop();
    return first_element;
}

fn spawnProcessAndTailLines(args: []const []const u8, allocator: std.mem.Allocator, number_of_lines: usize, output_file_path: ?[]const u8, stdout_enum: u8) !void {
    var child = std.process.Child.init(args, allocator);
    child.stdout_behavior = .Pipe;
    try child.spawn();
    const reader = child.stdout.?.reader();
    try tailLines2(allocator, reader, output_file_path, number_of_lines, stdout_enum);
    _ = try child.wait();
}

const StdOutEnum = enum(u8) {
    None = 1,
    StdOut = 2,
    ClearConsole = 4,
    ToFile = 8,
};

fn tailLines2(allocator: std.mem.Allocator, reader: anytype, output_file_path: ?[]const u8, number_of_lines: usize, stdout_enum: u8) !void {
    var lines = try std.ArrayList([]u8).initCapacity(allocator, number_of_lines);
    defer {
        for (lines.items) |line| {
            allocator.free(line);
        }
        lines.deinit();
    }

    const f = if (output_file_path != null) try std.fs.cwd().createFile(output_file_path.?, .{ .truncate = true }) else null;
    defer {
        if (f != null) {
            f.?.close();
        }
    }

    var file_out = std.ArrayList(u8).init(allocator);
    defer file_out.deinit();
    var new_lines_printed: usize = 0; // :/ couldn't get it to work more cleanly
    var bwriter = std.io.bufferedWriter(std.io.getStdOut().writer());
    var writer = bwriter.writer();
    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096)) |line| {
        // std.time.sleep(std.time.ns_per_s * 1);
        if (number_of_lines <= lines.items.len) {
            allocator.free(shiftElementsUp(&lines));
        }

        if ((stdout_enum & (@intFromEnum(StdOutEnum.StdOut) | @intFromEnum(StdOutEnum.ClearConsole))) != 0) {
            while (new_lines_printed > 0) {
                try writer.print("\x1b[F\x1b[2K\x1b[0G", .{}); // move up clear line move to start of the line
                new_lines_printed -= 1;
            }
        }

        try lines.append(line);
        for (lines.items) |nline| {
            try file_out.appendSlice(nline);
            try file_out.append('\n');
            new_lines_printed += 1;
        }
        const out = file_out.items.ptr[0..file_out.items.len];
        if ((stdout_enum & @intFromEnum(StdOutEnum.StdOut)) != 0) {
            // var bwriter = std.io.bufferedWriter(std.io.getStdOut().writer());
            // var writer = bwriter.writer();
            if ((stdout_enum & @intFromEnum(StdOutEnum.ClearConsole)) != 0) {
                try writer.print("{s}", .{out});
            } else {
                try writer.print("{s}\n", .{line});
            }
            try bwriter.flush();
        }
        if (f != null) {
            const f0 = f.?;
            try f0.seekTo(0);
            try f0.writeAll(out);
            try f0.setEndPos(out.len);
        }
        file_out.clearRetainingCapacity();
    }
}
