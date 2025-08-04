//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("euchrezInternal");
const Game = lib.Game;
const Env = lib.Env;

const stdout_file = std.io.getStdOut().writer();

pub fn main() !void {
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    // const allocator = gpa.allocator();

    try stdout.print("Play Euchre\n", .{});
    try bw.flush();

    // Start Time
    const start = try std.time.Instant.now();

    var agent_1 = lib.input_agent.InputAgent(.{}).init();
    var agent_2 = try lib.random_agent.RandomAgent(.{.seed = 44}).init();
    var agent_3 = try lib.random_agent.RandomAgent(.{.seed = 44}).init();
    var agent_4 = try lib.random_agent.RandomAgent(.{.seed = 44}).init();

    const env_config = lib.EnvConfig{
        .verbose = true,
        .game_config = .{.dealer_id = null, .seed = 45, .verbose = true},
        .agents = .{
            agent_1.agent(),
            agent_2.agent(),
            agent_3.agent(),
            agent_4.agent(),
        }
    };

    var env = try Env.new(env_config);

    try env.run();

    // End Time
    const elapsed_ns = (try std.time.Instant.now()).since(start);
    const elapsed_ms = elapsed_ns / std.time.ns_per_ms;
    const elapsed_s = elapsed_ns / std.time.ns_per_s;

    try stdout.print("Duration: {}s {}ms\n", .{ elapsed_s, elapsed_ms % std.time.ms_per_s });
    try bw.flush();
}
