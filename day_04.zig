const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

pub fn Queue(comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = struct {
            val: T,
            next: ?*Node,
        };

        alloc: Allocator,
        head: *Node,
        tail: *Node,

        pub fn init(alloc: Allocator) !Self {
            const head = try alloc.create(Node);
            head.* = .{ .val = undefined, .next = null };

            return Self{
                .alloc = alloc,
                .head = head,
                .tail = head,
            };
        }

        pub fn deinit(self: *Self) void {
            var curr: ?*Node = self.head;
            while (curr) |node| {
                const next = node.next;
                self.alloc.destroy(node);
                curr = next;
            }
        }

        pub fn enqueue(self: *Self, val: T) !void {
            const node = try self.alloc.create(Node);
            node.* = .{ .val = val, .next = null };

            self.tail.next = node;
            self.tail = node;
        }

        pub fn dequeue(self: *Self) ?T {
            const node = self.head.next orelse return null;
            defer self.alloc.destroy(node);

            self.head.next = node.next;
            if (self.head.next == null) {
                self.tail = self.head;
            }

            return node.val;
        }

        pub fn empty(self: *Self) bool {
            return self.head == self.tail;
        }
    };
}

test "Queue" {
    var queue = try Queue(u4).init(std.testing.allocator);
    defer queue.deinit();

    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);

    try std.testing.expectEqual(queue.dequeue(), 1);
    try std.testing.expectEqual(queue.dequeue(), 2);
    try std.testing.expectEqual(queue.dequeue(), 3);
    try std.testing.expectEqual(queue.dequeue(), null);

    try queue.enqueue(4);

    try std.testing.expectEqual(queue.dequeue(), 4);
    try std.testing.expectEqual(queue.dequeue(), null);
}

fn AdjCounter() type {
    return struct {
        const Self = @This();
        const DirectionDelta = struct {
            // Delta row.
            dr: isize,
            // Delta column.
            dc: isize,
        };

        const directions = [_]DirectionDelta{
            .{ .dr = -1, .dc = -1 },
            .{ .dr = -1, .dc = 0 },
            .{ .dr = -1, .dc = 1 },
            .{ .dr = 0, .dc = 1 },
            .{ .dr = 1, .dc = 1 },
            .{ .dr = 1, .dc = 0 },
            .{ .dr = 1, .dc = -1 },
            .{ .dr = 0, .dc = -1 },
        };

        grid: [][]u8,
        n_rows: usize,
        n_cols: usize,

        pub fn init(grid: [][]u8) Self {
            return Self{
                .grid = grid,
                .n_rows = grid.len,
                .n_cols = if (grid.len > 0) grid[0].len else 0,
            };
        }

        /// Counts how many neighboring cells around `(row, col)` match `target`.
        pub fn countAdj(self: *const Self, row: usize, col: usize, target: u8) u4 {
            var count: u4 = 0;

            const n_rows_i: isize = @intCast(self.n_rows);
            const n_cols_i: isize = @intCast(self.n_cols);

            const row_i: isize = @intCast(row);
            const col_i: isize = @intCast(col);

            for (directions) |delta| {
                const r = row_i + delta.dr;
                const c = col_i + delta.dc;

                if (r < 0 or r >= n_rows_i) continue;
                if (c < 0 or c >= n_cols_i) continue;

                const rr: usize = @intCast(r);
                const cc: usize = @intCast(c);

                if (self.grid[rr][cc] == target) count += 1;
            }

            return count;
        }
    };
}

