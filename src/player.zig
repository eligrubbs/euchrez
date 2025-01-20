
const Card = @import("card/card.zig").Card;

const Player = struct {
    id: u2,
    tricks: u3,
    hand: [6:null]?*const Card,

    const PlayerError = error {InitialHandNot5Cards};

    /// Creates an empty player object
    /// A player is always initialized with 5 cards
    pub fn init(id: u2, hand: []const Card) PlayerError!Player {
        var p_hand: [6:null]?*const Card = undefined;

        if (hand.len != 5) return PlayerError.InitialHandNot5Cards;

        for (0..5) | ind| p_hand[ind] = &hand[ind];

        p_hand[5] = null;

        return Player {
            .id = id,
            .tricks = 0,
            .hand = p_hand,
        };
    }

    /// Returns the number of cards in the players hand.
    pub fn cards_left(self: *const Player) usize {
        for (self.hand, 0..) |card, count| {
            if (card == null) {
                return count;
            }
        }
        unreachable;
    }
};


const std = @import("std");
const expect = std.testing.expect;

test "create_player" {
    const Deck = @import("deck.zig").Deck;
    const alloc = std.testing.allocator;
    var deck = try Deck.init(alloc);
    defer deck.deinit();

    const five_cards = try deck.deal_five_cards();

    const player = try Player.init(0, five_cards);

    try expect(player.id == 0);
    try expect(player.cards_left() == 5);
    try expect(player.hand[5] == null);
    try expect(player.hand[0].?.eq(&try Card.from_str("S9") ));

    // Testing that the players hand ptr points to the deck
    const new_card = try Card.from_str("HT");
    deck.card_buffer[0] = new_card;
    try expect(player.hand[0].?.eq(&new_card));
}
