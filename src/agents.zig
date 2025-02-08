//! This file contains code for the basic agents

// https://zig.news/kilianvounckx/zig-interfaces-for-the-uninitiated-an-update-4gf1

const std = @import("std");

const Action = @import("action.zig").Action;
const ScopedState = @import("game.zig").ScopedState;
const LegalActions = @import("game.zig").LegalActions;

pub const Agent = union(enum) {
        const Self = @This();

        Random: RandomAgent,


        pub fn decideAction(self: *Self, state: *const ScopedState, acts: LegalActions) Action {
            return switch (self.*) {
                .Random => |*agent| agent.decideActionFn(state , acts),
            };
        }
    };


pub const RandomAgent= struct {
        prng: std.Random.DefaultPrng,

        const Self = @This();

        /// Used by `Sgent` to decide what action to take given the current state
        pub fn decideActionFn(self: *Self, state: *const ScopedState, acts: LegalActions) Action {
            _ = state;
            const act_to_take = acts.get(self.prng.random().intRangeAtMost(usize, 1, acts.num_left()) - 1);
            return act_to_take.?;
        }

        /// Creates a new random agent.
        pub fn new(seed: ?u64) !Self {

            const the_prng = std.Random.DefaultPrng.init(blk: {
                var the_seed: u64 = undefined;
                if (seed == null) {
                    try std.posix.getrandom(std.mem.asBytes(&the_seed));
                } else {
                    the_seed = seed.?;
                }
                break :blk the_seed;
            });

            return Self{
                .prng = the_prng,
            };
        }
};



test "random-agent-works" {
    const Game = @import("game.zig").Game;

    const test_seed: u64 = 43;

    var game = try Game.new(.{.seed = test_seed});
    var rdm_agent = Agent{.Random = try RandomAgent.new(test_seed)};

    const first_act = rdm_agent.decideAction(&game.get_scoped_state(game.curr_player_id), game.get_legal_actions());
    try std.testing.expect(first_act == Action.Pick);

    _ = try game.step(first_act);

    const second_act = rdm_agent.decideAction(&game.get_scoped_state(game.curr_player_id), game.get_legal_actions());
    try std.testing.expect(second_act == Action.DiscardCA);
}