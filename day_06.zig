const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const Operator = enum { Plus, Multiply };

fn parsePart1(alloc: Allocator, bytes: []const u8) !struct {
    nums: [][]u64,
    operators: []Operator,
} {
    var nums = std.array_list.Managed([]u64).init(alloc);
    var operators = std.array_list.Managed(Operator).init(alloc);

    var curr_buf: [32]u8 = undefined;
    var curr_buf_len: usize = 0;

    var iter = std.mem.splitScalar(u8, bytes, '\n');
    while (iter.next()) |line| {
        var row: ?*std.array_list.Managed(u64) = null;

        for (line) |ch| {
            switch (ch) {
                '0'...'9' => {
                    if (row == null) {
                        var new_row = std.array_list.Managed(u64).init(alloc);
                        row = &new_row;
                    }

                    curr_buf[curr_buf_len] = ch;
                    curr_buf_len += 1;
                    continue;
                },
                '+' => try operators.append(Operator.Plus),
                '*' => try operators.append(Operator.Multiply),
                ' ' => {},
                else => return error.InvalidInput,
            }

            if (row) |arr| {
                if (curr_buf_len > 0) {
                    try arr.append(try std.fmt.parseInt(u64, curr_buf[0..curr_buf_len], 10));
                    curr_buf_len = 0;
                }
            }
        }

        if (row) |arr| {
            if (curr_buf_len > 0) {
                try arr.append(try std.fmt.parseInt(u64, curr_buf[0..curr_buf_len], 10));
                curr_buf_len = 0;
            }

            try nums.append(try arr.*.toOwnedSlice());
        }
    }

    return .{
        .nums = try nums.toOwnedSlice(),
        .operators = try operators.toOwnedSlice(),
    };
}

fn solvePart1(nums: [][]u64, operators: []Operator) u64 {
    var result: u64 = 0;

    for (0..nums[0].len) |col| {
        var total: u64 = nums[0][col];
        for (1..nums.len) |row| {
            switch (operators[col]) {
                Operator.Plus => total += nums[row][col],
                Operator.Multiply => total *= nums[row][col],
            }
        }
        result += total;
    }

    return result;
}

test "solvePart1" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const tests = [_]struct {
        name: []const u8,
        input: []const u8,
        expected: u64,
    }{
        .{
            .name = "real world",
            .input =
            \\123 328  51 64
            \\ 45 64  387 23
            \\  6 98  215 314
            \\*   +   *   +
            ,
            .expected = 4277556,
        },
    };

    for (tests) |tt| {
        const parse_result = try parsePart1(alloc, tt.input);
        const result = solvePart1(parse_result.nums, parse_result.operators);
        try std.testing.expectEqual(tt.expected, result);
    }
}

fn parsePart2(alloc: Allocator, bytes: []const u8) !struct {
    nums: [][]u64,
    operators: []Operator,
} {
    var nums = std.array_list.Managed([]u64).init(alloc);
    var operators = std.array_list.Managed(Operator).init(alloc);

    var lines_raw = std.array_list.Managed([]const u8).init(alloc);
    var lines_iter = std.mem.splitScalar(u8, bytes, '\n');
    while (lines_iter.next()) |line| {
        try lines_raw.append(line);
    }

    var max_line_len: usize = 0;
    for (lines_raw.items) |line| {
        if (line.len > max_line_len) max_line_len = line.len;
    }
    var lines = try alloc.alloc([]u8, lines_raw.items.len);
    for (lines_raw.items, 0..) |line, i| {
        var buf = try alloc.alloc(u8, max_line_len);
        @memcpy(buf[0..line.len], line);
        @memset(buf[line.len..max_line_len], ' ');
        lines[i] = buf;
    }

    var curr_buf: [32]u8 = undefined;
    var curr_buf_len: usize = 0;
    var curr_operator: ?Operator = null;

    var nums_group = std.array_list.Managed(u64).init(alloc);

    for (0..lines[0].len) |col| {
        // Numbers.
        for (0..lines.len - 1) |row| {
            const ch = lines[row][col];
            switch (ch) {
                '0'...'9' => {
                    curr_buf[curr_buf_len] = ch;
                    curr_buf_len += 1;
                },
                ' ' => {},
                else => unreachable,
            }
        }
        if (curr_buf_len > 0) {
            try nums_group.append(try std.fmt.parseInt(u64, curr_buf[0..curr_buf_len], 10));
            curr_buf_len = 0;
        } else {
            try nums.append(try nums_group.toOwnedSlice());
            try operators.append(curr_operator.?);
            nums_group = std.array_list.Managed(u64).init(alloc);
        }

        // Operator.
        switch (lines[lines.len - 1][col]) {
            '+' => curr_operator = Operator.Plus,
            '*' => curr_operator = Operator.Multiply,
            ' ' => {},
            else => unreachable,
        }
    }

    try nums.append(try nums_group.toOwnedSlice());
    try operators.append(curr_operator.?);

    return .{
        .nums = try nums.toOwnedSlice(),
        .operators = try operators.toOwnedSlice(),
    };
}

fn solvePart2(nums: [][]u64, operators: []Operator) u64 {
    var result: u64 = 0;

    for (0..nums.len) |i| {
        var total: u64 = nums[i][0];
        for (nums[i][1..]) |num| {
            switch (operators[i]) {
                Operator.Plus => total += num,
                Operator.Multiply => total *= num,
            }
        }
        result += total;
    }

    return result;
}

test "solvePart2" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const tests = [_]struct {
        name: []const u8,
        input: []const u8,
        expected: u64,
    }{
        .{
            .name = "real world",
            .input =
            \\123 328  51 64
            \\ 45 64  387 23
            \\  6 98  215 314
            \\*   +   *   +
            ,
            .expected = 3263827,
        },
    };

    for (tests) |tt| {
        const parse_result = try parsePart2(alloc, tt.input);
        const result = solvePart2(parse_result.nums, parse_result.operators);
        try std.testing.expectEqual(tt.expected, result);
    }
}

fn readFile(alloc: Allocator, filename: []const u8) ![]u8 {
    return try std.fs.cwd().readFileAlloc(alloc, filename, std.math.maxInt(usize));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();

    const bytes = try readFile(alloc, "input.txt");

    const parse_result_1 = try parsePart1(alloc, bytes);
    const parse_result_2 = try parsePart2(alloc, bytes);

    print("Part 1: {}\n", .{solvePart1(parse_result_1.nums, parse_result_1.operators)});
    print("Part 2: {}\n", .{solvePart2(parse_result_2.nums, parse_result_2.operators)});
}
