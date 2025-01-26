//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("euchre-zig_lib");
const Game = lib.Game;


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const games: []Game = try allocator.alloc(Game, 1);
    defer allocator.free(games);

    for (0..games.len) |game_ind| {
        games[game_ind] = try Game.new(.{});
        var game: Game = games[game_ind];
        try game.reset();
        for (0..29) |_| {
            if (game.is_over == true) break;
            const acts = game.get_legal_actions();
            _ = try game.step(acts[0].?);
            // std.debug.print("{any}\n", .{acts});
        }
    }

    var vars = try std.process.getEnvMap(allocator);
    defer vars.deinit();

    // std.debug.print("Vars: {s}\n", .{vars.get("PATH").?});

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!
}
