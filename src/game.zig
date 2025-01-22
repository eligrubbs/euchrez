// The `Game` struct contains logic and exposes API's to run a game of euchre.  
// While Euchre is a 4 player game, the API exposes a simple `step` function.

const std = @import("std");

const Card = @import("card/card.zig").Card;
const Deck = @import("deck.zig").Deck;
const Player = @import("player.zig").Player;
const FlippedChoice = @import("actions.zig").FlippedChoice;

const Game = struct {
    const num_players = 4; // do not change

    was_initialized: bool, // make sure that reset is called before calling other methods
    is_over: bool,

    deck: Deck,

    players: [4]Player,
    dealer_id: u2,
    curr_player_id: u2,
    calling_player_id: ?u2,

    flipped_card: *const Card,
    flipped_choice: ?FlippedChoice,

    const GameError = error {
        NotPlayable,
    };

    /// Creates a game object. It is NOT ready to be played.
    /// 
    /// Caller is responsible for cleaning up game's memory with `deinit`
    pub fn init(allocator: std.mem.Allocator) !Game {

        return Game {
            .was_initialized = false,
            .is_over = false,

            .deck = try Deck.init(allocator),

            .players = undefined,
            .dealer_id = undefined,
            .curr_player_id = undefined,
            .calling_player_id = null,

            .flipped_card = undefined,
            .flipped_choice = null,
        };

    }

    /// Resets the game state to a valid beginning state.
    /// 
    /// Right now this is what it does:
    /// 1. Sets was initialized to true
    /// 2. Sets is_over to false
    /// 3. resets deck to unshuffled version
    /// 4. Creates 4 players and deals them 5 cards each
    /// 5. Sets dealer id to 0, curr player to 1, and calling_player to null
    /// 6. initializes flipped card and sets flipped choice to null
    pub fn reset(self: *Game) void {
        self.was_initialized = true;

        self.is_over = false;

        Deck.fill_unshuffled(&self.deck.card_buffer);

        for (0..4) |ind| {
            self.players[ind] = Player.init(ind, try self.deck.deal_five_cards());
        }

        self.dealer_id = 0;
        self.curr_player_id = 1;
        self.calling_player_id = null;

        self.flipped_card = try self.deck.deal_one_card();
        self.flipped_choice = null;
    }

    /// Cleans up game object.
    pub fn deinit(self: *Game) void {
        self.deck.deinit();
    }

    pub fn is_active(self: *Game) bool {
        return self.in_non_terminal_state;
    }

};
