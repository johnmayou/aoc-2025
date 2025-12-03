const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const Range = struct {
    // Inclusive.
    start: u64,
    // Inclusive.
    stop: u64,
};

fn parse(alloc: Allocator, bytes: []const u8) ![]Range {
    var ranges = std.array_list.Managed(Range).init(alloc);

    var iter = std.mem.splitScalar(u8, bytes, ',');
    while (iter.next()) |range_str| {
        var range_iter = std.mem.splitScalar(u8, range_str, '-');

        const start_str = range_iter.next() orelse return error.InvalidRange;
        const start = try std.fmt.parseInt(u64, start_str, 10);

        const stop_str = range_iter.next() orelse return error.InvalidRange;
        const stop = try std.fmt.parseInt(u64, stop_str, 10);

        try ranges.append(.{
            .start = start,
            .stop = stop,
        });
    }

    return try ranges.toOwnedSlice();
}

fn readFile(alloc: Allocator, filename: []const u8) ![]u8 {
    return try std.fs.cwd().readFileAlloc(alloc, filename, std.math.maxInt(usize));
}

fn solvePart1(ranges: []Range) u64 {
    var result: u64 = 0;

    for (ranges) |range| {
        var buf: [20]u8 = undefined;

        var candidate: u64 = range.start;
        while (candidate <= range.stop) : (candidate += 1) {
            const str = std.fmt.bufPrint(&buf, "{}", .{candidate}) catch unreachable;
            if (str.len % 2 != 0) continue;

            if (std.mem.eql(u8, str[0 .. str.len / 2], str[str.len / 2 ..])) {
                result += candidate;
            }
        }
    }

    return result;
}

fn solvePart2(ranges: []Range) u64 {
    var result: u64 = 0;

    for (ranges) |range| {
        var buf: [20]u8 = undefined;

        var candidate: u64 = range.start;
        candidate_loop: while (candidate <= range.stop) : (candidate += 1) {
            const str = std.fmt.bufPrint(&buf, "{}", .{candidate}) catch unreachable;

            var chunk_size: usize = 1;
            chunk_loop: while (chunk_size <= str.len / 2) : (chunk_size += 1) {
                if (str.len % chunk_size != 0) continue;

                // Start at second chunk so we can compare with previous chunk.
                var start = chunk_size;
                while (start < str.len) : (start += chunk_size) {
                    const prev_chunk = str[start - chunk_size .. start];
                    const curr_chunk = str[start .. start + chunk_size];
                    if (!std.mem.eql(u8, prev_chunk, curr_chunk)) {
                        continue :chunk_loop;
                    }
                }

                result += candidate;
                continue :candidate_loop;
            }
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

    const bytes = try readFile(alloc, "input.txt");
    const ranges = try parse(alloc, bytes);

    print("Part 1: {}\n", .{solvePart1(ranges)});
    print("Part 2: {}\n", .{solvePart2(ranges)});
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
            .input = "11-22,95-115,998-1012,1188511880-1188511890,222220-222224,1698522-1698528,446443-446449,38593856-38593862,565653-565659,824824821-824824827,2121212118-2121212124",
            .expected = 1227775554,
        },
    };

    for (cases) |tt| {
        const ranges = try parse(alloc, tt.input);
        const result = solvePart1(ranges);
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
            .input = "11-22,95-115,998-1012,1188511880-1188511890,222220-222224,1698522-1698528,446443-446449,38593856-38593862,565653-565659,824824821-824824827,2121212118-2121212124",
            .expected = 4174379265,
        },
    };

    for (cases) |tt| {
        const ranges = try parse(alloc, tt.input);
        const result = solvePart2(ranges);
        try std.testing.expectEqual(tt.expected, result);
    }
}
