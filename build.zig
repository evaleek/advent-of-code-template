const default_year = 2025;

pub fn build(b: *Build) error{OutOfMemory}!void {
    const target = b.standardTargetOptions(.{});

    const run = b.step("run", "Run solution(s)");

    const days_option = b.option(
        []const u8,
        "day",
        "Specify the solution days, end inclusive ('5', '1..7', '..12')",
    );
    const year: u16 = b.option(
        u16,
        "year",
        b.fmt("Specify the solution year (default: {s})", .{ default_year }),
    ) orelse default_year;

    if (days_option) |days_string| {
        if (parseIntRange(b.allocator, days_string, Day)) |days| {
            defer b.allocator.free(days);

        } else |err| {
            const fail = b.addFail( switch (err) {
                error.OutOfMemory => return err,
                error.Overflow => b.fmt("Out-of-range integer in string '{s}'", .{ days_string }),
                error.InvalidCharacter => b.fmt("Invalid range string '{s}'", .{ days_string }),
            });
            run.dependOn(&fail.step);
        }
    } else {
        const fail = b.addFail("Please specify which day(s) to attempt solving (-Dday)");
        run.dependOn(&fail.step);
    }

    _ = year;
    _ = target;
}

/// End-inclusive, optionally implicit start at 1, integer range syntax parsing.
/// Caller must free the returned slice (even if `len==1`).
fn parseIntRange(
    allocator: Allocator,
    string: []const u8,
    comptime T: type,
) (fmt.ParseIntError||Allocator.Error)![]const T {
    const dot_index: ?usize = for (string, 0..) |char, i| {
        if (char == '.') break i;
    } else null;
    if (dot_index) |first_dot_index| {
        if (first_dot_index == 0 and string[1] == '.') {
            const int = try fmt.parseUnsigned(T, string[2..], 10);
            const list = try allocator.alloc(T, int);
            for (list, 1..) |*day, i| day.* = @intCast(i);
            return list;
        } else if (string.len > first_dot_index+2 and string[first_dot_index+1] == '.') {
            const first = try fmt.parseUnsigned(T, string[0..first_dot_index], 10);
            const last = try fmt.parseUnsigned(T, string[first_dot_index+2..], 10);
            if (last > first) {
                const list = try allocator.alloc(T, last-first+1);
                for (list, first..) |*day, i| day.* = @intCast(i);
                return list;
            } else {
                return error.InvalidCharacter;
            }
        } else {
            return error.InvalidCharacter;
        }
    } else {
        const int = try fmt.parseUnsigned(T, string, 10);
        const list = try allocator.alloc(T, 1);
        list[0] = int;
        return list;
    }
}

test parseIntRange {
    const allocator = testing.allocator;
    {
        const expected: []const u8 = &.{ 82 };
        const actual: []const u8 = try parseIntRange(allocator, "82", u8);
        try testing.expectEqualDeep(expected, actual);
        allocator.free(actual);
    }
    {
        const expected: []const u8 = &.{ 3, 4, 5 };
        const actual: []const u8 = try parseIntRange(allocator, "3..5", u8);
        try testing.expectEqualDeep(expected, actual);
        allocator.free(actual);
    }
    {
        const expected: []const u8 = &.{ 1, 2, 3, 4, 5, 6 };
        const actual: []const u8 = try parseIntRange(allocator, "..6", u8);
        try testing.expectEqualDeep(expected, actual);
        allocator.free(actual);
    }
    try testing.expectError(error.InvalidCharacter, parseIntRange(allocator, "4..4", u8));
    try testing.expectError(error.InvalidCharacter, parseIntRange(allocator, "5..4", u8));
    try testing.expectError(error.InvalidCharacter, parseIntRange(allocator, "3.4", u8));
    try testing.expectError(error.InvalidCharacter, parseIntRange(allocator, "f..oo", u8));
    try testing.expectError(error.InvalidCharacter, parseIntRange(allocator, "5...4", u8));
    try testing.expectError(error.Overflow, parseIntRange(allocator, "256", u8));
}

const Day = u8;

const Problem = struct {
    year: u12,
    day: u8,

    pub const start_year = 2015;
};

const testing = std.testing;
const fmt = std.fmt;
const Allocator = std.mem.Allocator;
const Build = std.Build;
const std = @import("std");
