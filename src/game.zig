// The `Game` struct contains logic and exposes API's to run a game of euchre.  
// While Euchre is a 4 player game, the API exposes a simple `step` function.

const std = @import("std");

const Card = @import("card/card.zig").Card;
const Suit = @import("card/suit.zig").Suit;
const Rank = @import("card/rank.zig").Rank;
const Deck = @import("deck.zig").Deck;
const Player = @import("player.zig").Player;
const FlippedChoice = @import("actions.zig").FlippedChoice;

const Game = struct {
    const num_players = 4; // do not change

    was_initialized: bool, // make sure that reset is called before calling other methods
    is_over: bool,
    scores: ?[4]u3, // scores not null only at end of game

    deck: Deck,

    players: [4]Player,
    dealer_id: u2,
    curr_player_id: u2,
    caller_id: ?u2,

    flipped_card: *const Card,
    flipped_choice: ?FlippedChoice,

    order: [4]u2,
    center: ?[4:null]?*const Card,
    trump: ?Suit,

    const GameError = error {
        NotPlayable,
        CenterIsEmpty,
        TrumpNotSet,
    };

    /// Creates a game object. It is NOT ready to be played.
    /// 
    /// Caller is responsible for cleaning up game's memory with `deinit`
    pub fn init(allocator: std.mem.Allocator) !Game {

        return Game {
            .was_initialized = false,
            .is_over = false,
            .scores = null,

            .deck = try Deck.init(allocator),

            .players = undefined,
            .dealer_id = undefined,
            .curr_player_id = undefined,
            .caller_id = null,

            .flipped_card = undefined,
            .flipped_choice = null,

            .order = undefined,
            .center = null,
            .trump = null,
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
        self.scores = null;

        Deck.fill_unshuffled(&self.deck.card_buffer);

        for (0..4) |ind| {
            self.players[ind] = Player.init(ind, try self.deck.deal_five_cards());
        }

        self.dealer_id = 0;
        self.curr_player_id = 1;
        self.caller_id = null;

        self.flipped_card = try self.deck.deal_one_card();
        self.flipped_choice = null;

        self.order = self.order_starting_from(self.curr_player_id);
        self.center = null;
        self.trump = null;

    }

    /// Cleans up game object.
    pub fn deinit(self: *Game) void {
        self.deck.deinit();
    }

    /// Returns the order of the rest of the players if `p_id` is assumed to go first.
    fn order_starting_from(p_id: u2) [4]u2 {
        return .{p_id, p_id +% 1, p_id +% 2, p_id +% 3};
    }

    /// Returns the effective suit of the game?
    /// If there is no effective suit, return null
    fn get_led_suit(self: *const Game) GameError!?Suit {
        if (self.center == null) return null;

        if (self.trump == null) return GameError.TrumpNotSet;
        if (self.center.?[0] == null) return GameError.CenterIsEmpty;

        const led_card = self.center.?[0].?;
        if (self.is_left_bower(led_card)) {
                return self.trump;
        }
        return led_card.suit;
    }

    fn is_left_bower(self: *const Game, card: *const Card) GameError!bool {
        if (self.trump == null) return GameError.TrumpNotSet;

        return (card.rank.eq(Rank.from_char('J')) and 
                self.left_bower_suit(self.trump.?) == card.suit);
    }

    /// Given a trump suit, returns the suit whose Jack is considered trump 
    fn left_bower_suit(trump: Suit) Suit {
        return switch (trump) {
            .Spades => .Clubs,
            .Clubs => .Spades,
            .Hearts => .Diamonds,
            .Diamonds => .Hearts,
        };
    }
};
