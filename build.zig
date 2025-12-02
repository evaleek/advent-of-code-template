//! A convenience build script for Advent of Code solutions.
//!
//! The directory containing this file is expected as the following layout.
//! Leading zeroes in names are necessary.
//!
//! ```
//! build.zig
//! input/
//!     2015/
//!         day01.txt
//!         day02.txt
//!         ...
//!         i-will-be-ignored.*
//! 2015/
//!     day_01.zig
//!     day_02.zig
//!     ...
//!     i_will_be_ignored_unless_imported.zig
//! ```

/// Increment if out-of-date
pub const current_year = "2025";

pub fn build(b: *Build) error{OutOfMemory}!void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.option(
        OptimizeMode,
        "optimize",
        "Optimization mode for solution executables (default: Debug)",
    ) orelse OptimizeMode.Debug;

    const run_step = b.step("solve", "Run and print solution(s)");
    const test_step = b.step("test", "Run unit tests for solution(s)");

    const day_flag_name = "day";
    const days_option = b.option(
        []const u8,
        day_flag_name,
        "Solution day(s), e.g. '5', '1..7', '..12' (end-inclusive)",
    );
    const year = b.option(
        []const u8,
        "year",
        b.fmt("Solution directory (default: {s})", .{ current_year }),
    ) orelse current_year;
    const timer = b.option(
        bool,
        "time",
        "Print performance time of each solution (default: true)",
    ) orelse true;
    const color = b.option(
        bool,
        "color",
        "Print ANSI color-coded output (default: true)",
    ) orelse true;
    const stop_at_failure = b.option(
        bool,
        "fail-stop",
        "If a solution returns an error, exit (default: false)",
    ) orelse false;
    const part = b.option(
        enum { @"1", @"2", both },
        "part",
        "Select which solution part to run",
    ) orelse .both;

    const write_runner_source = b.addWriteFiles();
    const runner_path = write_runner_source.add("aoc_runner.zig", runner_source);
    const runner_mod = b.createModule(.{
        .root_source_file = runner_path,
        .target = target,
        .optimize = optimize,
    });
    const runner_exe = b.addExecutable(.{
        .name = b.fmt("advent-of-code-{s}", .{year}),
        .root_module = runner_mod,
    });
    runner_exe.step.dependOn(&write_runner_source.step);
    const run_cmd = b.addRunArtifact(runner_exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.setCwd(b.path("./"));

    b.installArtifact(runner_exe);

    const runner_day_options = b.addOptions();
    runner_day_options.addOption(bool, "timer", timer);
    runner_day_options.addOption(bool, "color", color);
    runner_day_options.addOption(bool, "failstop", stop_at_failure);
    runner_day_options.addOption([]const u8, "year", year);
    runner_day_options.addOption(@TypeOf(part), "part", part);
    defer runner_mod.addOptions("days", runner_day_options);

    if (days_option) |days_string| {
        if (parseIntRange(b.allocator, days_string, Day)) |days| {
            defer b.allocator.free(days);

            runner_day_options.addOption(usize, "start", days[0]);
            runner_day_options.addOption(usize, "count", days.len);

            for (days) |day| {
                if (day > 99) break;
                const day_path = b.path(b.fmt("{s}/day_{d:0>2}.zig", .{ year, day }));
                const day_mod = b.createModule(.{
                    .root_source_file = day_path,
                    .target = target,
                    .optimize = optimize,
                });
                runner_mod.addImport(b.fmt("day_{d}", .{day}), day_mod);
                const day_test = b.addTest(.{
                    .name = b.fmt("day-{d}-test", .{day}),
                    .root_module = day_mod,
                });
                const run_day_test = b.addRunArtifact(day_test);
                test_step.dependOn(&run_day_test.step);
            }
        } else |err| {
            const fail = b.addFail( switch (err) {
                error.OutOfMemory => |e| return e,
                error.Overflow => b.fmt("Out-of-range integer in string '{s}'", .{ days_string }),
                error.InvalidCharacter => b.fmt("Invalid range string '{s}'", .{ days_string }),
            });
            run_step.dependOn(&fail.step);
            test_step.dependOn(&fail.step);
        }
    } else {
        const fail = b.addFail("Please select the solution day(s) using -D" ++ day_flag_name);
        run_step.dependOn(&fail.step);
        test_step.dependOn(&fail.step);

        runner_day_options.addOption(usize, "start", 0);
        runner_day_options.addOption(usize, "count", 0);
    }
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
            if (string.len <= 2) return error.InvalidCharacter;
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
    try testing.expectError(error.InvalidCharacter, parseIntRange(allocator, "foo", u8));
    try testing.expectError(error.InvalidCharacter, parseIntRange(allocator, "f..oo", u8));
    try testing.expectError(error.InvalidCharacter, parseIntRange(allocator, "5...4", u8));
    try testing.expectError(error.Overflow, parseIntRange(allocator, "256", u8));
}

