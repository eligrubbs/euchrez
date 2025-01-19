// Create and maintain a euchre deck
const std = @import("std");

const Card = @import("card/card.zig").Card;

const Suit = @import("card/suit.zig").Suit;
const SuitRange = @import("card/suit.zig").SuitRange;
const Rank = @import("card/rank.zig").Rank;
const RankRange = @import("card/rank.zig").RankRange;


pub const Deck = struct {
    const deck_size = 24; // should always be 24. don't change...

    card_buffer: []Card,
    allocator: std.mem.Allocator,

    deal_index: usize,

    const DeckError = error{
        OutOfMemory,
        DeckSizeNot24,
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
        inline for (SuitRange) |suit| {
            inline for (RankRange) |rank| {
                deck_buff.*[card_ind] = Card{.suit = suit, .rank = rank};
                card_ind += 1;
            }
        }
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