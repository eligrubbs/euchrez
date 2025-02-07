# euchrez
Implementation of Euchre in Zig.

Meant to be used as a library in your program to play euchre games.

The `Game` type is intended only to move the game forward/backward. 
An interface for loading each of the 4 players as unique agents has not been created yet.


### Benchmarks:

When built with `-Drelease=true`:

|    Games   | Time to play (sec, ms) |
|  --------  |  ----------------  |
|  10,000    |        0s 24ms       |
|  100,000   |        0s 220ms       |
|  1,000,000   |        2s 240ms       |
|  10,000,000 |        22s 600ms      |