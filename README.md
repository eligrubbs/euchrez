# euchre-zig
Implementation of Euchre in Zig


### Benchmarks:

When built with `-Doptimize=ReleaseFast`:

|    Games   | Time to play (sec, ms) |
|  --------  |  ----------------  |
|  10,000    |        0s 24ms       |
|  100,000   |        0s 220ms       |
|  1,000,000   |        2s 240ms       |
|  10,000,000 |        22s 600ms      |