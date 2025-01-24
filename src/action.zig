// Each action that can be taken in the game is represented by a number.  
// This explicitness lends itself well if this code were to be utilized to write bots
// or potentially deep learning algorithms

const std = @import("std");
const utils = @import("utils.zig");

const Card = @import("card/card.zig").Card;
const Suit = @import("card/suit.zig").Suit;
const Rank = @import("card/rank.zig").Rank;

pub const Action = enum(u6) {
    pub const PickPass = utils.enumFieldRange(@This(), .Pick, .Pass);
    pub const Call = utils.enumFieldRange(@This(), .CallSpades, .CallClubs);
    pub const Play = utils.enumFieldRange(@This(), .PlayS9, .PlayCA);
    pub const Discard = utils.enumFieldRange(@This(), .DiscardS9, .DiscardCA);

    const total_actions = 54; // do not change

    // Whether to call or pass on the flipped card
    Pick, Pass,

    // although not necessary, this order matches that of `Suit.Range()`
    CallSpades, CallHearts, CallDiamonds, CallClubs, 

    // Play actions
    PlayS9, PlayST, PlaySJ, PlaySQ, PlaySK, PlaySA,
    PlayH9, PlayHT, PlayHJ, PlayHQ, PlayHK, PlayHA,
    PlayD9, PlayDT, PlayDJ, PlayDQ, PlayDK, PlayDA,
    PlayC9, PlayCT, PlayCJ, PlayCQ, PlayCK, PlayCA,

    // Discard actions
    DiscardS9, DiscardST, DiscardSJ, DiscardSQ, DiscardSK, DiscardSA,
    DiscardH9, DiscardHT, DiscardHJ, DiscardHQ, DiscardHK, DiscardHA,
    DiscardD9, DiscardDT, DiscardDJ, DiscardDQ, DiscardDK, DiscardDA,
    DiscardC9, DiscardCT, DiscardCJ, DiscardCQ, DiscardCK, DiscardCA,

    const ActionError = error{
        IntOutOfRange,
        StrNotConvertable,
        NotConvertableToCard,
    };

    pub fn toInt(self: Action) u6 {
        return @intFromEnum(self);
    }

    pub fn fromInt(integer: u6) ActionError!Action {
        if (integer >= total_actions) return ActionError.IntOutOfRange;
        return @enumFromInt(integer);
    }

    pub fn fromStr(str: []const u8) ActionError!Action {
        if (std.meta.stringToEnum(Action, str)) |dude| {
            return dude;
        }
        return ActionError.StrNotConvertable;
    }

    pub fn fromCard(card: *const Card, to_play: bool ) Action {
        const suit_num: u6 = @as(u6, @intFromEnum(card.suit)) + 1;
        const rank_num: u6 = @intFromEnum(card.rank) - 9;
        const discard_offset: u6 = if (to_play == true) 0 else 24;
        const num = rank_num + (suit_num * 6) + discard_offset;
        return @enumFromInt(num);
    }

    pub fn toCard(self: Action) ActionError!Card {
        const num: u6 = @intFromEnum(self);
        if (num < 6) return ActionError.NotConvertableToCard;
        const rank_num = (num % 6) + 9;
        const suit_num = (( (if (num > 29) num + 6 else num) % 30) / 6) - 1;

        return Card{.suit = @enumFromInt(suit_num), .rank = @enumFromInt(rank_num)};
    }

};


pub const FlippedChoice = enum(u1) {
    PickedUp,
    TurnedDown,
};


const expect = std.testing.expect;
const expectErr = std.testing.expectError;

test "action_from_str" {
    const act_str = "Pick";

    const act = try Action.fromStr(act_str[0..]);

    try expect(act == Action.Pick);

    try expectErr(Action.ActionError.StrNotConvertable, Action.fromStr("playS9"));
}

test "action_from_card" {
    var card = try Card.from_str("S9");

    var act = Action.fromCard(&card, true);
    try expect(act == Action.PlayS9);

    var act_d = Action.fromCard(&card, false);
    try expect(act_d == Action.DiscardS9);

    card = try Card.from_str("CA");

    act = Action.fromCard(&card, true);
    try expect(act == Action.PlayCA);

    act_d = Action.fromCard(&card, false);
    try expect(act_d == Action.DiscardCA);
}

test "card_from_action" {
    var act = Action.PlayC9;
    const card = try act.toCard();
    try expect(card.eq(&try Card.from_str("C9")));
}