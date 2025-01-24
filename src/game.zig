// The `Game` struct contains logic and exposes API's to run a game of euchre.  
// While Euchre is a 4 player game, the API exposes a simple `step` function.

const std = @import("std");

const Card = @import("card/card.zig").Card;
const Suit = @import("card/suit.zig").Suit;
const Rank = @import("card/rank.zig").Rank;
const Deck = @import("deck.zig").Deck;
const Action = @import("action.zig").Action;
const Player = @import("player.zig").Player;
const FlippedChoice = @import("action.zig").FlippedChoice;

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
    center: ?[4:null]?*const Card, // 4 is maximum number of cards that can be in the middle
    trump: ?Suit,

    actions_taken: [29:null]?Action, // maximum number of actions there can be in a euchre game.

    const GameError = error {
        NotPlayable,
        CenterIsEmpty,
        TrumpNotSet,
        GameHasNotStarted,
        KittyCardNotAvailable,
    };

    /// Creates a game object. It is NOT ready to be played.
    /// 
    /// Caller is responsible for cleaning up game's memory with `deinit`
    pub fn new() !Game {

        return Game {
            .was_initialized = false,
            .is_over = false,
            .scores = null,

            .deck = try Deck.new(),

            .players = undefined,
            .dealer_id = undefined,
            .curr_player_id = undefined,
            .caller_id = null,

            .flipped_card = undefined,
            .flipped_choice = null,

            .order = undefined,
            .center = null,
            .trump = null,

            .actions_taken = .{null} ** 29,
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

        self.actions_taken = .{null} ** 29;
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

    /// Returns the number of actions taken
    fn num_actions_taken(self: *const Game) usize {
        for (self.actions_taken, 0..) |act, count| {
            if (act == null) return count;
        }
        return self.actions_taken.len;
    }

    /// Returns the most recent action taken or null if no actions have been taken
    fn last_action(self: *const Game) ?Action {
        const acts_taken = self.num_actions_taken();
        if (acts_taken == 0) return null;
        return self.actions_taken[acts_taken-1];
    }

    // //////
    // / Game Logic
    // /////

    /// Take `action` and change the game state to reflect that.
    pub fn step(self: *Game, action: Action) u2 {
        switch (action) {
            .Pick => self.perform_pick_action(),
            .Pass => 0,
            Action.Call => 1,
            Action.Play => 2,
            Action.Discard => 3,
        }

        return self.curr_player_id;
    }

    /// Remove the affects of the last action taken in the game.
    pub fn step_back(self: *Game) GameError!u2 {
        const the_last_action = self.last_action();
        if (the_last_action == null) return GameError.GameHasNotStarted;

        switch (the_last_action.?) {
            .Pick => self.undo_pick_action(),
            .Pass => 0,
            Action.Call => 1,
            Action.Play => 2,
            Action.Discard => 3,
        }

        return self.curr_player_id;
    }



    /// Changes to game state:
    /// 1. flipped card goes into dealers hand
    /// 2. `curr_player_id` is changed to `dealer_id`
    /// 3. player who called has their id saved into `caller_id`
    /// 4. flipped choice is set to picked up
    ///      - prevents this method from being called again
    /// 5. Trump is set to suit of flipped card
    /// 
    /// State Validation:
    /// 1. flipped choice must be null before making changes
    fn perform_pick_action(self: *Game) void {
        if (self.flipped_choice != null) return GameError.KittyCardNotAvailable;

        self.players[self.dealer_id].pick_up_6th_card(self.flipped_card);
        self.curr_player_id = self.dealer_id;
        self.caller_id = self.curr_player_id;
        self.flipped_choice = FlippedChoice.PickedUp;
        self.trump = self.flipped_card.suit;
    }

    /// Undos this pick action. Assumes it is only called from a valid state
    /// 1. Removes flipped card from dealers hand
    /// 2. `curr_player_id` is changed to `caller_id`
    /// 3. `caller_id` is set to null
    /// 4. flipped choice is set to null
    /// 5. Trump is set to none
    fn undo_pick_action(self: *Game) void {
        try self.players[self.dealer_id].discard_card(self.flipped_card);
        self.curr_player_id = self.caller_id.?;
        self.caller_id = null;
        self.flipped_choice = null;
        self.trump = null;
    }


    fn perform_pass_action(self: *Game) void {
        _ = self;
    }

    /// undos this pass action. Assumes it is only called from a valid state
    fn undo_pass_action(self: *Game) void {
        _ = self;
    }



    fn perform_call_action(self: *Game) void {
        _ = self;
    }

    /// undos this call action. Assumes it is only called from a valid state
    fn undo_call_action(self: *Game) void {
        _ = self;
    }



    fn perform_play_action(self: *Game) void {
        _ = self;
    }

    /// undos this play action. Assumes it is only called from a valid state
    fn undo_play_action(self: *Game) void {
        _ = self;
    }



    fn perform_discard_action(self: *Game) void {
        _ = self;
    }

    /// undos this discard action. Assumes it is only called from a valid state
    fn undo_discard_action(self: *Game) void {
        _ = self;
    }

};



const expect = std.testing.expect;

test "create_game" {
    const game = try Game.new();

    try expect(game.is_over == false);
}
