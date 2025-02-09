
const game =  @import("game.zig");
const Game = game.Game;
const GameConfig = game.GameConfig;
const Agent = @import("agents.zig").Agent;

/// Configures a euchre environment
pub const EnvConfig = struct {
    /// Configuration to pipe to euchre `Game` object
    game_config: GameConfig,

    /// List of agents to play the game.
    /// The order in this array will become their ID (0, 1, 2, or 3)
    agents: [4]Agent,
};

/// A wrapper for the euchre `Game` that makes it easier for individual agents
/// to play euchre against one another.
pub const Env = struct {

    game: Game,

    agents: [4]Agent,


    /// Create a new euchre environment ready to be played
    pub fn new(config: EnvConfig) Env {
        return Env {
            .game = try Game.new(config.game_config),
            .agents = config.agents,
        };
    }

    /// Have the current agent decide and execute an action to move
    /// the game to the next state.
    pub fn step(self: *Env) self.game.GameError!void {
        const curr_p = self.game.curr_player_id;

        const state = self.game.get_scoped_state(curr_p);
        const possible_acts = self.game.get_legal_actions();

        // TODO: Add logging and stuff
        const act_to_take = self.agents[curr_p].decideAction(&state, possible_acts);

        // execute action in game simulator
        _ = self.game.step(act_to_take) catch |err| return err;

    }

    /// Undo the last action taken in the game.
    pub fn step_back(self: *Env) void {
        self.game.step_back();
    }

    /// Resets the Env using the same config passed when `new` was called.
    pub fn reset(self: *Env) void {
        try self.game.reset();
    }

    /// Run the game from the current state until the end
    pub fn run() void {

    }

};
