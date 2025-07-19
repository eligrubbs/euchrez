//! The general Agent interface for playing Euchre games.
//! 
//! Following pattern of zig std Allocator.

const std = @import("std");
const Agent = @This();
const assert = std.debug.assert;

const Action = @import("action.zig").Action;
const ScopedState = @import("game.zig").ScopedState;
const LegalActions = @import("game.zig").LegalActions;


ptr: *anyopaque,
vtable: *const VTable,


pub const VTable = struct {
    /// Return the Action selected by the agent conditional 
    /// on the provided game state / metadata.
    decide: *const fn (*anyopaque, state: *const ScopedState, acts: LegalActions) Action,
};


/// Return the Action selected by the agent conditional 
/// on the provided game state / metadata.
pub fn decide(a: Agent, state: *const ScopedState, acts: LegalActions) Action {
    return a.vtable.decide(a.ptr, state, acts);
}