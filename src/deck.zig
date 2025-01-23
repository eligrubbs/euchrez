// Create and maintain a euchre deck
const std = @import("std");

const Card = @import("card/card.zig").Card;

const Suit = @import("card/suit.zig").Suit;
const Rank = @import("card/rank.zig").Rank;


pub const Deck = struct {
    const deck_size = 24; // should always be 24. don't change...

    // Deck has known size, no need to allocate anything
    card_buffer: [deck_size]Card,

    deal_index: usize,

    const DeckError = error{
        NotEnoughCards,
    };

    /// Create an unshuffled deck object.
    pub fn new() DeckError!Deck {
        var deck = Deck {
            .card_buffer = undefined,
            .deal_index = 0,
        };

        try Deck.fill_unshuffled(&deck.card_buffer);

        return deck;
    }


    pub fn fill_unshuffled(deck_buff: *[deck_size]Card) DeckError!void {

        var card_ind: usize = 0;
        inline for (Suit.Range()) |suit| {
            inline for (Rank.Range()) |rank| {
                deck_buff.*[card_ind] = Card{.suit = suit, .rank = rank};
                card_ind += 1;
            }
        }
    }

    /// Return a const slice to the next 5 cards in the deck.
    /// Then, increments `deal_index` by 5 so these cards can't be dealt again.
    /// 
    /// The cards are NOT removed from the deck's memory buffer.
    /// 
    /// Will throw an error there are not 5 cards to deal.
    pub fn deal_five_cards(self: *Deck) DeckError![]const Card {
        if(self.deal_index >= (deck_size - 4)) return DeckError.NotEnoughCards;

        self.deal_index += 5;
        return self.card_buffer[(self.deal_index-5)..self.deal_index];
    }

    /// Return a reference to the next undealt card.
    /// Does not deal the card.
    pub fn peek_at_top_card(self: *Deck) DeckError! *const Card {
        if (self.deal_index >= deck_size) return DeckError.NotEnoughCards;
        return &self.card_buffer[self.deal_index];
    }

    /// Return a reference to the next undealt card.
    /// Increments `deal_index` by 1 so this card can't be dealt again.
    /// 
    /// The card is NOT removed from the deck's memory buffer.
    /// 
    pub fn deal_one_card(self: *Deck) DeckError!*const Card {
        if (self.deal_index >= deck_size) return DeckError.NotEnoughCards;
        self.deal_index += 1;
        return &self.card_buffer[self.deal_index-1];
    }
};


const expect = std.testing.expect;
const expectErr = std.testing.expectError;

test "create_unshuffled" {
    var deck = try Deck.new();

    try expect(deck.card_buffer[0].eq(&Card{.suit=Suit.Spades, .rank=Rank.Nine}));
    try expect(deck.card_buffer[23].eq(&Card{.suit=Suit.Clubs, .rank=Rank.Ace}));
    try expect(deck.card_buffer.len == 24); 
}


test "deal euchre deck" {
    var deck = try Deck.new();

    const hand1 = try deck.deal_five_cards();
    const expected_hand1 = [5]Card {try Card.from_str("S9"),
                                             try Card.from_str("ST"),
                                             try Card.from_str("SJ"),
                                             try Card.from_str("SQ"),
                                             try Card.from_str("SK")};
    for (expected_hand1, 0..) |card, ind| {
        try expect(card.eq(&hand1[ind]));
    }

    const hand2 = try deck.deal_five_cards();
    const expected_hand2 = [5]Card {try Card.from_str("SA"),
                                             try Card.from_str("H9"),
                                             try Card.from_str("HT"),
                                             try Card.from_str("HJ"),
                                             try Card.from_str("HQ")};
    for (expected_hand2, 0..) |card, ind| {
        try expect(card.eq(&hand2[ind]));
    }

    const hand3 = try deck.deal_five_cards();
    const expected_hand3 = [5]Card {try Card.from_str("HK"),
                                             try Card.from_str("HA"),
                                             try Card.from_str("D9"),
                                             try Card.from_str("DT"),
                                             try Card.from_str("DJ")};
    for (expected_hand3, 0..) |card, ind| {
        try expect(card.eq(&hand3[ind]));
    }

    const hand4 = try deck.deal_five_cards();
    const expected_hand4 = [5]Card {try Card.from_str("DQ"),
                                             try Card.from_str("DK"),
                                             try Card.from_str("DA"),
                                             try Card.from_str("C9"),
                                             try Card.from_str("CT")};
    for (expected_hand4, 0..) |card, ind| {
        try expect(card.eq(&hand4[ind]));
    }

    // cant deal any more cards
    try expect(deck.deal_index == 20);
    try expectErr(Deck.DeckError.NotEnoughCards, deck.deal_five_cards());

}
