//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.

pub const Game = @import("game.zig").Game;
pub const Card = @import("card/card.zig").Card;
pub const Suit = @import("card/suit.zig").Suit;
pub const Rank = @import("card/rank.zig").Rank;