test "AdjCounter" {
    const alloc = std.testing.allocator;

    var grid = try alloc.alloc([]u8, 3);
    defer {
        for (grid) |row| {
            alloc.free(row);
        }
        alloc.free(grid);
    }
    grid[0] = try alloc.dupe(u8, "xxx");
    grid[1] = try alloc.dupe(u8, "x.x");
    grid[2] = try alloc.dupe(u8, "xxx");

    const tests = [_]struct {
        row: usize,
        col: usize,
        expected: u4,
    }{
        .{ .row = 0, .col = 0, .expected = 2 },
        .{ .row = 0, .col = 1, .expected = 4 },
        .{ .row = 0, .col = 2, .expected = 2 },

        .{ .row = 1, .col = 0, .expected = 4 },
        .{ .row = 1, .col = 1, .expected = 8 },
        .{ .row = 1, .col = 2, .expected = 4 },

        .{ .row = 2, .col = 0, .expected = 2 },
        .{ .row = 2, .col = 1, .expected = 4 },
        .{ .row = 2, .col = 2, .expected = 2 },
    };

    const adj_counter = AdjCounter().init(grid[0..]);
    for (tests) |tt| {
        try std.testing.expectEqual(tt.expected, adj_counter.countAdj(tt.row, tt.col, 'x'));
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

fn solvePart1(grid: [][]u8) u64 {
    var result: u64 = 0;

    const n_rows = grid.len;
    const n_cols = grid[0].len;
    var adj_counter = AdjCounter().init(grid);

    for (0..n_rows) |r| {
        for (0..n_cols) |c| {
            if (grid[r][c] == '@' and adj_counter.countAdj(r, c, '@') < 4) {
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
            \\..@@.@@@@.
            \\@@@.@.@.@@
            \\@@@@@.@.@@
            \\@.@@@@..@.
            \\@@.@@@@.@@
            \\.@@@@@@@.@
            \\.@.@.@.@@@
            \\@.@@@.@@@@
            \\.@@@@@@@@.
            \\@.@.@@@.@.
            ,
            .expected = 13,
        },
    };

    for (tests) |tt| {
        const grid = try splitLines(alloc, tt.input);
        const result = solvePart1(grid);
        try std.testing.expectEqual(tt.expected, result);
    }
}

fn solvePart2(alloc: Allocator, grid: [][]u8) !u64 {
    var result: u64 = 0;

    const n_rows = grid.len;
    const n_cols = grid[0].len;
    var adj_counter = AdjCounter().init(grid);
    var remove_queue = try Queue(struct { r: usize, c: usize }).init(alloc);

    // Enqueue all initial removable rolls.
    for (0..n_rows) |r| {
        for (0..n_cols) |c| {
            if (grid[r][c] == '@' and adj_counter.countAdj(r, c, '@') < 4) {
                try remove_queue.enqueue(.{ .r = r, .c = c });
            }
        }
    }

    // For every removable roll, remove the roll, then check if any neighbors
    // are now removable.
    while (!remove_queue.empty()) {
        const pos = remove_queue.dequeue().?;

        // Skip if already removed.
        if (grid[pos.r][pos.c] != '@') continue;

        // Remove the roll.
        grid[pos.r][pos.c] = '.';
        result += 1;

        // Neighbors may now be removable, check if any are.
        for (AdjCounter().directions) |delta| {
            const r = @as(isize, @intCast(pos.r)) + delta.dr;
            const c = @as(isize, @intCast(pos.c)) + delta.dc;

            if (r < 0 or r >= @as(isize, @intCast(n_rows))) continue;
            if (c < 0 or c >= @as(isize, @intCast(n_cols))) continue;

            const r_usize: usize = @intCast(r);
            const c_usize: usize = @intCast(c);

            // If neighbor is removable, add it to the queue.
            if (grid[r_usize][c_usize] == '@' and adj_counter.countAdj(r_usize, c_usize, '@') < 4) {
                try remove_queue.enqueue(.{ .r = r_usize, .c = c_usize });
            }
        }
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
            \\..@@.@@@@.
            \\@@@.@.@.@@
            \\@@@@@.@.@@
            \\@.@@@@..@.
            \\@@.@@@@.@@
            \\.@@@@@@@.@
            \\.@.@.@.@@@
            \\@.@@@.@@@@
            \\.@@@@@@@@.
            \\@.@.@@@.@.
            ,
            .expected = 43,
        },
    };

    for (tests) |tt| {
        const grid = try splitLines(alloc, tt.input);
        const result = try solvePart2(alloc, grid);
        try std.testing.expectEqual(tt.expected, result);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();

    const grid = try splitLines(alloc, try readFile(alloc, "input.txt"));

    print("Part 1: {}\n", .{solvePart1(grid)});
    print("Part 2: {}\n", .{try solvePart2(alloc, grid)});
}
