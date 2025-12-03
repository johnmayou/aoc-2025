const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

fn parse(alloc: Allocator, lines: [][]const u8) ![]i32 {
    var spins = try alloc.alloc(i32, lines.len);

    for (lines, 0..) |line, i| {
        if (line.len == 0) continue;

        const raw_amount = try std.fmt.parseInt(i32, line[1..], 10);
        const amount = switch (line[0]) {
            'L' => -raw_amount,
            'R' => raw_amount,
            else => return error.InvalidDirection,
        };

        spins[i] = amount;
    }

    return spins;
}

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

fn solvePart1(spins: []const i32) u32 {
    var result: u32 = 0;
    var dial: i32 = 50;

    for (spins) |amount| {
        dial += @rem(amount, 100);
        dial = @mod(dial, 100);
        if (dial == 0) {
            result += 1;
        }
    }

    return result;
}

fn solvePart2(spins: []const i32) u32 {
    var result: u32 = 0;
    var dial: i32 = 50;

    for (spins) |amount| {
        const dial_start = dial;

        dial += @rem(amount, 100);
        result += @abs(amount) / 100;

        // If we started at 0, then the next normalization step (wrapping) does not truly pass zero, thus we don't count it.
        if (dial_start != 0 and (dial < 0 or dial > 100)) {
            result += 1;
        }
        dial = @mod(dial, 100);

        if (dial == 0) {
            result += 1;
        }
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
    const spins = try parse(alloc, lines);

    print("Part 1: {}\n", .{solvePart1(spins)});
    print("Part 2: {}\n", .{solvePart2(spins)});
}

test "solvePart1" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const cases = [_]struct {
        name: []const u8,
        input: []const u8,
        expected: u32,
    }{
        .{
            .name = "real world",
            .input =
            \\L68
            \\L30
            \\R48
            \\L5
            \\R60
            \\L55
            \\L1
            \\L99
            \\R14
            \\L82
            ,
            .expected = 3,
        },
    };

    for (cases) |tt| {
        const lines = try splitLines(alloc, tt.input);
        const spins = try parse(alloc, lines);
        const result = solvePart1(spins);
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
        expected: u32,
    }{
        .{
            .name = "real world",
            .input =
            \\L68
            \\L30
            \\R48
            \\L5
            \\R60
            \\L55
            \\L1
            \\L99
            \\R14
            \\L82
            ,
            .expected = 6,
        },
    };

    for (cases) |tt| {
        const lines = try splitLines(alloc, tt.input);
        const spins = try parse(alloc, lines);
        const result = solvePart2(spins);
        try std.testing.expectEqual(tt.expected, result);
    }
}
