## Sample

In `2015/day_03.zig`:

```zig
pub fn part1(input: []const u8) [:0]const u8 {
    _ = input;
    return "foo";
}

pub fn part2(input: []u8) !i32 {
    std.debug.print("All your codebase are belong to us.\n", .{});
    _ = input;
    return error.Overflow;
}

const std = @import("std");
```

(`input/2015/day03.txt` exists)

```console
$ zig build solve -Dday=..3 -Dyear=2015
[01/1] (43.3 µs)    foo
All your codebase are belong to us.
[01/2]  failed: Overflow
[02/1] (26.361 ms)  27
...
[03/2] (1.652 ms)   bar
Total elapsed solution time: 104.833 ms (excluding 1 failure)
```

## Usage

You may delete any file other than `build.zig`.

The build script expects the following file layout:

```
input/
    YYYY/
        day01.txt
        day02.txt
        ...
YYYY/
    day_01.zig
    day_02.zig
    ...
build.zig
```

In each `day_DD.zig`, the solution program checks for and runs
top-level `pub` functions named `part1()` and `part2()`,
each of which must accept a slice of bytes (`[]const u8` or `[]u8`),
which contains that day's input string as it appears in `input/YYYY/dayDD.txt`.
You may safely mutate the slice. Do not free the slice.
The solution functions may return
any type printable with `{any}`,
a type with a `.format()` method,
a `u8` string,
or any of the previous options within an error union.
If you return data by reference (e.g. a `[]const u8`),
do not keep it on the stack and do not free it from the heap
(use static buffers or leak the memory).

`zig build solve -Dday=...` will run the solutions
for any single day or range of days:

- `-Dday=5`: print output of `day_05.part1()`, if it is defined,
    print output of `day_05.part2()`, if it is defined
- `-Dday=5..7`: the same, for days 5, 6, and 7, serially
- `-Dday=..7`: the same, for days 1-7, serially

The results are printed directly to `stdout`.
