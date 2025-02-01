// The `Game` struct contains logic and exposes API's to run a game of euchre.  
// While Euchre is a 4 player game, the API exposes a simple `step` function.

const std = @import("std");

const Card = @import("card/card.zig").Card;
const Suit = @import("card/suit.zig").Suit;
const Rank = @import("card/rank.zig").Rank;
const Deck = @import("deck.zig").Deck;
const Action = @import("action.zig").Action;
const Player = @import("player.zig").Player;
const PlayerId: type = @import("player.zig").PlayerId;
const FlippedChoice = @import("action.zig").FlippedChoice;
const NullSentinelArray = @import("nullarray.zig").NullSentinelArray;

pub const Turn: type = struct{PlayerId,Action};
pub const TurnsTaken: type = NullSentinelArray(Turn, 29);
pub const LegalActions: type = NullSentinelArray(Action, 7);
pub const CenterCards: type = NullSentinelArray(Card, 4);

pub const Game = struct {
    const num_players = 4; // do not change
    const empty_center: CenterCards = CenterCards.new();
    const Winners: type = NullSentinelArray(PlayerId, 5);

    config: GameConfig,
    prng: std.Random.DefaultPrng,

    was_initialized: bool, // make sure that reset is called before calling other methods
    is_over: bool,
    scores: ?[4]u3, // scores not null only at end of game

    deck: Deck,

    players: [4]Player,
    dealer_id: PlayerId,
    curr_player_id: PlayerId,
    caller_id: ?PlayerId,
    called_alone: ?bool,

    flipped_card: Card,
    flipped_choice: ?FlippedChoice,

    order: [4]PlayerId,
    previous_winners: Winners,
    center: CenterCards, // 4 is maximum number of cards that can be in the middle
    trump: ?Suit,

    turns_taken: TurnsTaken, // maximum number of actions there can be in a euchre game.

    const GameError = error {
        ActionNotLegalGivenGameState,
        NotPlayable,
        TrumpNotSet,
        GameHasNotStarted,
        GameIsOver,
        KittyCardNotAvailable,
        DealerMustCallAfterTurnedDownKittyCard,
        TrumpAlreadySet,
        ActionNotPreviouslyTaken,
    } || Player.PlayerError || Card.CardError || Action.ActionError || CenterCards.ArrayError;

    pub const GameConfig = struct {
        /// Determines whether to print out to stdout the events of the game
        verbose: bool = false,
        /// Specify the dealer or `null` for a random dealer every `reset` unless `seed` is set.
        dealer_id: ?PlayerId = null,
        /// Specify the seed for consistent `reset` results or `null` for random `reset` every time.
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

            .deck = Deck.new(),

            .players = undefined,
            .dealer_id = undefined,
            .curr_player_id = undefined,
            .caller_id = null,
            .called_alone = null,

            .flipped_card = undefined,
            .flipped_choice = null,

            .order = undefined,
            .previous_winners = Winners.new(),
            .center = empty_center,
            .trump = null,

            .turns_taken = TurnsTaken.new(),
        };

    }

    /// Resets the game state to a valid beginning state.
    /// 
    /// Reuses the config passed in when `new` was called.
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

        Deck.fillUnshuffled(&self.deck.card_buffer);
        self.prng.random().shuffle(Card, &self.deck.card_buffer);

        self.players[0] = try Player.new(0, try self.deck.DealFiveCards());
        self.players[1] = try Player.new(1, try self.deck.DealFiveCards());
        self.players[2] = try Player.new(2, try self.deck.DealFiveCards());
        self.players[3] = try Player.new(3, try self.deck.DealFiveCards());

        self.dealer_id = if (self.config.dealer_id != null) self.config.dealer_id.? else self.prng.random().int(PlayerId);
        self.curr_player_id = self.dealer_id +% 1;
        self.caller_id = null;
        self.called_alone = null;

        self.flipped_card = try self.deck.DealOneCard();
        self.flipped_choice = null;

        self.order = self.order_starting_from(self.curr_player_id);
        self.previous_winners = Winners.new();
        self.center = empty_center;
        self.trump = null;

        self.turns_taken = TurnsTaken.new();
    }

    /// Returns the order of the rest of the players if `p_id` is assumed to go first.
    /// Takes into consideration a game where someone called trump. The last player will be the skipped player
    fn order_starting_from(self: *const Game, p_id: PlayerId) [4]PlayerId {
        if (self.called_alone != null and self.called_alone.?) {
            std.debug.assert(p_id != self.caller_id.? +% 2);
            const second_to_go = self.player_after(p_id);
            const third_to_go = self.player_after(second_to_go);
            return .{p_id, second_to_go, third_to_go, self.caller_id.? +% 2};
        }
        return .{p_id, p_id +% 1, p_id +% 2, p_id +% 3};
    }

    /// Returns the effective suit of the game
    /// If there is no effective suit, return null
    fn get_led_suit(self: *const Game) ?Suit {
        if (self.center.get(0) == null or self.trump == null) return null;

        const led_card = self.center.get(0).?;
        if (led_card.isLeftBower(self.trump.?)) {
                return self.trump;
        }
        return led_card.suit;
    }

    /// Returns the most recent action taken or null if no actions have been taken
    fn last_action(self: *const Game) ?Turn {
        const acts_taken = self.turns_taken.num_left();
        if (acts_taken == 0) return null;
        return self.turns_taken.get(acts_taken-1);
    }

    /// Returns the id of the next player, making considerations for a game where someone chose to go alone.
    fn player_after(self: *const Game, p_id: PlayerId) PlayerId {
        // add 2 to current player if the player to skip would be next
        const offset: u2 = if (self.called_alone != null and self.called_alone.? and self.caller_id.? == p_id -% 1) 2 else 1;
        return p_id +% offset;
    }

    /// Returns the id of the previous player, making considerations for a game where someone chose to go alone.
    fn player_before(self: *const Game, p_id: PlayerId) PlayerId {
        // remove 2 from current player if the player to skip is to my right (before me)
        const offset: u2 = if (self.called_alone != null and self.called_alone.? and self.caller_id.? == p_id +% 1) 2 else 1;
        return p_id -% offset;
    }

    // //////
    // / Game Logic
    // /////

    /// Take `action` and change the game state to reflect that.
    /// 
    /// Will return errors if the action is not allowed in this state, or the game is over.
    pub fn step(self: *Game, action: Action) GameError!struct {PlayerId, ScopedState} {
        if (self.is_over) return GameError.GameIsOver;

        // impossible if player is curr_player and their partner called it alone, unless they are the dealer to discard
        if (self.called_alone != null and self.called_alone.? and self.dealer_id != self.curr_player_id) 
            std.debug.assert(self.curr_player_id != self.caller_id.? +% 2);

        const legal_acts = self.get_legal_actions();
        const old_player = self.curr_player_id;
        const legal = (legal_acts.find(action) catch 10) < legal_acts.num_left();

        if (!legal) return GameError.ActionNotLegalGivenGameState;

        switch (@intFromEnum(action) ) {
            @intFromEnum(Action.Pick)...@intFromEnum(Action.PickAlone) => self.perform_pick_action(action),
            @intFromEnum(Action.Pass) => self.perform_pass_action(),
            @intFromEnum(Action.CallSpades)...@intFromEnum(Action.CallClubsAlone)=> self.perform_call_action(action),
            @intFromEnum(Action.PlayS9)...@intFromEnum(Action.PlayCA) => self.perform_play_action(action),
            @intFromEnum(Action.DiscardS9)...@intFromEnum(Action.DiscardCA) => self.perform_discard_action(action),
            else => unreachable,
        }

        // Record that I have taken this action. above code (get_legal_actions) gurantees this will work.
        self.turns_taken.push(.{old_player, action}) catch unreachable;

        // std.debug.print(" {d}\n", .{self.curr_player_id});
        return .{self.curr_player_id, self.get_scoped_state()};
    }

    /// Remove the affects of the last action taken in the game.
    pub fn step_back(self: *Game) GameError!struct {PlayerId, ScopedState} {
        if (self.is_over) self.is_over = false;

        const the_last_turn = self.last_action();
        if (the_last_turn == null) return GameError.GameHasNotStarted;

        const the_last_action = the_last_turn.?[1];

        switch (@intFromEnum(the_last_action)) {
            @intFromEnum(Action.Pick)...@intFromEnum(Action.PickAlone) => self.undo_pick_action(),
            @intFromEnum(Action.Pass) => self.undo_pass_action(),
            @intFromEnum(Action.CallSpades)...@intFromEnum(Action.CallClubsAlone) => self.undo_call_action(),
            @intFromEnum(Action.PlayS9)...@intFromEnum(Action.PlayCA) => self.undo_play_action(the_last_action),
            @intFromEnum(Action.DiscardS9)...@intFromEnum(Action.DiscardCA) => self.undo_discard_action(the_last_action),
            else => unreachable,
        }

        // remove the action
        _ = self.turns_taken.pop();

        return .{self.curr_player_id, self.get_scoped_state()};
    }

    /// Returns an array of size 7 containing all possible actions a player can take.  
    /// The array is 7 long because at most a player can have 7 choices at once, never more.
    pub fn get_legal_actions(self: *const Game) LegalActions {
        var result: LegalActions = LegalActions.new();
        if (self.is_over) return result;

        const active_player = &self.players[self.curr_player_id];

        var play_hand: bool = true;

        if (active_player.cards_left() == 6) { // dealer must discad
            // exit control flow, will translate whole hand into result for discard action at bottom.
            play_hand = false;

        } else if (self.trump == null) { // deciding trump

            if (self.flipped_choice == null) { // flipped card available
    
                result.push(Action.Pick) catch unreachable;
                result.push(Action.PickAlone) catch unreachable;
                result.push(Action.Pass) catch unreachable;

            } else { // else flipped_choice is TurnedDown, because PickedUp would set trump. All but dealer can pass

                result.push(Action.CallSpades) catch unreachable;
                result.push(Action.CallHearts) catch unreachable;
                result.push(Action.CallDiamonds) catch unreachable;
                result.push(Action.CallClubs) catch unreachable;
                // works because I pushed into `result` using same order as Suit.range
                result.remove_ind( @intFromEnum(self.flipped_card.suit) );

                result.push(Action.CallSpadesAlone) catch unreachable;
                result.push(Action.CallHeartsAlone) catch unreachable;
                result.push(Action.CallDiamondsAlone) catch unreachable;
                result.push(Action.CallClubsAlone) catch unreachable;
                // works because I pushed into `result` using same order as Suit.range
                // need u3 conversion since suit is of u2. 2 added since 0 based indexing
                result.remove_ind(2 + @as(u3, @intFromEnum(self.flipped_card.suit)));

                result.push( if (self.curr_player_id == self.dealer_id) null else Action.Pass ) catch unreachable;
            }

            return result;

        } else if (self.get_led_suit() == null) { 
            // can play any card, exit control flow 

        } else { // either must follow suit, or play any card
            const led_suit = self.get_led_suit().?;

            for (0..active_player.cards_left()) |ind| {
                const curr_card = active_player.hand.get(ind).?;

                const is_left: bool = curr_card.isLeftBower(self.trump.?);
                const is_led_suit: bool = curr_card.suit.eq(led_suit);
                if ((!is_left and is_led_suit) or (is_left and self.trump == led_suit)) {
                    result.push(Action.FromCard(curr_card, true)) catch unreachable;
                }
            }

            if (result.num_left() > 0) return result; // must follow suit
            // exit control flow, can play any card
        }

        // Here only if I can't follow suit, or I am leading, or I may discard any card in my hand. 
        // Either way I will go through my whole hand.
        for (0..6) |ind| {
            const curr_card = active_player.hand.get(ind);
            result.push( if (curr_card == null) null else Action.FromCard(curr_card.?, play_hand) ) catch unreachable;
        }

        return result;
    }

    /// Returns the state of the game as `current_actor` sees it.
    pub fn get_scoped_state(self: *const Game) ScopedState {
        const scoped_state = ScopedState{
            .dealer_actor = self.dealer_id,
            .current_actor = self.curr_player_id,
            .hand = self.players[self.curr_player_id].hand,

            .calling_actor = self.caller_id,
            .called_alone = self.called_alone,
            .flipped_choice = self.flipped_choice,
            .flipped_card = self.flipped_card,

            .trump = self.trump,

            .led_suit = self.get_led_suit(),

            .order = self.order,
            .center = self.center,

            .turns_taken = self.turns_taken,

            .legal_actions= self.get_legal_actions(),
        };
        return scoped_state;
    }

    /// Changes to game state:
    /// 1. flipped card goes into dealers hand
    /// 2. player who called has their id saved into `caller_id`
    /// 3. `curr_player_id` is changed to `dealer_id`
    /// 4. flipped choice is set to picked up
    ///      - prevents this method from being called again in `legal_actions`
    /// 5. Trump is set to suit of flipped card
    /// 6. Determine if the pick was to go alone
    fn perform_pick_action(self: *Game, action: Action) void {
        self.players[self.dealer_id].pick_up_6th_card(self.flipped_card) catch unreachable;
        self.caller_id = self.curr_player_id;
        self.curr_player_id = self.dealer_id;
        self.flipped_choice = FlippedChoice.PickedUp;
        self.trump = self.flipped_card.suit;
        self.called_alone = (action == Action.PickAlone);
    }

    /// Mirror image of `perform_pick_action`
    fn undo_pick_action(self: *Game) void {
        self.trump = null;
        self.flipped_choice = null;
        self.curr_player_id = self.caller_id.?;
        self.caller_id = null;
        self.players[self.dealer_id].discard_card(self.flipped_card) catch unreachable;
        self.called_alone = null;
    }


    /// Changes to game state:
    /// 1. if dealer, set flipped choice to turned down
    /// 2. player is incremented by 1 wrapping
    fn perform_pass_action(self: *Game) void {
        if (self.curr_player_id == self.dealer_id)
            self.flipped_choice = FlippedChoice.TurnedDown;

        self.curr_player_id +%= 1;
    }

    /// Mirror image of `perform_pass_action`
    fn undo_pass_action(self: *Game) void {
        self.curr_player_id -%= 1;

        if (self.curr_player_id == self.dealer_id)
            self.flipped_choice = null;
    }


    /// Changes to game state:
    /// 1. Trump set to suit of flipped card
    /// 2. Determines if the call was to go alone
    /// 3. calling player set to current player
    /// 4. current player becomes left of dealer unless right of dealer went alone
    /// 5. updates the order of play
    ///     - This is important because if someone called it alone, want to skip them
    fn perform_call_action(self: *Game, action: Action) void {
        const act_num = @intFromEnum(action);
        std.debug.assert(act_num >= 48 and act_num < 56);
        self.trump = Suit.range[act_num % 4];

        self.called_alone = (act_num >= 52);

        self.caller_id = self.curr_player_id;
        self.curr_player_id = self.player_after(self.dealer_id);
        self.order = self.order_starting_from(self.curr_player_id);
    }

    /// Mirror image of `perform_call_action`
    fn undo_call_action(self: *Game) void {
        self.curr_player_id = self.caller_id.?;
        self.caller_id = null;
        self.called_alone = null;
        self.trump = null;
        self.order = self.order_starting_from(self.dealer_id +% 1);
    }


    /// Changes the game state:
    /// 1. removes played card from players hand
    /// 2. adds played card to center
    /// 3. Handles trick end logic OR sets current player to player on the left (+1 wrapping)
    /// 
    /// Trick end logic:
    ///     1. Determine winner and add winner to `previous_winner` stack. Award them a trick
    ///     2. Save that the current player (who ended trick) as the previous last trick ender
    ///     3. Reset order based on winner and empty center
    ///     4. Set current player to winner
    ///     5. If winners hand == empty then game is over
    fn perform_play_action(self: *Game, action: Action) void {
        const card = action.ToCard() catch unreachable;
        self.players[self.curr_player_id].discard_card(card) catch unreachable;

        std.debug.assert(self.called_alone != null);
        std.debug.assert(self.center.num_left() < 4); // there is room
        std.debug.assert(!self.called_alone.? or (self.center.num_left() < 3)); // there is room if someone called alone
        self.center.push(card) catch unreachable;

        if (self.center.num_left() == 4 or (self.center.num_left() == 3 and self.called_alone.?)) { // end trick
            const winner_id = self.judge_trick();
            self.previous_winners.push(winner_id) catch unreachable;
            self.players[winner_id].award_trick();


            self.order = self.order_starting_from(winner_id);
            self.center = empty_center;

            // set next player to the winner, even if game is over now
            self.curr_player_id = winner_id;
            // the winner having no more cards implies no one has cards
            if (self.players[self.curr_player_id].cards_left() == 0) {
                self.is_over = true;
                self.scores = self.score_round();
            }
        } else {
            self.curr_player_id = self.player_after(self.curr_player_id);
        }
        // the next player can't be the partner of the player who went alone
        if (self.called_alone.?) std.debug.assert(self.curr_player_id != self.caller_id.? +% 2);
    }

    /// Mirror image of `perform_play_action`
    fn undo_play_action(self: *Game, action: Action) void {
        const card = action.ToCard() catch unreachable;

        std.debug.assert(self.called_alone != null);
        if (self.center.num_left() == 0) { // this action ended a trick
            // if no one calls, it takes at least 6 turns to get to a trick end (pick, discard, 4 plays)
            // else it takes at least 5 (pick, discard, 3 plays)
            const num_turns = self.turns_taken.num_left();
            std.debug.assert((num_turns > 5 and ! self.called_alone.?) or (num_turns > 4 and self.called_alone.?));

            if (self.players[self.curr_player_id].cards_left() == 0) {
                self.is_over = false;
                self.scores = null;
            }
            // current player is the winner of this trick, so make it the person who played the card
            // that ended this trick
            self.curr_player_id = self.turns_taken.get(num_turns-1).?[0];

            // number 2 and number 3 in this loop
            const called_alone_offset: usize = if (self.called_alone != null and self.called_alone.?) 3 else 4;
            for (0..called_alone_offset) |offset| {
                // goes from -4, -3, -2, -1 from num_turns
                // or from -3, -2, -1 if called alone
                const last_turn = self.turns_taken.get(num_turns - called_alone_offset + offset).?;
                const act_card = last_turn[1].ToCard() catch unreachable;
                self.order[offset] = last_turn[0];
                self.center.push(act_card) catch unreachable;
            }
            std.debug.assert(self.center.num_left() == 4 or (self.center.num_left() == 3 and self.called_alone != null and self.called_alone.?));

            // current player right now was the winner
            const old_winner = self.previous_winners.pop().?;
            self.players[old_winner].take_away_trick() catch unreachable;

        } else {
            std.debug.assert(self.center.num_left() < 4 and self.center.num_left() > 0);
            self.curr_player_id = self.player_before(self.curr_player_id);
        }

        _ = self.center.pop();
        self.players[self.curr_player_id].put_card_back_in_hand(card) catch unreachable;
    }


    /// Changes the game state:
    /// 1. remove specified card from dealers hand
    /// 2. sets current player to player left of dealer unless the player to the right called alone
    /// 3. If someone called it alone, update the order of play to make sure their partner doesn't have a turn
    fn perform_discard_action(self: *Game, action: Action) void {
        const card = action.ToCard() catch unreachable;
        self.players[self.dealer_id].discard_card(card) catch unreachable;
        self.curr_player_id = self.player_after(self.dealer_id);
        self.order = self.order_starting_from(self.curr_player_id);
    }

    /// Mirror image of `perform_discard_action`
    /// Order is not used before the discard stage, so we don't undo that
    fn undo_discard_action(self: *Game, action: Action) void {
        self.curr_player_id = self.dealer_id;
        std.debug.assert(self.players[self.dealer_id].hand.num_left() == 5);
        const deck_card = action.ToCard() catch unreachable;
        self.players[self.dealer_id].pick_up_6th_card(deck_card) catch unreachable;
    }

    /// Returns the player_id of the winner.
    /// 
    /// Asserts the game is in a state where center has 4 cards or 3 cards if someone called alone.  
    /// Leverages that indices of cards in center match the id of who played them in `self.order`
    fn judge_trick(self: *Game) PlayerId {
        std.debug.assert(self.called_alone != null);
        std.debug.assert(self.center.num_left() == 4 or (self.center.num_left() == 3 and self.called_alone.?));

        var best_player: PlayerId = self.order[0];
        var best_card: Card = self.center.get(0).?;

        const end_considering_going_alone: usize = if(self.called_alone.?) 3 else 4;
        for (1..end_considering_going_alone) |ind| {
            const card_comparison = self.center.get(ind).?.gt(best_card, self.trump.?);
            if (card_comparison != null and card_comparison.?) {
                best_card = self.center.get(ind).?;
                best_player = self.order[ind];
                // winner can't be partner of player who went alone
                if (self.called_alone.?) std.debug.assert(best_player != self.caller_id.? +% 2);
            }
        }
        return best_player;
    }


    /// At the end of the game, determine the scores based on the 5 tricks
    fn score_round(self: *Game) [4]u3 {
        std.debug.assert(self.called_alone != null);
        const team_1_tricks: u3 = self.players[0].get_tricks() + self.players[2].get_tricks();
        const team_1_called: bool = self.caller_id.? % 2 == 0;
        const team_1_went_alone: bool = self.called_alone.? and team_1_called;

        if (team_1_tricks == 5) { // team 1 swept
            if (team_1_went_alone) return .{4, 0, 4, 0};
            return .{2, 0, 2, 0};
        } else if (team_1_tricks >= 3) {
            if (team_1_called) return .{1, 0, 1, 0}; // team 1 won and called. no sweep
            return .{2, 0, 2, 0}; // team 1 euchred team 2
        } else if (team_1_tricks > 0) {
            if (team_1_called) return .{0, 2, 0, 2}; // team 2 euchred team 1
            return .{0, 1, 0, 1}; // team 2 won and called. no sweep
        } else { // team 2 swept
            if (!team_1_went_alone) return .{0, 4, 0, 4};
            return .{0, 2, 0, 2};
        }
    }

};


