// Create and maintain a euchre deck
const std = @import("std");

const Card = @import("card/card.zig").Card;

const Suit = @import("card/suit.zig").Suit;
const Rank = @import("card/rank.zig").Rank;


pub const Deck = struct {
    const deck_size = 24; // should always be 24. don't change...

    card_buffer: []Card,
    allocator: std.mem.Allocator,

    deal_index: usize,

    const DeckError = error{
        OutOfMemory,
        DeckSizeNot24,
        NotEnoughCards,
    };

    /// Create an unshuffled deck object.
    /// Caller is responsible for cleaning up deck's memory with `deinit`
    pub fn init(allocator: std.mem.Allocator) DeckError!Deck {
        var deck = Deck {
            .card_buffer = allocator.alloc(Card, deck_size) catch return DeckError.OutOfMemory,
            .allocator = allocator,
            .deal_index = 0,
        };

        try Deck.fill_unshuffled(&deck.card_buffer);

        return deck;
    }

    pub fn deinit(self: *Deck) void {
        self.allocator.free(self.card_buffer);
    }

    fn fill_unshuffled(deck_buff: *[]Card) !void {
        expect(deck_buff.*.len == deck_size) catch return DeckError.DeckSizeNot24;

        var card_ind: usize = 0;
        inline for (Suit.Range()) |suit| {
            inline for (Rank.Range()) |rank| {
                deck_buff.*[card_ind] = Card{.suit = suit, .rank = rank};
                card_ind += 1;
            }
        }
    }

    /// Return a reference to the next 5 cards in the deck.
    /// Then, increments `deal_index` by 5 so these cards can't be dealt again.
    /// 
    /// The cards are NOT removed from the deck's memory buffer.
    /// 
    /// Will throw an error there are not 5 cards to deal.
    pub fn deal_five_cards(self: *Deck) DeckError.NotEnoughCards![]const Card {
        if(self.deal_index >= (deck_size - 4)) return DeckError.NotEnoughCards;

        self.deal_index += 5;
        return self.card_buffer[(self.deal_index-5)..self.deal_index];
    }

    /// Return a reference to the next undealt card.
    /// Does not deal the card.
    pub fn peek_at_top_card(self: *Deck) DeckError.NotEnoughCards! *const Card {
        if (self.deal_index >= deck_size) return DeckError.NotEnoughCards;
        return &self.card_buffer[self.deal_index];
    }

    /// Return a reference to the next undealt card.
    /// Increments `deal_index` by 1 so this card can't be dealt again.
    /// 
    /// The card is NOT removed from the deck's memory buffer.
    /// 
    pub fn deal_one_card(self: *Deck) DeckError.NotEnoughCards!*const Card {
        if (self.deal_index >= deck_size) return DeckError.NotEnoughCards;
        self.deal_index += 1;
        return &self.card_buffer[self.deal_index-1];
    }
};


const expect = std.testing.expect;

test "create_unshuffled" {
    var deck = try Deck.init(std.testing.allocator);
    defer deck.deinit();
    try expect(deck.card_buffer[0].eq(&Card{.suit=Suit.Spades, .rank=Rank.Nine}));
    try expect(deck.card_buffer[23].eq(&Card{.suit=Suit.Hearts, .rank=Rank.Ace}));
    try expect(deck.card_buffer.len == 24); 
}
