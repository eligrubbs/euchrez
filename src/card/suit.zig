// Implementation of Suits of common playing cards

pub const Suit = enum(u2) {
    Spades,
    Hearts,
    Diamonds,
    Clubs,

    /// Constant for-loop-able array of suits. For consistency,
    /// this range is referenced everywhere something like this could be.
    ///
    /// The order follows the reverse alphabetical convention of some types of Poker
    pub const range: [4]Suit = [4]Suit{
        Suit.Spades,
        Suit.Hearts,
        Suit.Diamonds,
        Suit.Clubs,
    };

    pub const SuitError = error{InvalidChar};

    pub fn char(self: Suit) u8 {
        return switch (self) {
            .Spades => 'S',
            .Clubs => 'C',
            .Diamonds => 'D',
            .Hearts => 'H',
        };
    }

    pub fn FromChar(chr: u8) SuitError!Suit {
        return switch (chr) {
            'S' => .Spades,
            'C' => .Clubs,
            'D' => .Diamonds,
            'H' => .Hearts,
            else => SuitError.InvalidChar,
        };
    }

    /// Returns the the suit of the left bower taking `self` as trump.
    pub fn LeftBowerSuit(self: Suit) Suit {
        return switch (self) {
            .Spades => Suit.Clubs,
            .Hearts => Suit.Diamonds,
            .Diamonds => Suit.Hearts,
            .Clubs => Suit.Spades,
        };
    }

    /// Iterator for suits.
    /// In same order as `Suit.range`
    ///
    /// Recommended use is to call `new()`, although an explicit map can be made.
    pub fn Iterator() type {
        return struct {
            const IterDef = @This();

            suits: [4]Suit,
            index: usize,

            /// Creates a new `SuitIterator`. Must be `var` to actually be useful.
            ///
            /// Example:
            /// ```zig
            /// var suit_iter = SuitIterator.new();
            ///
            /// const is_true = suit_iter.next() == Suit.Spades;
            /// ```
            pub fn new() IterDef {
                return IterDef{
                    .suits = Suit.range,
                    .index = 0,
                };
            }

            pub fn next(self: *IterDef) ?Suit {
                if (self.index >= self.suits.len) return null;
                self.index += 1;
                return self.suits[self.index - 1];
            }
        };
    }
};

test "create_suit" {
    const expect = @import("std").testing.expect;

    const suit = Suit.Clubs;

    try expect(suit == Suit.Clubs);
}

test "suits_equal" {
    const expect = @import("std").testing.expect;

    const left = Suit.Spades;
    const right = Suit.Spades;
    const diff = Suit.Hearts;

    try expect(left == right);
    try expect(right == left);
    try expect(!(diff == right));
}

test "suits_iter" {
    const expect = @import("std").testing.expect;

    const suit_order: [4]Suit = [4]Suit{
        Suit.Spades,
        Suit.Hearts,
        Suit.Diamonds,
        Suit.Clubs,
    };

    for (Suit.range, 0..) |suit, ind| {
        try expect(suit_order[ind] == suit);
    }

    var suit_iter = Suit.Iterator().new();
    var curr_suit = suit_iter.next();
    var ind: usize = 0;
    while (curr_suit != null) : ({
        curr_suit = suit_iter.next();
        ind += 1;
    }) {
        try expect(suit_order[ind] == curr_suit);
    }
}
