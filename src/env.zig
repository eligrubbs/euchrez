
const game =  @import("game.zig");
const Game = game.Game;
const GameConfig = game.GameConfig;
const Agent = @import("Agent.zig");

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
    pub fn new(config: EnvConfig) !Env {
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
        const act_to_take = self.agents[curr_p].decide(&state, possible_acts);

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
    pub fn run(self: *Env) !void {
        while (!self.game.is_over()) {
            const curr_p = self.game.curr_player_id;
            const curr_state = self.game.get_scoped_state(curr_p);
            const legal_acts = self.game.get_legal_actions();
            const act_to_take = self.agents[curr_p].decide(&curr_state, legal_acts);

            _ = try self.game.step(act_to_take);
        }
    }

};



test "env of random agents" {
    const expect = @import("std").testing.expect;

    const rdm_agent = @import("agents/random_agent.zig");

    var agent_1 = (try rdm_agent.RandomAgent(.{.seed = 42}).init());
    var agent_2 = (try rdm_agent.RandomAgent(.{.seed = 42}).init());
    var agent_3 = (try rdm_agent.RandomAgent(.{.seed = 42}).init());
    var agent_4 = (try rdm_agent.RandomAgent(.{.seed = 42}).init());


    const env_config: EnvConfig = EnvConfig{
        .game_config = GameConfig{.dealer_id = 0, .seed = 1, .verbose = false},
        .agents = [4]Agent{
            agent_1.agent(),
            agent_2.agent(),
            agent_3.agent(),
            agent_4.agent()
        }
    };

    var game_env = try Env.new(env_config);

    try game_env.run();

    try expect(game_env.game.is_over() == true);
}
