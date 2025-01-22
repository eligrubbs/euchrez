
const Card = @import("card/card.zig").Card;

const Player = struct {
    id: u2,
    tricks: u3,
    hand: [6:null]?*const Card,

    const PlayerError = error {
        InitialHandNot5Cards,
        CardNotPresent,
        AlgorithmError,
    };

    /// Creates an empty player object
    /// A player is always initialized with 5 cards
    pub fn init(p_id: u2, hand: []const Card) PlayerError!Player {
        var p_hand: [6:null]?*const Card = undefined;

        if (hand.len != 5) return PlayerError.InitialHandNot5Cards;

        for (0..5) | ind| p_hand[ind] = &hand[ind];

        p_hand[5] = null;

        return Player {
            .id = p_id,
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
        return 6; // hand is completely full
    }

    pub fn pick_up_6th_card(self: *Player, card: *const Card) void {
        self.hand[5] = card;
    }

    /// Removes a card from the players hand.
    /// 
    /// Shifts all cards to the right of that spot over.
    pub fn discard_card(self: *Player, card: *const Card) PlayerError!void {
        var found: bool = false;
        for (0..6) |ind| {
            if (found) {
                expect(self.hand[ind-1] == null) catch return PlayerError.AlgorithmError;
                self.hand[ind-1] = self.hand[ind];
                self.hand[ind] = null;
            }
            if (self.hand[ind] == card) {
                self.hand[ind] = null;
                found = true;
            }
        }

        if (!found) return PlayerError.CardNotPresent;
    }

    pub fn get_id(self: *const Player) u2 {
        return self.id;
    }

    pub fn award_trick(self: *Player) void {
        self.tricks += 1;
    }

    pub fn get_tricks(self: *const Player) u3 {
        return self.tricks;
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

test "player_picks_up_and_discards" {
    const Deck = @import("deck.zig").Deck;
    const alloc = std.testing.allocator;
    var deck = try Deck.init(alloc);
    defer deck.deinit();

    const five_cards = try deck.deal_five_cards();

    var player = try Player.init(0, five_cards);

    const pickup_card = try deck.deal_one_card();
    player.pick_up_6th_card(pickup_card);

    try expect(player.cards_left() == 6);
    try expect(player.hand[5].?.eq(pickup_card));

    // Discard last card
    try player.discard_card(pickup_card);
    try expect(player.cards_left() == 5);
    try expect(player.hand[5] == null);

    // Discard first card and make sure that the cards shifted correctly.
    try player.discard_card(player.hand[0].?);
    try expect(player.cards_left() == 4);
    try expect(player.hand[0].?.eq(&deck.card_buffer[1]));

}