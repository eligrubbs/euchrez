//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("euchrez_lib");
const Game = lib.Game;

const stdout_file = std.io.getStdOut().writer();

pub fn main() !void {
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    const num_games = 1_000_000;

    try stdout.print("Starting {d} games of Euchre.\n", .{num_games});
    try bw.flush();

    const start = try std.time.Instant.now();

    const games: []Game = try allocator.alloc(Game, num_games);
    defer allocator.free(games);

    for (0..games.len) |game_ind| {
        games[game_ind] = try Game.new(.{});
        var game: Game = games[game_ind];
        for (0..29) |_| {
            if (game.is_over() == true) break;
            const acts = game.get_legal_actions();
            _ = try game.step(acts.get(0).?);
            // std.debug.print("{any}\n", .{acts});
        }
    }

    var vars = try std.process.getEnvMap(allocator);
    defer vars.deinit();
    // std.debug.print("Vars: {s}\n", .{vars.get("PATH").?});

    const elapsed_ns = (try std.time.Instant.now()).since(start);
    const elapsed_ms = elapsed_ns / std.time.ns_per_ms;
    const elapsed_s = elapsed_ns / std.time.ns_per_s;

    try stdout.print("Duration: {}s {}ms\n", .{ elapsed_s, elapsed_ms % std.time.ms_per_s });
    try bw.flush(); // Don't forget to flush!
}
