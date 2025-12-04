const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

fn readFile(alloc: Allocator, filename: []const u8) ![]u8 {
    return try std.fs.cwd().readFileAlloc(alloc, filename, std.math.maxInt(usize));
}

fn splitLines(alloc: Allocator, bytes: []const u8) ![][]const u8 {
    var list = std.array_list.Managed([]const u8).init(alloc);
    var iter = std.mem.splitScalar(u8, bytes, '\n');
    while (iter.next()) |line| {
        try list.append(line);
    }
    return try list.toOwnedSlice();
}

fn solvePart1(lines: [][]const u8) u64 {
    var result: u64 = 0;

    for (lines) |line| {
        // These keep track of the digits that make up the largest possible 2-digit
        // integer where the second digit (`digit2`) appears after the first (`digit1`).
        var digit1 = line[0];
        var digit2 = line[1];

        var i: usize = 1;
        while (i < line.len) : (i += 1) {
            const ch = line[i];
            // If this is the last char, regardless if it's larger than `digit1`, there
            // is nothing to replace `digit2` with, thus we do not enter the conditional.
            if (i != line.len - 1 and ch > digit1) {
                digit1 = ch;
                digit2 = line[i + 1];
            } else if (ch > digit2) {
                digit2 = ch;
            }
        }

        const digit1_int = digit1 - '0';
        const digit2_int = digit2 - '0';
        result += (digit1_int * 10) + digit2_int;
    }

    return result;
}

fn solvePart2(comptime N: usize, lines: [][]const u8) u64 {
    var result: u64 = 0;

    for (lines) |line| {
        // We'll use a stack to keep track of the `N` digits that make up the largest
        // resulting integer while preserving the left to right order of the input.
        var stack: [N]u8 = undefined;
        var stack_len: usize = 0;

        for (line, 0..) |ch, i| {
            // Number of chars remaning in the line. Includes current char.
            var remaining_chars = line.len - i;

            const remaining_stack_capacity = N - stack_len;

            // Try to replace x number of digits with `ch` if doing so produces a larger
            // resulting integer *and* we still have enough characters left in the input
            // to eventually fill a full `N`-digit stack.
            //
            // Example (N = 2, line = "123"):
            //
            //   i=1 -> '2', stack = ['1']
            //   - remaining_chars = 2 > 1 = remaining_stack_capacity
            //   - '2' > '1'
            //   -> pop '1', then later push '2', eventually resulting in ['2', '3']
            //
            while (stack_len > 0 and remaining_chars > remaining_stack_capacity and ch > stack[stack_len - 1]) {
                stack_len -= 1;
                remaining_chars -= 1;
            }

            // Push current char if we have room on the stack.
            if (stack_len < N) {
                stack[stack_len] = ch;
                stack_len += 1;
            }
        }

        // Convert string digits to integer.
        var value: u64 = 0;
        for (stack[0..stack_len]) |digit| {
            value = value * 10 + (digit - '0');
        }

        result += value;
    }

    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();

    const lines = try splitLines(alloc, try readFile(alloc, "input.txt"));

    print("Part 1: {}\n", .{solvePart1(lines)});
    print("Part 2: {}\n", .{solvePart2(12, lines)});
}

test "solvePart1" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const cases = [_]struct {
        name: []const u8,
        input: []const u8,
        expected: u64,
    }{
        .{
            .name = "real world",
            .input =
            \\987654321111111
            \\811111111111119
            \\234234234234278
            \\818181911112111
            ,
            .expected = 357,
        },
    };

    for (cases) |tt| {
        const lines = try splitLines(alloc, tt.input);
        const result = solvePart1(lines);
        try std.testing.expectEqual(tt.expected, result);
    }
}

test "solvePart2" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const cases = [_]struct {
        name: []const u8,
        input: []const u8,
        expected: u64,
    }{
        .{
            .name = "real world",
            .input =
            \\987654321111111
            \\811111111111119
            \\234234234234278
            \\818181911112111
            ,
            .expected = 3121910778619,
        },
    };

    for (cases) |tt| {
        const lines = try splitLines(alloc, tt.input);
        const result = solvePart2(12, lines);
        try std.testing.expectEqual(tt.expected, result);
    }
}
