// Implementation of card ranks in common playing cards

const Rank = enum(u4) {
    Nine = 9,
    Ten = 10,
    Jack = 11,
    Queen = 12,
    King = 13,
    Ace = 14,

    pub fn eq(self: Rank, other: Rank) bool {
        return self == other;
    }

    pub fn gt(self: Rank, other: Rank) bool {
        self > other;
    }
};

/// Constant for-loop-able array of suits. For consistency, 
/// this range is referenced everywhere something like this could be.
const RankRange: [6]Rank = [4]Rank{Rank.Nine, Rank.Ten, Rank.Jack, Rank.Queen, Rank.King, Rank.Ace};

/// Iterator for Ranks
/// 
/// 
const RankIterator = struct {
    ranks: *const[6]Rank,
    index: usize,

    pub fn new() RankIterator {
        return RankIterator{
            .ranks = &RankRange,
            .index = 0,
        };
    }

    pub fn next(self: *RankIterator) ?Rank {
        if (self.index >= self.ranks.len) return null;
        self.index += 1;
        return self.ranks[self.index-1];
    }
};