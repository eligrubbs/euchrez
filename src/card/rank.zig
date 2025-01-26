// Implementation of card ranks in common playing cards



pub const Rank = enum(u4) {
    Nine = 9,
    Ten = 10,
    Jack = 11,
    Queen = 12,
    King = 13,
    Ace = 14,

    /// Constant for-loop-able array of suits. For consistency, 
    /// this range is referenced everywhere something like this could be.
    pub const range:  [6]Rank = [6]Rank{Rank.Nine, Rank.Ten, Rank.Jack, Rank.Queen, Rank.King, Rank.Ace};

    pub const RankError = error{InvalidChar};

    pub fn eq(self: Rank, other: Rank) bool {
        return self == other;
    }

    pub fn gt(self: Rank, other: Rank) bool {
        return @intFromEnum(self) > @intFromEnum(other);
    }

    pub fn char(self: Rank) u8 {
        return switch (self) {
            .Nine => '9',
            .Ten => 'T',
            .Jack => 'J',
            .Queen => 'Q',
            .King => 'K',
            .Ace => 'A',
        };
    }

    pub fn from_char(chr: u8) RankError!Rank {
        return switch (chr) {
            '9' => .Nine,
            'T' => .Ten,
            'J' => .Jack,
            'Q' => .Queen,
            'K' => .King,
            'A' => .Ace,
            else => RankError.InvalidChar,
        };
    }

    pub fn Iterator() type {
        return struct {
            const IterDef = @This();

            ranks: [6]Rank,
            index: usize,

            pub fn new() IterDef {
                return IterDef {
                    .ranks = Rank.RankRange(),
                    .index = 0,
                };
            }

            pub fn next(self: *IterDef) ?Rank {
                if (self.index >= self.ranks.len) return null;
                self.index += 1;
                return self.ranks[self.index-1];
            }
        };
    }

};



const expect = @import("std").testing.expect;

test "get_char" {
    const rank = Rank.Nine;

    try expect(rank.char() == '9');
}