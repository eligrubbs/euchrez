// Implementation of playing cards from a common deck of cards.

const Suit = @import("suit.zig").Suit;
const Rank = @import("rank.zig").Rank;

const Card = struct {
    suit: Suit,
    rank: Rank,
};

