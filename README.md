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

If you manually install and run the `advent-of-code-YYYY` executable
with the `install` step (if for example using it with a debugger),
please run it from the same directory containing the `input/` directory.

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

## Implementation

A string with Zig source code for a runner executable is kept statically in `build.zig`.
This allows the entire convenience script to live in a single distributable source file,
but it would be more typical to keep this committed as a dedicated source file
that `build.zig` adds to the build graph via `LazyPath`.
Instead, it uses `Build.addWriteFile`,
which tells the build to cache the executable source as a file,
and points to the cached file path as the root source path of the executable module.

The executable module imports modules named from day 1 to 31,
but because declarations are evaluated lazily,
it will only reference the range of days passed to it via build option.
Another way to accomplish this,
and one that would allow any range or names of solution modules,
would be to write `@import` lines into the source string passed to `addWriteFile`.

The solution runner keeps a writer to `stdout`, and for each day, it

1. Opens a reader to the matching day's input file
2. Reads and double allocates (so that each part can mutate) the day's input
3. Starts a performance timer, calls `day_DD.partN()`, and immediately reads the timer
4. Prints the results

Note then that the printed times are not a proper benchmark,
but they are a precise measure of the time it takes for each solution function to execute,
without the IO time of fetching input or printing results included.

Proper benchmarking is included as a build flag (`-Dbench=true`).
A benchmarked solution has its execution time measured just as before
(without IO time, purely the time it takes for the solution function to return),
and the times of all iterations (default 10000) are used to print statistics.
