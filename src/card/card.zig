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

    /// Returns true if this card is greater than `other`.
    /// false automatically if the cards suits are different and trump is null or does not apply
    pub fn gt(self: *const Card, other: *const Card, trump: ?Suit) ?bool {
        if (trump == null) {
            if (self.suit != other.suit) return null;
            return self.rank.gt(other.rank);
        }

        const self_eff_suit = if (self.isLeftBower(trump.?)) trump.? else self.suit;
        const other_eff_suit = if (other.isLeftBower(trump.?)) trump.? else other.suit;

        if (self_eff_suit == other_eff_suit) {
            if (self_eff_suit == trump.?) { // handle bower edge cases if trump
                if (self.isRightBower(trump.?)) return true;
                if (other.isRightBower(trump.?)) return false;
                // neither are right bower now
                if (self.isLeftBower(trump.?)) return true;
                if (other.isLeftBower(trump.?)) return false;
            }
            return self.rank.gt(other.rank);
        } else if (self_eff_suit == trump.?) {
            return true;
        } else if (other_eff_suit == trump.?) {
            return false;
        }
        // don't have same suit and neither are trump, therefore not comparable -> false
        return null;
    }

    /// Given a trump suit, return true if this card is the left bower.
    pub fn isLeftBower(self: *const Card, trump: Suit) bool {
        return (self.rank == Rank.Jack) and self.suit == trump.BrotherSuit();
    }

    /// Given a trump suit, return true if this card is the right bower
    pub fn isRightBower(self: *const Card, trump: Suit) bool {
        return (self.rank == Rank.Jack) and self.suit == trump;
    }

    /// Given a trump suit, returns whether `self` is trump or not.
    pub fn isTrump(self: *const Card, trump: Suit) bool {
        return self.suit == trump or self.isLeftBower(trump);
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

test "is_left" {
    var trump = Suit.Spades;

    var card = try Card.from_str("H9");
    try expect(!card.isLeftBower(trump));
    card = try Card.from_str("HJ");
    try expect(!card.isLeftBower(trump));
    card = try Card.from_str("CJ"); // Is left!
    try expect(card.isLeftBower(trump));
    card = try Card.from_str("SJ");
    try expect(!card.isLeftBower(trump));
    
    trump = Suit.Diamonds;
    card = try Card.from_str("DJ");
    try expect(!card.isLeftBower(trump));
    card = try Card.from_str("D9");
    try expect(!card.isLeftBower(trump));
    card = try Card.from_str("HJ");
    try expect(card.isLeftBower(trump));

}

test "cards_greater_than" {
    // Test No Trump
    var card1 = try Card.from_str("S9");
    var card2 = try Card.from_str("S9");

    try expect(!card1.gt(&card2, null).?);
    card2 = try Card.from_str("ST");
    try expect(!card1.gt(&card2, null).?);
    try expect(card2.gt(&card1, null).?);
    card2 = try Card.from_str("SA");
    try expect(!card1.gt(&card2, null).?);
    try expect(card2.gt(&card1, null).?);

    card2 = try Card.from_str("HA");
    try expect(card1.gt(&card2, null) == null);
    try expect(card2.gt(&card1, null) == null);

    // Test Trump

    var trump = Suit.Clubs;

    // Tests from above should still pass even if trump is passed in
    card1 = try Card.from_str("S9");
    card2 = try Card.from_str("S9");
    try expect(!card1.gt(&card2, trump).?);
    card2 = try Card.from_str("ST");
    try expect(!card1.gt(&card2, trump).?);
    try expect(card2.gt(&card1, trump).?);
    card2 = try Card.from_str("SA");
    try expect(!card1.gt(&card2, trump).?);
    try expect(card2.gt(&card1, trump).?);

    // Test left bower
    trump = Suit.Hearts;
    card1 = try Card.from_str("DJ");
    card2 = try Card.from_str("HA");
    try expect(card1.gt(&card2, trump).?);
    try expect(!card2.gt(&card1, trump).?);

    card2 = try Card.from_str("HJ");
    try expect(!card1.gt(&card2, trump).?);
    try expect(card2.gt(&card1, trump).?);
    
    card1 = try Card.from_str("CA");
    try expect(!card1.gt(&card2, trump).?);
    try expect(card2.gt(&card1, trump).?);
}