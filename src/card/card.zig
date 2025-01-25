// Implementation of playing cards from a common deck of cards.

const Suit = @import("suit.zig").Suit;
const Rank = @import("rank.zig").Rank;


pub const Card = struct {
    suit: Suit,
    rank: Rank,

    
    pub const CardError = error{InvalidSuitChar, InvalidRankChar};

    pub fn str(self: Card) [2]u8 {
        return [2]u8{self.suit.char(), self.rank.char()};
    }

    pub fn from_str(string: *const [2]u8) CardError!Card {
        
        const suit = Suit.from_char(string[0]) catch return CardError.InvalidSuitChar;
        const rank = Rank.from_char(string[1]) catch return CardError.InvalidRankChar;

        return Card{.suit = suit, .rank = rank};
    }

    pub fn eq(self: *const Card, other: *const Card) bool {
        return (self.suit.eq(other.suit) and self.rank.eq(other.rank));
    }
};


const expect = @import("std").testing.expect;
const mem_eq = @import("std").mem.eql;

test "print_card" {
    const card = Card{.suit=Suit.Spades, .rank=Rank.Ten};
    try expect(mem_eq(u8, &card.str(), "ST") );
}

test "from_string" {
    var str_repr = "SA";
    var card = try Card.from_str(str_repr);
    var truth = Card{.suit = Suit.Spades, .rank = Rank.Ace};

    try expect(truth.eq(&card));

    str_repr = "TT";
    const dude = Card.from_str(str_repr);

    try expect(dude == Card.CardError.InvalidSuitChar);

    str_repr = "SS";
    const dude2 = Card.from_str(str_repr);

    try expect(dude2 == Card.CardError.InvalidRankChar);
}
