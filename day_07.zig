const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const BitSet = struct {
    const Self = @This();

    n: usize,
    bits: []u8,
    alloc: Allocator,

    pub fn init(alloc: Allocator, n: usize) !Self {
        const nbytes = (n + 7) / 8;
        const bits = try alloc.alloc(u8, nbytes);
        @memset(bits, 0);

        return BitSet{
            .n = n,
            .bits = bits,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Self) void {
        self.alloc.free(self.bits);
    }

    pub fn set(self: *Self, i: usize) void {
        self.bits[i >> 3] |= @as(u8, 1) << @intCast(i & 7);
    }

    pub fn unset(self: *Self, i: usize) void {
        self.bits[i >> 3] &= ~(@as(u8, 1) << @intCast(i & 7));
    }

    pub fn get(self: *const Self, i: usize) bool {
        return (self.bits[i >> 3] & (@as(u8, 1) << @intCast(i & 7))) != 0;
    }

    pub fn reset(self: *Self) void {
        for (self.bits) |*byte| byte.* = 0;
    }

    pub fn format(self: *const Self, writer: *std.Io.Writer) !void {
        for (0..self.n) |i| {
            try writer.writeByte(if (self.get(i)) '1' else '0');
        }
    }
};

test "BitSet" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    var bitset = try BitSet.init(alloc, 12);
    defer bitset.deinit();

    const expect_on = struct {
        fn func(bset: *BitSet, comptime on: []const usize, count: usize) !void {
            for (0..count) |i| {
                const actual = bset.get(i);
                const expected = blk: {
                    var found = false;
                    inline for (on) |v| {
                        if (v == i) {
                            found = true;
                            break;
                        }
                    }
                    break :blk found;
                };
                std.testing.expectEqual(expected, actual) catch |err| {
                    print("bit {} expected {} but got {}: {f}\n", .{ i, expected, actual, bset });
                    return err;
                };
            }
        }
    }.func;

    inline for (0..12) |i| {
        bitset.set(i);
        try expect_on(&bitset, &[_]usize{i}, 12);

        bitset.unset(i);
        try expect_on(&bitset, &[_]usize{}, 12);
    }

    bitset.set(0);
    bitset.set(3);
    bitset.set(6);
    bitset.set(9);

    try expect_on(&bitset, &[_]usize{ 0, 3, 6, 9 }, 12);

    bitset.unset(0);
    bitset.unset(6);

    try expect_on(&bitset, &[_]usize{ 3, 9 }, 12);

    bitset.reset();

    try expect_on(&bitset, &[_]usize{}, 12);

    bitset.set(3);

    var buf: [12]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, "{f}", .{bitset});
    try std.testing.expectEqualStrings("000100000000", s);
}

fn solvePart1(alloc: Allocator, lines: [][]u8) !u64 {
    var result: u64 = 0;

    var p = try BitSet.init(alloc, lines[0].len);
    var c = try BitSet.init(alloc, lines[0].len);
    var prev = &p;
    var curr = &c;

    for (lines[0], 0..) |ch, i| {
        switch (ch) {
            'S' => {
                prev.set(i);
                break;
            },
            '.' => {},
            else => unreachable,
        }
    }

    for (lines[1..]) |line| {
        for (0..line.len) |i| {
            switch (line[i]) {
                '^' => {
                    if (prev.get(i)) {
                        if (i > 0) curr.set(i - 1);
                        if (i + 1 < line.len) curr.set(i + 1);
                        result += 1;
                    }
                },
                '.' => {
                    if (prev.get(i)) curr.set(i);
                },
                else => unreachable,
            }
        }

        std.mem.swap(*BitSet, &prev, &curr);
        curr.reset();
    }

    return result;
}

test "solvePart1" {
    const tests = [_]struct {
        name: []const u8,
        input: []const u8,
        expected: u64,
    }{
        .{
            .name = "real world",
            .input =
            \\.......S.......
            \\...............
            \\.......^.......
            \\...............
            \\......^.^......
            \\...............
            \\.....^.^.^.....
            \\...............
            \\....^.^...^....
            \\...............
            \\...^.^...^.^...
            \\...............
            \\..^...^.....^..
            \\...............
            \\.^.^.^.^.^...^.
            \\...............
            ,
            .expected = 21,
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    for (tests) |tt| {
        const lines = try splitLines(alloc, tt.input);
        const result = try solvePart1(alloc, lines);
        try std.testing.expectEqual(tt.expected, result);
    }
}

fn solvePart2(alloc: Allocator, lines: [][]u8) !u64 {
    var p = try alloc.alloc(u64, lines[0].len);
    var c = try alloc.alloc(u64, lines[0].len);
    var prev = &p;
    var curr = &c;
    @memset(p, 0);
    @memset(c, 0);

    for (lines[0], 0..) |ch, i| {
        switch (ch) {
            'S' => {
                prev.*[i] = 1;
                break;
            },
            '.' => {},
            else => unreachable,
        }
    }

    for (lines[1..]) |line| {
        for (0..line.len) |i| {
            const count = prev.*[i];
            if (count == 0) continue;

            switch (line[i]) {
                '^' => {
                    if (i > 0) curr.*[i - 1] += count;
                    if (i + 1 < line.len) curr.*[i + 1] += count;
                },
                '.' => {
                    curr.*[i] += count;
                },
                else => unreachable,
            }
        }

        std.mem.swap(*BitSet, &prev, &curr);
        @memset(curr.*, 0);
    }

    var total: u64 = 0;
    for (prev.*) |v| total += v;
    return total;
}

test "solvePart2" {
    const tests = [_]struct {
        name: []const u8,
        input: []const u8,
        expected: u64,
    }{
        .{
            .name = "real world",
            .input =
            \\.......S.......
            \\...............
            \\.......^.......
            \\...............
            \\......^.^......
            \\...............
            \\.....^.^.^.....
            \\...............
            \\....^.^...^....
            \\...............
            \\...^.^...^.^...
            \\...............
            \\..^...^.....^..
            \\...............
            \\.^.^.^.^.^...^.
            \\...............
            ,
            .expected = 40,
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    for (tests) |tt| {
        const lines = try splitLines(alloc, tt.input);
        const result = try solvePart2(alloc, lines);
        try std.testing.expectEqual(tt.expected, result);
    }
}

fn readFile(alloc: Allocator, filename: []const u8) ![]u8 {
    return try std.fs.cwd().readFileAlloc(alloc, filename, std.math.maxInt(usize));
}

fn splitLines(alloc: Allocator, bytes: []const u8) ![][]u8 {
    var list = std.array_list.Managed([]u8).init(alloc);
    var iter = std.mem.splitScalar(u8, bytes, '\n');
    while (iter.next()) |line| {
        try list.append(try alloc.dupe(u8, line));
    }
    return try list.toOwnedSlice();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();

    const bytes = try readFile(alloc, "input.txt");
    const lines = try splitLines(alloc, bytes);

    print("Part 1: {}\n", .{try solvePart1(alloc, lines)});
    print("Part 2: {}\n", .{try solvePart2(alloc, lines)});
}
