//! Provided agent that ships with this package.
//! 
//! It will accept strings which represent each action from the terminal.
//! Maybe in the future I will generalize it to accept input from a provided stream.

const std = @import("std");

const Action = @import("../action.zig").Action;
const ScopedState = @import("../game.zig").ScopedState;
const LegalActions = @import("../game.zig").LegalActions;
const Agent = @import("../Agent.zig");


pub const Config = struct {

};

/// Call `.init()` to initialize this struct
pub fn InputAgent(comptime config: Config) type {
    return struct {
        const Self = @This();


        /// Creates a new random agent.
        pub fn init() Self {

            // so compiler will shut up
            _ = config;

            return Self{
                
            };
        }

        pub fn decide(context: *anyopaque, state: *const ScopedState, acts: LegalActions) Action {
            const self : *Self = @ptrCast(@alignCast(context));

            // Display State about game to terminal
            self.explain_state(state);
            std.log.info("{any}", .{acts.data});

            // Prompt for input
            const act_to_take = acts.get(0);
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


        pub fn explain_state(self: *Self, state: *const ScopedState) void {
            _ = self;
            std.log.info("Kitty Card: {s}", .{state.flipped_card.str()});
            std.log.info("Kitty Was: {any}", .{state.flipped_choice});
            std.log.info("Trump: {c}", .{state.trump.?.char()});
        }
    };
}