pub const Day = u8;

// This allows the entire helper script to live in a single distributable file.
pub const runner_source: [:0]const u8 =
    \\pub fn main() !void {
    \\    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    \\    defer std.debug.assert(debug_allocator.deinit() == .ok);
    \\    const allocator = debug_allocator.allocator();
    \\
    \\    const writer_buffer = try allocator.alloc(u8, 1024);
    \\    defer allocator.free(writer_buffer);
    \\    var stdout = std.fs.File.stdout();
    \\    defer stdout.close();
    \\    var stdout_writer = stdout.writer(writer_buffer);
    \\    const writer = &stdout_writer.interface;
    \\
    \\    const timer_supported = !std.meta.isError(time.Instant.now());
    \\    const use_timer = days.timer and timer_supported;
    \\    if (days.timer and !timer_supported)
    \\        std.log.err("performance timer is unsupported on the host system", .{});
    \\    const color = days.color and @import("builtin").target.os.tag != .windows;
    \\
    \\    const new_io = @hasDecl(std.Io, "File");
    \\    var threaded = if (new_io) std.Io.Threaded.init_single_threaded else {};
    \\    defer { if (new_io) threaded.deinit(); }
    \\    const io = if (new_io) threaded.io() else {};
    \\
    \\    const cwd = std.fs.cwd();
    \\    const rel_path = try std.fmt.allocPrint(allocator, "./input/{s}", .{days.year});
    \\    defer allocator.free(rel_path);
    \\    const sub_path = rel_path[2..];
    \\    const input_dir = cwd.openDir(sub_path, .{}) catch |err| {
    \\        const dir_path = try cwd.realpathAlloc(allocator, ".");
    \\        defer allocator.free(dir_path);
    \\        const path = try std.fmt.allocPrint(allocator, "{s}/input/{s}", .{ dir_path, days.year });
    \\        defer allocator.free(path);
    \\        switch (err) {
    \\            error.FileNotFound, error.NotDir => {
    \\                try writer.print("No input files: expected input directory at\n    {s}\n", .{ path });
    \\                try writer.flush();
    \\                return;
    \\            },
    \\            else => |e| {
    \\                std.log.err("'{s}' access failure: {t}", .{ path, e });
    \\                return err;
    \\            },
    \\        }
    \\    };
    \\
    \\    var total_ns: u64 = 0;
    \\    var failed: u16 = 0;
    \\
    \\    const start = days.start;
    \\    const end = start + days.count;
    \\    iter_days: inline for (start..end) |day| {
    \\        const Day = DayNumberToModule(day);
    \\
    \\        const has_part_1 = @hasDecl(Day, "part1") and @typeInfo(@TypeOf(Day.part1)) == .@"fn";
    \\        const has_part_2 = @hasDecl(Day, "part2") and @typeInfo(@TypeOf(Day.part2)) == .@"fn";
    \\
    \\        if (has_part_1 or has_part_2) {
    \\            const input_file_name = try std.fmt.allocPrint(allocator, "day{d:0>2}.txt", .{day});
    \\            const input_file = input_dir.openFile(input_file_name, .{}) catch |err| err: {
    \\                switch (err) {
    \\                    error.FileNotFound => {
    \\                        if (color) try writer.writeAll("\x1b[36m");
    \\                        try writer.print("[{d:0>2}/*]", .{day});
    \\                        if (color) try writer.writeAll("\x1b[0m");
    \\                        if (color) try writer.writeAll("\x1b[33m");
    \\                        try writer.writeAll("  (missing ");
    \\                        if (color) try writer.writeAll("\x1b[0m");
    \\                        try writer.print("input/{s}", .{input_file_name});
    \\                        if (color) try writer.writeAll("\x1b[33m");
    \\                        try writer.writeAll(")\n");
    \\                        if (color) try writer.writeAll("\x1b[0m");
    \\                        try writer.flush();
    \\                    },
    \\                    else => |e| {
    \\                        const path = try cwd.realpathAlloc(allocator, "./input");
    \\                        defer allocator.free(path);
    \\                        std.log.err("'{s}/{s}' access failure: {t}", .{ path, input_file_name, e });
    \\                    },
    \\                }
    \\                allocator.free(input_file_name);
    \\                break :err null;
    \\            };
    \\            allocator.free(input_file_name);
    \\
    \\            if (input_file) |file| {
    \\                const input_1: []u8 = read_input: {
    \\                    var file_reader = if (new_io) file.reader(io, &.{}) else file.reader(&.{});
    \\                    const reader = &file_reader.interface;
    \\                    break :read_input try reader.allocRemaining(allocator, .unlimited);
    \\                };
    \\                defer allocator.free(input_1);
    \\                file.close();
    \\                const input_2: []u8 = try allocator.alloc(u8, input_1.len);
    \\                defer allocator.free(input_2);
    \\                @memcpy(input_2, input_1);
    \\
    \\                if ((days.part == .@"1" or days.part == .both) and has_part_1) {
    \\                    const result = try runAndPrintSolution(
    \\                        writer,
    \\                        Day.part1,
    \\                        input_1,
    \\                        day,
    \\                        use_timer,
    \\                        color,
    \\                    );
    \\                    try writer.flush();
    \\                    if (result) |ns| {
    \\                        total_ns += ns;
    \\                    } else {
    \\                        failed += 1;
    \\                        if (days.failstop) break :iter_days;
    \\                    }
    \\                }
    \\
    \\                if ((days.part == .@"2" or days.part == .both) and has_part_2) {
    \\                    const result = try runAndPrintSolution(
    \\                        writer,
    \\                        Day.part2,
    \\                        input_2,
    \\                        day,
    \\                        use_timer,
    \\                        color,
    \\                    );
    \\                    try writer.flush();
    \\                    if (result) |ns| {
    \\                        total_ns += ns;
    \\                    } else {
    \\                        failed += 1;
    \\                        if (days.failstop) break :iter_days;
    \\                    }
    \\                }
    \\            }
    \\        } else {
    \\            if (color) try writer.writeAll("\x1b[36m");
    \\            try writer.print("[{d:0>2}/*]", .{ day });
    \\            if (color) try writer.writeAll("\x1b[0m");
    \\            try writer.writeAll("  ");
    \\            if (color) try writer.writeAll("\x1b[33m");
    \\            try writer.writeAll("(missing both parts)");
    \\            if (color) try writer.writeAll("\x1b[0m");
    \\            try writer.writeAll("\n");
    \\        }
    \\    }
    \\
    \\    if (total_ns > 0) {
    \\        try writer.writeAll("Total elapsed solution time: ");
    \\        _ = try printTime(writer, total_ns);
    \\        if (failed > 0) {
    \\            try writer.print(" (excluding {d} failure", .{ failed });
    \\            if (failed > 1) try writer.writeAll("s");
    \\            try writer.writeAll(")");
    \\        }
    \\        try writer.writeAll("\n");
    \\    }
    \\    try writer.flush();
    \\}
    \\
    \\fn runAndPrintSolution(
    \\    writer: *std.Io.Writer,
    \\    solution: anytype,
    \\    input: []u8,
    \\    day: usize,
    \\    use_timer: bool,
    \\    color: bool,
    \\) !?u64 {
    \\    const Solution = @TypeOf(solution);
    \\    if (comptime !isSolutionFn(Solution)) @compileError(std.fmt.comptimePrint(
    \\        "expected a solution function type, found {s}",
    \\        .{ @typeName(Solution) },
    \\    ));
    \\    const Return = @typeInfo(Solution).@"fn".return_type;
    \\    const is_err = if (Return) |R| @typeInfo(R) == .error_union else false;
    \\
    \\    if (use_timer) {
    \\        const part, const nanoseconds = timer: {
    \\            var timer = Timer.start() catch unreachable;
    \\            const answer = solution(input);
    \\            const t = timer.read();
    \\            break :timer .{ answer, t };
    \\        };
    \\
    \\        if (color) try writer.writeAll("\x1b[36m");
    \\        try writer.print("[{d:0>2}/1]", .{day});
    \\        if (color) try writer.writeAll("\x1b[0m");
    \\
    \\        if (is_err) {
    \\            if (part) |answer| {
    \\                try writer.writeAll(" ");
    \\                if (color) try writer.writeAll("\x1b[90m");
    \\                try writer.writeAll("(");
    \\                const fill = try printTime(writer, nanoseconds);
    \\                try writer.writeAll(")");
    \\                if (color) try writer.writeAll("\x1b[0m");
    \\                try writer.splatByteAll(' ', fill);
    \\                try printAnswer(writer, answer);
    \\                return nanoseconds;
    \\            } else |err| {
    \\                try writer.writeAll("  ");
    \\                if (color) try writer.writeAll("\x1b[31m");
    \\                try writer.writeAll("failed");
    \\                if (color) try writer.writeAll("\x1b[0m");
    \\                try writer.print(": {t}\n", .{ err });
    \\                return null;
    \\            }
    \\        } else {
    \\            try writer.writeAll(" ");
    \\            if (color) try writer.writeAll("\x1b[90m");
    \\            try writer.writeAll("(");
    \\            const fill = try printTime(writer, nanoseconds);
    \\            try writer.writeAll(")");
    \\            if (color) try writer.writeAll("\x1b[0m");
    \\            try writer.splatByteAll(' ', fill);
    \\            try printAnswer(writer, part);
    \\            return nanoseconds;
    \\        }
    \\    } else {
    \\        const part = solution(input);
    \\
    \\        if (color) try writer.writeAll("\x1b[36m");
    \\        try writer.print("[{d:0>2}/1]", .{day});
    \\        if (color) try writer.writeAll("\x1b[0m");
    \\
    \\        if (is_err) {
    \\            if (part) |answer| {
    \\                try printAnswer(writer, answer);
    \\        } else |err| {
    \\                try writer.writeAll("  ");
    \\                if (color) try writer.writeAll("\x1b[31m");
    \\                try writer.writeAll("failed");
    \\                if (color) try writer.writeAll("\x1b[0m");
    \\                try writer.print(": {t}\n", .{ err });
    \\            }
    \\        } else {
    \\            try printAnswer(writer, part);
    \\        }
    \\        return 0;
    \\    }
    \\}
    \\
    \\fn isSolutionFn(Fn: type) bool {
    \\    switch (@typeInfo(Fn)) {
    \\        .@"fn" => |f| return f.params.len == 1 and
    \\            ( f.params[0].type == []u8 or f.params[0].type == []const u8 ),
    \\        else => return false,
    \\    }
    \\}
    \\
    \\fn printAnswer(writer: *std.Io.Writer, answer: anytype) !void {
    \\    const Answer = @TypeOf(answer);
    \\    const fmt = switch (@typeInfo(Answer)) {
    \\        .int, .float => "{d}",
    \\        .pointer => |p| switch (p.child) {
    \\            u8 => if (p.sentinel_ptr==null
    \\                and (p.size==.many or p.size==.c)) "{any}" else "{s}",
    \\            else => "{any}"
    \\        },
    \\        else => if (comptime isContainer(Answer)
    \\            and @hasDecl(Answer, "format")) "{f}" else "{any}",
    \\    };
    \\    try writer.print(" " ++ fmt ++ "\n", .{ answer });
    \\}
    \\
    \\fn isContainer(T: type) bool {
    \\    return switch (@typeInfo(T)) {
    \\        .@"struct", .@"enum", .@"union" => true,
    \\        else => false,
    \\    };
    \\}
    \\
    \\fn printTime(writer: *std.Io.Writer, nanoseconds: u64) !u8 {
    \\    const max_digits = 8;
    \\    var t: f64 = @floatFromInt(nanoseconds);
    \\    if (nanoseconds == 0) {
    \\        // Unsure if this is possible, but handle it
    \\        try writer.print("instant", .{});
    \\        return 4;
    \\    } else if (nanoseconds < 100) {
    \\        try writer.print("{d:.0} ns", .{ nanoseconds });
    \\        const whole_digits = if (nanoseconds >= 10) @as(u8, 2) else @as(u8, 1);
    \\        const trailing_digits = 0;
    \\        return max_digits - @min(max_digits, whole_digits+trailing_digits);
    \\    } else if (nanoseconds < 100*1000) {
    \\        t /= @floatFromInt(time.ns_per_us);
    \\        try writer.print("{d:.1} \xc2\xb5s", .{t});
    \\        const whole_digits = if (t<1.0) @as(u8, 1)
    \\            else @as(u8, @intFromFloat(@floor(math.log10(@trunc(t)))))+1;
    \\        const trailing_digits = 2;
    \\        return max_digits - @min(max_digits, whole_digits+trailing_digits);
    \\    } else if (nanoseconds < 100*1000*10000) {
    \\        t /= @floatFromInt(time.ns_per_ms);
    \\        try writer.print("{d:.3} ms", .{t});
    \\        const whole_digits = if (t<1.0) @as(u8, 1)
    \\            else @as(u8, @intFromFloat(@floor(math.log10(@trunc(t)))))+1;
    \\        const trailing_digits = 4;
    \\        return max_digits - @min(max_digits, whole_digits+trailing_digits
    \\            + if (nanoseconds >= 100*1000*10000-500) @as(u8, 1) else @as(u8, 0));
    \\    } else if (nanoseconds < 100*1000*10000*60) {
    \\        t /= @floatFromInt(time.ns_per_s);
    \\        try writer.print("{d:.3} s", .{t});
    \\        const whole_digits = if (t<1.0) @as(u8, 1)
    \\            else @as(u8, @intFromFloat(@floor(math.log10(@trunc(t)))))+1;
    \\        const trailing_digits = 3;
    \\        return max_digits - @min(max_digits, whole_digits+trailing_digits);
    \\    } else if (nanoseconds <= 100*1000*10000*60*60) {
    \\        t /= @floatFromInt(time.ns_per_min);
    \\        try writer.print("{d:.3} m", .{t});
    \\        const whole_digits = if (t<1.0) @as(u8, 1)
    \\            else @as(u8, @intFromFloat(@floor(math.log10(@trunc(t)))))+1;
    \\        const trailing_digits = 3;
    \\        return max_digits - @min(max_digits, whole_digits+trailing_digits);
    \\    } else {
    \\        t /= @floatFromInt(time.ns_per_hour);
    \\        try writer.print("{d:.2} hr", .{t});
    \\        const whole_digits = if (t<1.0) @as(u8, 1)
    \\            else @as(u8, @intFromFloat(@floor(math.log10(@trunc(t)))))+1;
    \\        const trailing_digits = 3;
    \\        return max_digits - @min(max_digits, whole_digits+trailing_digits);
    \\    }
    \\}
    \\
    \\// `@import()` requires a string literal
    \\fn DayNumberToModule(comptime day: usize) type {
    \\    return switch (day) {
    \\        1 => @import("day_1"),
    \\        2 => @import("day_2"),
    \\        3 => @import("day_3"),
    \\        4 => @import("day_4"),
    \\        5 => @import("day_5"),
    \\        6 => @import("day_6"),
    \\        7 => @import("day_7"),
    \\        8 => @import("day_8"),
    \\        9 => @import("day_9"),
    \\        10 => @import("day_10"),
    \\        11 => @import("day_11"),
    \\        12 => @import("day_12"),
    \\        13 => @import("day_13"),
    \\        14 => @import("day_14"),
    \\        15 => @import("day_15"),
    \\        16 => @import("day_16"),
    \\        17 => @import("day_17"),
    \\        18 => @import("day_18"),
    \\        19 => @import("day_19"),
    \\        20 => @import("day_20"),
    \\        21 => @import("day_21"),
    \\        22 => @import("day_22"),
    \\        23 => @import("day_23"),
    \\        24 => @import("day_24"),
    \\        25 => @import("day_25"),
    \\        26 => @import("day_26"),
    \\        27 => @import("day_27"),
    \\        28 => @import("day_28"),
    \\        29 => @import("day_29"),
    \\        30 => @import("day_30"),
    \\        31 => @import("day_31"),
    \\        // This could go on, but there are only 31 possible days in December.
    \\        else => @compileError(std.fmt.comptimePrint("unsupported day number {d}", .{day})),
    \\    };
    \\}
    \\
    \\const Timer = time.Timer;
    \\const time = std.time;
    \\const math = std.math;
    \\const days = @import("days");
    \\const std = @import("std");
;

const Allocator = std.mem.Allocator;
const OptimizeMode = std.builtin.OptimizeMode;

const testing = std.testing;
const fmt = std.fmt;

const Build = std.Build;
const std = @import("std");
