// The `Game` struct contains logic and exposes API's to run a game of euchre.  
// While Euchre is a 4 player game, the API exposes a simple `step` function.

const std = @import("std");

const Deck = @import("deck.zig").Deck;

const Game = struct {
    const num_players = 4; // do not change

    in_non_terminal_state: bool = false,

    deck: Deck,

    /// Creates a game object. It is NOT ready to be played.
    /// 
    /// Caller is responsible for cleaning up game's memory with `deinit`
    pub fn init(allocator: std.mem.Allocator) Game {

        return Game {
            .in_non_terminal_state = false,
            .deck = Deck.init(allocator),
        };

    }

    /// Resets the game state to a valid beginning state.
    pub fn reset() void {

    }

    /// Cleans up game object.
    pub fn deinit(self: *Game) void {
        self.deck.deinit();
    }

    pub fn is_active(self: *Game) bool {
        return self.in_non_terminal_state;
    }

};
