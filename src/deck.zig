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

    pub const DeckError = error{
        NotEnoughCards,
    };

    /// Create an unshuffled deck object.
    pub fn new() Deck {
        var deck = Deck{
            .card_buffer = undefined,
            .deal_index = 0,
        };

        Deck.fillUnshuffled(&deck.card_buffer);

        return deck;
    }

    pub fn fillUnshuffled(deck_buff: *[deck_size]Card) void {
        var card_ind: usize = 0;
        inline for (Suit.range) |suit| {
            inline for (Rank.range) |rank| {
                deck_buff.*[card_ind] = Card{ .suit = suit, .rank = rank };
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
    pub fn DealFiveCards(self: *Deck) DeckError![]const Card {
        if (self.deal_index >= (deck_size - 4)) return DeckError.NotEnoughCards;

        self.deal_index += 5;
        return self.card_buffer[(self.deal_index - 5)..self.deal_index];
    }

    /// Return a copy of the next undealt card.
    /// Does not deal the card.
    pub fn PeekAtTopCard(self: *Deck) DeckError!Card {
        if (self.deal_index >= deck_size) return DeckError.NotEnoughCards;
        return self.card_buffer[self.deal_index];
    }

    /// Return a copy of the next undealt card.
    /// Increments `deal_index` by 1 so this card can't be dealt again.
    ///
    /// The card is NOT removed from the deck's memory buffer.
    ///
    pub fn DealOneCard(self: *Deck) DeckError!Card {
        if (self.deal_index >= deck_size) return DeckError.NotEnoughCards;
        self.deal_index += 1;
        return self.card_buffer[self.deal_index - 1];
    }
};



test "create_unshuffled" {
    const expect = std.testing.expect;

    var deck = Deck.new();

    try expect(deck.card_buffer[0].eq(Card{ .suit = Suit.Spades, .rank = Rank.Nine }));
    try expect(deck.card_buffer[23].eq(Card{ .suit = Suit.Clubs, .rank = Rank.Ace }));
    try expect(deck.card_buffer.len == 24);
}

test "deal euchre deck" {
    const expect = std.testing.expect;
    const expectErr = std.testing.expectError;

    var deck = Deck.new();

    const hand1 = try deck.DealFiveCards();
    const expected_hand1 = [5]Card{ try Card.FromStr("S9"), try Card.FromStr("ST"), try Card.FromStr("SJ"), try Card.FromStr("SQ"), try Card.FromStr("SK") };
    for (expected_hand1, 0..) |card, ind| {
        try expect(card.eq(hand1[ind]));
    }

    const hand2 = try deck.DealFiveCards();
    const expected_hand2 = [5]Card{ try Card.FromStr("SA"), try Card.FromStr("H9"), try Card.FromStr("HT"), try Card.FromStr("HJ"), try Card.FromStr("HQ") };
    for (expected_hand2, 0..) |card, ind| {
        try expect(card.eq(hand2[ind]));
    }

    const hand3 = try deck.DealFiveCards();
    const expected_hand3 = [5]Card{ try Card.FromStr("HK"), try Card.FromStr("HA"), try Card.FromStr("D9"), try Card.FromStr("DT"), try Card.FromStr("DJ") };
    for (expected_hand3, 0..) |card, ind| {
        try expect(card.eq(hand3[ind]));
    }

    const hand4 = try deck.DealFiveCards();
    const expected_hand4 = [5]Card{ try Card.FromStr("DQ"), try Card.FromStr("DK"), try Card.FromStr("DA"), try Card.FromStr("C9"), try Card.FromStr("CT") };
    for (expected_hand4, 0..) |card, ind| {
        try expect(card.eq(hand4[ind]));
    }

    // cant deal any more cards
    try expect(deck.deal_index == 20);
    try expectErr(Deck.DeckError.NotEnoughCards, deck.DealFiveCards());
}
