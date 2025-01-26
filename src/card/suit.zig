// Implementation of Suits of common playing cards

pub const SuitError = error{InvalidChar};

pub const Suit = enum(u2) {
    Spades,
    Hearts,
    Diamonds,
    Clubs,

    pub fn eq(self: Suit, other: Suit) bool {
        return self == other;
    }

    pub fn char(self: Suit) u8 {
        return switch (self) {
            .Spades => 'S',
            .Clubs => 'C',
            .Diamonds => 'D',
            .Hearts => 'H',
        };
    }

    pub fn from_char(chr: u8) SuitError!Suit {
        return switch (chr) {
            'S' => .Spades,
            'C' => .Clubs,
            'D' => .Diamonds,
            'H' => .Hearts,
            else => SuitError.InvalidChar,
        };
    }

    /// Returns the brother suit of `self`.  
    /// This is the suit of the left bower is `self` is trump.
    pub fn BrotherSuit(self: Suit) Suit {
        return switch (self) {
            .Spades => Suit.Clubs,
            .Hearts => Suit.Diamonds,
            .Diamonds => Suit.Hearts,
            .Clubs => Suit.Spades,
        };
    }

    
    /// Constant for-loop-able array of suits. For consistency, 
    /// this range is referenced everywhere something like this could be.
    /// 
    /// The order follows the reverse alphabetical convention of some types of Poker
    pub fn Range() [4]Suit {
        return [4]Suit{Suit.Spades, Suit.Hearts, Suit.Diamonds, Suit.Clubs,};
    }

    /// Iterator for suits.  
    /// In same order as `Suit.Range()` 
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
                return IterDef {
                    .suits = Suit.Range(),
                    .index = 0,
                };
            }

            pub fn next(self: *IterDef) ?Suit {
                if (self.index >= self.suits.len) return null;
                self.index += 1;
                return self.suits[self.index-1];
            }
        };
    }
};


const expect = @import("std").testing.expect;

test "create_suit" {
    const suit = Suit.Clubs;

    try expect(suit == Suit.Clubs);
}

test "suits_equal" {
    const left = Suit.Spades;
    const right = Suit.Spades;
    const diff = Suit.Hearts;

    try expect(left.eq(right));
    try expect(right.eq(left));
    try expect(!diff.eq(right));
}

test "suits_iter" {
    const suit_order: [4]Suit = [4]Suit{Suit.Spades, Suit.Hearts, Suit.Diamonds, Suit.Clubs,};

    for (Suit.Range(), 0..) |suit, ind| {
        try expect(suit_order[ind] == suit);
    }

    var suit_iter = Suit.Iterator().new();
    var curr_suit = suit_iter.next();
    var ind: usize = 0;
    while (curr_suit != null) : ({curr_suit = suit_iter.next(); ind += 1;}) {
        try expect(suit_order[ind] == curr_suit);
    }

}
