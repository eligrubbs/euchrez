// The `Game` struct contains logic and exposes API's to run a game of euchre.  
// While Euchre is a 4 player game, the API exposes a simple `step` function.

const Deck = @import("deck.zig").Deck;

const Game = struct {
    const num_players = 4; // do not change

    in_non_terminal_state: bool = false,

    deck: Deck,

    /// Creates a game object. It is NOT ready to be played.
    /// 
    /// Caller responsible for freeing used memory using `deinit` method
    pub fn init() void {

    }

    /// Resets the game state to a valid beginning state.
    pub fn reset() void {

    }

    /// Cleans up game object.
    pub fn deinit() void {

    }

    pub fn is_active(self: *Game) bool {
        return self.in_non_terminal_state;
    }

};
