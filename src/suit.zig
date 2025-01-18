// Implementation of Suits of common playing cards



const Suit = enum(u8) {
    Spades,
    Clubs,
    Diamonds,
    Hearts,
};


const expect = @import("std").testing.expect;

test "create_suit" {
    const suit = Suit.Clubs;

    try expect(suit == Suit.Clubs);
}