pub const ScopedState = struct {
    dealer_actor: PlayerId,
    current_actor: PlayerId,
    hand: Player.Hand,

    calling_actor: ?PlayerId,
    called_alone: ?bool,
    flipped_choice: ?FlippedChoice,
    flipped_card: Card,

    trump: ?Suit,

    led_suit: ?Suit,

    order: [4]PlayerId,
    center: CenterCards,

    turns_taken: TurnsTaken,

    legal_actions: LegalActions,
};


test "create_game" {
    const expect = std.testing.expect;

    var game = try Game.new(.{ .verbose = false, .seed = 42});
    try game.reset();
    try expect(game.is_over == false);

    for (0..29) |_| {
        if (game.is_over == true) break;
        const acts = game.get_legal_actions();
        _ = try game.step(acts.get(0).?);
        // std.debug.print("{any}\n", .{acts});
    }
    try expect(game.is_over == true);

}


test "play 10,000 games randomly" {
    const expect = std.testing.expect;

    // Instead of testing the code verbosely for runtime errors, I will run 10,000 games
    const num_games = 10_000;

    var prng = std.Random.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                try std.posix.getrandom(std.mem.asBytes(&seed));
                break :blk seed;
    });

    for (0..num_games) |_| {
        var game = try Game.new(.{ .verbose = false});
        try game.reset();
        for (0..29) |_| {
            if (game.is_over == true) break;

            const acts = game.get_legal_actions();
            const act = acts.get(prng.random().intRangeAtMost(usize, 1, acts.num_left())-1);
        
            _ = try game.step(act.?);
        }
        try expect(game.is_over == true);

        // step back through the whole game
        while (true) {
           const turn = game.step_back() catch break;
           _ = turn;
        }
    }
}