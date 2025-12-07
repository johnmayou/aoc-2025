const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const Range = struct {
    // Inclusive.
    start: u64,
    // Inclusive.
    end: u64,
};

const ParseResult = struct {
    ranges: []Range,
    ingredients: []u64,
};

fn parse(alloc: Allocator, bytes: []const u8) !ParseResult {
    var ranges = std.array_list.Managed(Range).init(alloc);
    var ingredients = std.array_list.Managed(u64).init(alloc);

    var in_ranges = true;

    var iter = std.mem.splitScalar(u8, bytes, '\n');
    while (iter.next()) |line| {
        if (std.mem.eql(u8, line, "")) {
            in_ranges = false;
            continue;
        }

        if (in_ranges) {
            var range_iter = std.mem.splitScalar(u8, line, '-');

            const start_str = range_iter.next() orelse return error.InvalidRange;
            const start = try std.fmt.parseInt(u64, start_str, 10);

            const end_str = range_iter.next() orelse return error.InvalidRange;
            const end = try std.fmt.parseInt(u64, end_str, 10);

            try ranges.append(.{
                .start = start,
                .end = end,
            });
        } else {
            const ingredient = try std.fmt.parseInt(u64, line, 10);
            try ingredients.append(ingredient);
        }
    }

    return ParseResult{
        .ranges = try ranges.toOwnedSlice(),
        .ingredients = try ingredients.toOwnedSlice(),
    };
}

fn readFile(alloc: Allocator, filename: []const u8) ![]u8 {
    return try std.fs.cwd().readFileAlloc(alloc, filename, std.math.maxInt(usize));
}

fn normalizeRanges(alloc: Allocator, ranges: []const Range) ![]Range {
    var normalized = std.array_list.Managed(Range).init(alloc);

    // Create a mutable copy to sort.
    var ranges_buf = try alloc.alloc(Range, ranges.len);
    defer alloc.free(ranges_buf);
    std.mem.copyForwards(Range, ranges_buf, ranges);
    std.mem.sort(Range, ranges_buf, {}, (struct {
        fn lessThan(_: void, a: Range, b: Range) bool {
            return a.start < b.start;
        }
    }).lessThan);

    try normalized.append(ranges_buf[0]);
    for (ranges_buf[1..]) |curr| {
        var last = &normalized.items[normalized.items.len - 1];

        if (curr.start - 1 <= last.end) {
            last.end = @max(last.end, curr.end);
        } else {
            try normalized.append(curr);
        }
    }

    return normalized.toOwnedSlice();
}

test "normalizeRanges" {
    const tests = [_]struct {
        name: []const u8,
        input: []const Range,
        expected: []const Range,
    }{
        .{
            .name = "combines overlapping ranges",
            .input = &[_]Range{
                .{ .start = 0, .end = 2 },
                .{ .start = 1, .end = 3 },
            },
            .expected = &[_]Range{
                .{ .start = 0, .end = 3 },
            },
        },
        .{
            .name = "combines touching ranges",
            .input = &[_]Range{
                .{ .start = 0, .end = 1 },
                .{ .start = 1, .end = 2 },
            },
            .expected = &[_]Range{
                .{ .start = 0, .end = 2 },
            },
        },
        .{
            .name = "does not combine non-touching ranges",
            .input = &[_]Range{
                .{ .start = 0, .end = 1 },
                .{ .start = 3, .end = 4 },
            },
            .expected = &[_]Range{
                .{ .start = 0, .end = 1 },
                .{ .start = 3, .end = 4 },
            },
        },
    };

    for (tests) |tt| {
        const actual = try normalizeRanges(std.testing.allocator, tt.input);
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualSlices(Range, tt.expected, actual);
    }
}

fn solvePart1(alloc: Allocator, ranges: []Range, ingredients: []u64) !u64 {
    var result: u64 = 0;

    const nranges = try normalizeRanges(alloc, ranges);

    for (ingredients) |ingredient| {
        var l: usize = 0;
        var r: usize = nranges.len;
        while (l < r) {
            const m = l + (r - l) / 2;
            if (nranges[m].start <= ingredient) {
                l = m + 1;
            } else {
                r = m;
            }
        }

        if (l > 0) {
            const i = l - 1;
            if (nranges[i].start <= ingredient and ingredient <= nranges[i].end) {
                result += 1;
            }
        }
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
            \\3-5
            \\10-14
            \\16-20
            \\12-18
            \\
            \\1
            \\5
            \\8
            \\11
            \\17
            \\32
            ,
            .expected = 3,
        },
    };

    for (tests) |tt| {
        const parse_result = try parse(alloc, tt.input);
        const result = try solvePart1(alloc, parse_result.ranges, parse_result.ingredients);
        try std.testing.expectEqual(tt.expected, result);
    }
}

fn solvePart2(alloc: Allocator, ranges: []Range) !u64 {
    var result: u64 = 0;

    const nranges = try normalizeRanges(alloc, ranges);
    for (nranges) |range| {
        result += range.end - range.start + 1;
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
            \\3-5
            \\10-14
            \\16-20
            \\12-18
            \\
            \\1
            \\5
            \\8
            \\11
            \\17
            \\32
            ,
            .expected = 14,
        },
    };

    for (tests) |tt| {
        const parse_result = try parse(alloc, tt.input);
        const result = try solvePart2(alloc, parse_result.ranges);
        try std.testing.expectEqual(tt.expected, result);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();

    const bytes = try readFile(alloc, "input.txt");
    const parse_result = try parse(alloc, bytes);

    print("Part 1: {}\n", .{try solvePart1(
        alloc,
        parse_result.ranges,
        parse_result.ingredients,
    )});
    print("Part 2: {}\n", .{try solvePart2(
        alloc,
        parse_result.ranges,
    )});
}
