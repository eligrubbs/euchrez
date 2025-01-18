// Implementation of Suits of common playing cards



const Suit = enum(u2) {
    Spades,
    Clubs,
    Diamonds,
    Hearts,

    pub fn eq(self: Suit, other: Suit) bool {
        return self == other;
    }
};

/// Constant for-loop-able array of suits. For consistency, 
/// this range is referenced everywhere something like this could be.
const SuitRange: [4]Suit = [4]Suit{Suit.Spades, Suit.Clubs, Suit.Diamonds, Suit.Hearts};

/// Iterator for suits.  
/// Order is Spades, Clubs, Diamonds, Hearts  
/// 
/// Recommended use is to call `new()`, although an explicit map can be made.
const SuitIterator = struct {
    suits: *const [4]Suit,
    index: usize,

    /// Creates a new `SuitIterator`. Must be `var` to actually be useful.
    /// 
    /// Example:  
    /// ```zig
    /// var suit_iter = SuitIterator.new();
    /// 
    /// const is_true = suit_iter.next() == Suit.Spades;
    /// ```
    pub fn new() SuitIterator {
        return SuitIterator{
            .suits = &SuitRange,
            .index = 0,
        };
    }

    pub fn next(self: *SuitIterator) ?Suit {
        if (self.index >= self.suits.len) return null;
        self.index += 1;
        return self.suits[self.index-1];
    }
};

//
//
// Tests Below
//
//

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
    const suit_order: [4]Suit = [4]Suit{Suit.Spades, Suit.Clubs, Suit.Diamonds, Suit.Hearts};

    for (SuitRange, 0..) |suit, ind| {
        try expect(suit_order[ind] == suit);
    }

    var suit_iter = SuitIterator.new();
    var curr_suit = suit_iter.next();
    var ind: usize = 0;
    while (curr_suit != null) : ({curr_suit = suit_iter.next(); ind += 1;}) {
        try expect(suit_order[ind] == curr_suit);
    }

}
