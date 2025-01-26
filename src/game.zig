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

pub const Game = struct {
    const num_players = 4; // do not change
    const empty_center: [4:null]?*const Card = .{null} ** 4;

    config: GameConfig,
    prng: std.Random.DefaultPrng,

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
    previous_last_in_order_id: ?u2, // used only for undoing play actions
    center: [4:null]?*const Card, // 4 is maximum number of cards that can be in the middle
    trump: ?Suit,

    actions_taken: [29:null]?Action, // maximum number of actions there can be in a euchre game.

    const GameError = error {
        ActionNotLegalGivenGameState,
        NotPlayable,
        TrumpNotSet,
        GameHasNotStarted,
        KittyCardNotAvailable,
        DealerMustCallAfterTurnedDownKittyCard,
        TrumpAlreadySet,
        ActionNotPreviouslyTaken,
    } || Player.PlayerError || Card.CardError || Action.ActionError;

    pub const GameConfig = struct {
        verbose: bool = false,
        seed: ?u64 = null,
    };

    /// Creates a game object. It is NOT ready to be played.
    /// 
    /// Caller is responsible for cleaning up game's memory with `deinit`
    pub fn new(config: GameConfig) !Game {

        return Game {
            .config = config,
            .prng = std.Random.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                if (config.seed == null) {
                    try std.posix.getrandom(std.mem.asBytes(&seed));
                } else {seed = config.seed.?;}
                break :blk seed;
            }),
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
            .previous_last_in_order_id = null,
            .center = empty_center,
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
    pub fn reset(self: *Game) !void {
        self.prng = std.Random.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                if (self.config.seed == null) {
                    try std.posix.getrandom(std.mem.asBytes(&seed));
                } else {seed = self.config.seed.?;}
                break :blk seed;
        });

        self.was_initialized = true;

        self.is_over = false;
        self.scores = null;

        Deck.fill_unshuffled(&self.deck.card_buffer);
        self.prng.random().shuffle(Card, &self.deck.card_buffer);

        self.players[0] = try Player.init(0, try self.deck.deal_five_cards());
        self.players[1] = try Player.init(1, try self.deck.deal_five_cards());
        self.players[2] = try Player.init(2, try self.deck.deal_five_cards());
        self.players[3] = try Player.init(3, try self.deck.deal_five_cards());

        self.dealer_id = self.prng.random().int(u2);
        self.curr_player_id = self.dealer_id +% 1;
        self.caller_id = null;

        self.flipped_card = try self.deck.deal_one_card();
        self.flipped_choice = null;

        self.order = Game.order_starting_from(self.curr_player_id);
        self.previous_last_in_order_id = null;
        self.center = empty_center;
        self.trump = null;

        self.actions_taken = .{null} ** 29;
    }

    /// Returns the order of the rest of the players if `p_id` is assumed to go first.
    fn order_starting_from(p_id: u2) [4]u2 {
        return .{p_id, p_id +% 1, p_id +% 2, p_id +% 3};
    }

    /// Returns the effective suit of the game
    /// If there is no effective suit, return null
    fn get_led_suit(self: *const Game) ?Suit {
        if (self.center[0] == null or self.trump == null) return null;

        const led_card = self.center[0].?;
        if (led_card.isLeftBower(self.trump.?)) {
                return self.trump;
        }
        return led_card.suit;
    }

    /// Returns the number of actions taken
    fn num_actions_taken(self: *const Game) usize {
        inline for (self.actions_taken, 0..) |act, count| {
            if (act == null) return count;
        }
        return self.actions_taken.len;
    }

    /// Returns the number of cards in the center
    fn num_cards_in_center(self: *const Game) usize {
        inline for (self.center, 0..) |card, count| {
            if (card == null) return count;
        }
        return self.center.len;
    }

    /// Returns the most recent action taken or null if no actions have been taken
    fn last_action(self: *const Game) ?Action {
        const acts_taken = self.num_actions_taken();
        if (acts_taken == 0) return null;
        return self.actions_taken[acts_taken-1];
    }

    fn ind_of_action_taken(self: *const Game, action: Action) GameError!usize {
        inline for (self.actions_taken, 0..) |act, ind| {
            if (act == null) return GameError.ActionNotPreviouslyTaken;
            if (act != null and act.? == action) {
                return ind;
            }
        }
        return GameError.ActionNotPreviouslyTaken;
    }

    // //////
    // / Game Logic
    // /////

    /// Take `action` and change the game state to reflect that.
    pub fn step(self: *Game, action: Action) GameError!u2 {
        const legal_acts = self.get_legal_actions();
        var legal = false;
        for (legal_acts) |act| {
            if (act != null and act.? == action) {
                legal = true;
            }
        }
        if (!legal) return GameError.ActionNotLegalGivenGameState;

        switch (@intFromEnum(action) ) {
            @intFromEnum(Action.Pick) => self.perform_pick_action(),
            @intFromEnum(Action.Pass) => try self.perform_pass_action(),
            // Action.Call => self.perform_call_action(action),
            @intFromEnum(Action.CallSpades)...@intFromEnum(Action.CallClubs)=> self.perform_call_action(action),
            @intFromEnum(Action.PlayS9)...@intFromEnum(Action.PlayCA) => {
                try self.perform_play_action(action);

                if (self.num_cards_in_center() == 4) {
                    self.reflect_end_trick();
                }
            },
            @intFromEnum(Action.DiscardS9)...@intFromEnum(Action.DiscardCA) => try self.perform_discard_action(action),
            else => unreachable,
        }

        // Record that I have taken this action
        self.actions_taken[self.num_actions_taken()] = action;

        return self.curr_player_id;
    }

    /// Remove the affects of the last action taken in the game.
    pub fn step_back(self: *Game) GameError!u2 {
        const the_last_action = self.last_action();
        if (the_last_action == null) return GameError.GameHasNotStarted;
        self.actions_taken[self.num_actions_taken()-1] = null;

        switch (the_last_action.?) {
            .Pick => self.undo_pick_action(),
            .Pass => self.undo_pass_action(),
            Action.Call => self.undo_call_action(),
            Action.Play => self.undo_play_action(the_last_action),
            Action.Discard => self.undo_discard_action(the_last_action),
        }

        return self.curr_player_id;
    }

    /// Returns an array of size 6 containing all possible actions a player can take.  
    /// The array is 6 long because at most a player can have 6 choices at once, never more.
    pub fn get_legal_actions(self: *const Game) [6:null]?Action {
        var result: [6:null]?Action = .{null} ** 6;
        const active_player = &self.players[self.curr_player_id];

        var play_hand: bool = true;

        if (active_player.cards_left() == 6) { // dealer must discard
            play_hand = false;
            // exit control flow, will translate whole hand into result for discard action at bottom.
        } else if (self.trump == null) { // deciding trump
            if (self.flipped_choice == null) { // flipped card available
                result[0] = Action.Pick;
                result[1] = Action.Pass;
            } else { // else flipped_choice is TurnedDown, because PickedUp would set trump. All but dealer can pass
                result = .{Action.CallSpades, Action.CallHearts, Action.CallDiamonds, Action.CallClubs, null, null};
                const turned_down_suit_ind: usize = @intFromEnum(self.flipped_card.suit);
                result[turned_down_suit_ind] = result[3];
                result[3] = if (self.curr_player_id == self.dealer_id) null else Action.Pass;
            }
            return result;
        } else if (self.get_led_suit() == null) { 
            // can play any card, exit control flow 
        } else { // either must follow suit, or play any card
            const led_suit = self.get_led_suit().?;
            var num_led_suit_in_hand: u3 = 0;
            for (0..active_player.cards_left()) |ind| {
                const curr_card = active_player.hand[ind].?;

                const is_left: bool = curr_card.isLeftBower(self.trump.?);
                const is_led_suit: bool = curr_card.suit.eq(led_suit);
                if ((!is_left and is_led_suit) or (is_left and self.trump == led_suit)) {
                    result[num_led_suit_in_hand] = Action.fromCard(curr_card, true);
                    num_led_suit_in_hand += 1;
                }
            }

            if (num_led_suit_in_hand > 0) return result; // must follow suit
            // exit control flow, can play any card
        }

        // Here only if I can't follow suit, or I am leading, or I may discard any card in my hand. 
        // Either way I will go through my whole hand.
        for (0..6) |ind| {
            const curr_card = active_player.hand[ind];
            result[ind] = if (curr_card == null) null else Action.fromCard(curr_card.?, play_hand);
        }

        return result;
    }

    /// Changes to game state:
    /// 1. flipped card goes into dealers hand
    /// 2. `curr_player_id` is changed to `dealer_id`
    /// 3. player who called has their id saved into `caller_id`
    /// 4. flipped choice is set to picked up
    ///      - prevents this method from being called again
    /// 5. Trump is set to suit of flipped card
    fn perform_pick_action(self: *Game) void {

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


    /// Changes to game state:
    /// 1. if dealer, set flipped choice to turned down
    /// 2. player is incremented by 1 wrapping
    fn perform_pass_action(self: *Game) GameError!void {
        if (self.curr_player_id == self.dealer_id)
            self.flipped_choice = FlippedChoice.TurnedDown;

        self.curr_player_id +%= 1;
    }

    /// undos this pass action. Assumes it is only called from a valid state
    /// 1. if dealer, set flipped choice to null
    /// 2. player is incremented by 1 wrapping
    fn undo_pass_action(self: *Game) void {
        if (self.curr_player_id == self.dealer_id)
            self.flipped_choice = null;

        self.curr_player_id -%= 1;
    }


    /// Changes to game state:
    /// 1. Trump set to suit of flipped card
    /// 2. current player becomes left of dealer
    /// 3. calling player set to current player
    fn perform_call_action(self: *Game, action: Action) void {
        self.trump = switch (action) {
            .CallSpades => Suit.Spades,
            .CallHearts => Suit.Hearts,
            .CallDiamonds => Suit.Diamonds,
            .CallClubs => Suit.Clubs,
            else => unreachable,
        };

        self.curr_player_id = self.dealer_id +% 1;
        self.caller_id = self.curr_player_id;
    }

    /// undos this call action. Assumes it is only called from a valid state
    /// 1. Sets trump to null
    /// 2. current player becomes caller_id
    /// 3. sets caller id to null
    fn undo_call_action(self: *Game) void {
        self.trump = null;
        self.curr_player_id = self.caller_id;
        self.caller_id = null;
    }


    /// Changes the game state:
    /// 1. removes played card from players hand
    /// 2. adds played card to center
    /// 3. sets current player to player left of current (player_id is one higher, wrapped)
    ///     - If this player plays the 4th (last) card of the trick, another method will overwrite this
    fn perform_play_action(self: *Game, action: Action) !void {
        const card = try action.toCard();
        try self.players[self.curr_player_id].discard_card(&card);

        const open_center_ind = self.num_cards_in_center();
        self.center[open_center_ind] = self.deck.find_card(&card);
 
        self.curr_player_id +%= 1;
    }

    /// undos this play action. Assumes it is only called from a valid state
    /// 1. Depending on whether the last played card ended a trick or not...
    ///     - if it did: (current player won last trick)
    ///         - takes away trick given to winner
    ///         - reset curr_player_id to previous end-of-order player
    ///         - reset center to be full of the 3 cards that came before this one
    ///     - if it did NOT:
    ///         - reset curr_player_id to be one less than current (wrapped)
    ///         - set latest card in center to null
    /// 2. puts the card played back in curr players hand
    fn undo_play_action(self: *Game, action: Action) Player.PlayerError!void {
        if (self.num_cards_in_center() == 0) {
            try self.players[self.curr_player_id].take_away_trick();
            self.curr_player_id = self.previous_last_in_order_id.?;
            const act_ind = try self.ind_of_action_taken(action);
    
            inline for (1..4) |offset| {
                const act_card = try self.actions_taken[act_ind-offset].?.toCard();
                self.center[3-offset] = self.deck.find_card(&act_card);
            }
        } else {
            self.curr_player_id -%= 1;
            self.center[self.num_cards_in_center()-1] = null;
        }

        const card = try action.toCard();
        try self.players[self.curr_player_id].put_card_back_in_hand(self.deck.find_card(&card));
    }


    /// Changes the game state:
    /// 1. sets current player to player left of dealer
    /// 2. remove specified card from dealers hand
    fn perform_discard_action(self: *Game, action: Action) !void {
        const card = try action.toCard();
        try self.players[self.dealer_id].discard_card(&card);
        self.curr_player_id = self.dealer_id +% 1;
    }

    /// undos this discard action. Assumes it is only called from a valid state
    /// 1. sets current player to dealer
    /// 2. adds discarded card to dealers hand
    fn undo_discard_action(self: *Game, action: Action) void {
        const card = try action.toCard();
        self.curr_player_id = self.dealer_id;
        const deck_card = self.deck.find_card(&card);
        self.players[self.dealer_id].pick_up_6th_card(deck_card);
    }


    /// Changes the game state
    /// 1. determines winner of trick. Sets current player to winner
    /// 2. Sets previous end of order id
    /// 3. updates order based on winner
    /// 4. Awards the winner a trick
    /// 5. empties center
    /// 6. Decide if the game is over and handle points as well
    fn reflect_end_trick(self: *Game) void {
        const winner_id = self.judge_trick();
        self.curr_player_id = winner_id;
        self.players[winner_id].award_trick();

        self.previous_last_in_order_id = self.order[3];
        self.order = Game.order_starting_from(winner_id);

        self.center = empty_center;

        // the winner having no more cards implies no one has cards
        if (self.players[self.curr_player_id].cards_left() == 0) {
            self.is_over = true;
            self.scores = self.score_round();
        }
    }


    /// Returns the player_id of the winner.
    /// 
    /// Assumes the game is in a state where center has 4 cards.  
    /// Leverages that indices of cards in center match the id of who played them in `self.order`
    fn judge_trick(self: *Game) u2 {
        var best_player: u2 = self.order[0];
        var best_card: *const Card = self.center[0].?;

        for (1..4) |ind| {
            const card_comparison = self.center[ind].?.gt(best_card, self.trump.?);
            if (card_comparison != null and card_comparison.?) {
                best_card = self.center[ind].?;
                best_player = self.order[ind];
            }
        }
        return best_player;
    }


    /// At the end of the game, determine the scores based on the 5 tricks
    fn score_round(self: *Game) [4]u3 {
        const team_1_tricks: u3 = self.players[0].get_tricks() + self.players[2].get_tricks();
        const team_1_called: bool = if (self.caller_id.? % 2 == 0) true else false;

        if (team_1_tricks == 5) { // team 1 swept
            return .{2, 0, 2, 0};
        } else if (team_1_tricks >= 3) {
            if (team_1_called) { // team 1 won and called no sweep
                return .{1, 0, 1, 0};
            } else {
                return .{2, 0, 2, 0}; // team 1 euchred team 2
            }
        } else if (team_1_tricks > 0) {
            if (team_1_called) { // team 2 euchred team 1
                return .{0, 2, 0, 2};
            } else {
                return .{0, 1, 0, 1}; // team 2 won and called no sweep
            }
        } else { // team 2 swept
            return .{0, 2, 0, 2};
        }
    }

};



const expect = std.testing.expect;

test "create_game" {
    var game = try Game.new(.{ .verbose = false, .seed = 42});
    try game.reset();
    try expect(game.is_over == false);

    for (0..29) |_| {
        if (game.is_over == true) break;
        const acts = game.get_legal_actions();
        _ = try game.step(acts[0].?);
        // std.debug.print("{any}\n", .{acts});
    }
    try expect(game.is_over == true);

}


test "play 10,000 games" {
    // Instead of testing the code verbosely for runtime errors, I will run 10,000 games
    const num_games = 10_000;

    for (0..num_games) |_| {
        var game = try Game.new(.{ .verbose = false});
        try game.reset();
        for (0..29) |_| {
            if (game.is_over == true) break;
            const acts = game.get_legal_actions();
            _ = try game.step(acts[0].?);
        }
        try expect(game.is_over == true);
    }
}