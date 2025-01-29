
const Card = @import("card/card.zig").Card;
const NullSentinelArray = @import("nullarray.zig").NullSentinelArray;

pub const PlayerId: type = u2;

pub const Player = struct {
    pub const Hand = NullSentinelArray(Card, 6);

    id: PlayerId,
    tricks: u3,
    hand: Hand,

    pub const PlayerError = error {
        InitialHandNot5Cards,
        HandFull,
        CardNotPresent,
        AlgorithmError,
        NoTricksToRemove,
    };

    /// Creates a new player object
    /// A player is always initialized with 5 cards
    pub fn new(p_id: PlayerId, hand: []const Card) PlayerError!Player {
        var p_hand: Hand = Hand.new();

        if (hand.len != 5) return PlayerError.InitialHandNot5Cards;

        // we know this will work because of the above check
        for (0..5) | ind| p_hand.push(hand[ind]) catch {};

        return Player {
            .id = p_id,
            .tricks = 0,
            .hand = p_hand,
        };
    }

    /// Returns the number of cards in the players hand.
    pub fn cards_left(self: *const Player) usize {
        return self.hand.num_left();
    }

    pub fn pick_up_6th_card(self: *Player, card: Card) PlayerError!void {
        if (self.hand.num_left() != 5) return PlayerError.InitialHandNot5Cards;
        self.hand.push(card) catch return PlayerError.HandFull;
    }

    /// Designed to be used to undo a previous play action involving `card`
    pub fn put_card_back_in_hand(self: *Player, card: Card) PlayerError!void {
        self.hand.push(card) catch return PlayerError.HandFull;
    }

    /// Removes a card from the players hand.
    /// 
    /// Shifts all cards to the right of that spot over.
    pub fn discard_card(self: *Player, card: Card) PlayerError!void {
        self.hand.remove(card) catch return PlayerError.CardNotPresent;   
    }

    pub fn get_id(self: *const Player) PlayerId {
        return self.id;
    }

    pub fn award_trick(self: *Player) void {
        self.tricks += 1;
    }

    pub fn take_away_trick(self: *Player) PlayerError!void {
        if (self.tricks == 0) return PlayerError.NoTricksToRemove;
        self.tricks -= 1;
    }

    pub fn get_tricks(self: *const Player) u3 {
        return self.tricks;
    }
};


const std = @import("std");
const expect = std.testing.expect;

test "create_player" {
    const Deck = @import("deck.zig").Deck;
    var deck = Deck.new();

    const five_cards = try deck.DealFiveCards();

    const player = try Player.new(0, five_cards);

    try expect(player.id == 0);
    try expect(player.cards_left() == 5);
    try expect(player.hand.get(5) == null);
    try expect(player.hand.get(0).?.eq(try Card.FromStr("S9") ));

    // Testing that the players hand has copy of those in the deck
    const new_card = try Card.FromStr("HT");
    deck.card_buffer[0] = new_card;
    try expect(!player.hand.get(0).?.eq(new_card));
}

test "player_picks_up_and_discards" {
    const Deck = @import("deck.zig").Deck;
    var deck = Deck.new();

    const five_cards = try deck.DealFiveCards();

    var player = try Player.new(0, five_cards);

    const pickup_card = try deck.DealOneCard();
    try player.pick_up_6th_card(pickup_card);

    try expect(player.cards_left() == 6);
    try expect(player.hand.get(5).?.eq(pickup_card));

    // Discard last card
    try player.discard_card(pickup_card);
    try expect(player.cards_left() == 5);
    try expect(player.hand.get(5) == null);

    // Discard first card and make sure that the cards shifted correctly.
    try player.discard_card(player.hand.get(0).?);
    try expect(player.cards_left() == 4);
    try expect(player.hand.get(0).?.eq(deck.card_buffer[1]));

}