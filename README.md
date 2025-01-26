# euchre-zig
Implementation of Euchre in Zig


### Benchmarks:

When built with `-Doptimize=ReleaseFast`:

|    Games   | Time to play (sec, ms) |
|  --------  |  ----------------  |
|  10,000    |        0s 40ms       |
|  100,000   |        0s 320ms       |
|  1,000,000   |        3s 156ms       |
|  10,000,000 |        32s 494ms      |