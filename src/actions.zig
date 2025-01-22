// Each action that can be taken in the game is represented by a number.  
// This explicitness lends itself well if this code were to be utilized to write bots
// or potentially deep learning algorithms

const std = @import("std");

const Action = enum(u6) {
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
};


const FlippedChoice = enum(u1) {
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
