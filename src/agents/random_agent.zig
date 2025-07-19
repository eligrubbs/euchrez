//! Provided random agent that ships with this package.
//! 
//! It will take actions randomly.

const std = @import("std");

const Action = @import("../action.zig").Action;
const ScopedState = @import("../game.zig").ScopedState;
const LegalActions = @import("../game.zig").LegalActions;
const Agent = @import("../Agent.zig");


pub const Config = struct {
    /// Seed to initialize random number generator with
    seed: ?u64,
};


/// Call `.init()` to initialize this struct
pub fn RandomAgent(comptime config: Config) type {
    return struct {
        const Self = @This();

        prng: std.Random.DefaultPrng,

        /// Creates a new random agent.
        pub fn init() !Self {

            const the_prng = std.Random.DefaultPrng.init(blk: {
                var the_seed: u64 = undefined;
                if (config.seed == null) {
                    try std.posix.getrandom(std.mem.asBytes(&the_seed));
                } else {
                    the_seed = config.seed.?;
                }
                break :blk the_seed;
            });

            return Self{
                .prng = the_prng,
            };
        }

        pub fn decide(context: *anyopaque, state: *const ScopedState, acts: LegalActions) Action {
            const self : *Self = @ptrCast(@alignCast(context));

            _ = state;
            const act_to_take = acts.get(self.prng.random().intRangeAtMost(usize, 1, acts.num_items()) - 1);
            return act_to_take.?;
        }

        pub fn agent(self: *Self) Agent {
            return .{
                .ptr = self,
                .vtable = &.{
                    .decide = decide,
                }
            };
        }
    };
}


test "random-agent-works" {
    const Game = @import("../game.zig").Game;

    const test_seed: u64 = 43;

    var game = try Game.new(.{.seed = test_seed});

    var rdm_agent = (try RandomAgent(.{.seed = test_seed}).init());
    var agent = rdm_agent.agent();

    const first_act = agent.decide(&game.get_scoped_state(game.curr_player_id), game.get_legal_actions());
    try std.testing.expect(first_act == Action.Pick);

    _ = try game.step(first_act);

    const second_act = agent.decide(&game.get_scoped_state(game.curr_player_id), game.get_legal_actions());
    try std.testing.expect(second_act == Action.DiscardCA);
}