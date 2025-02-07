//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.

pub const Card: type = @import("card/card.zig").Card;
pub const Suit: type = @import("card/suit.zig").Suit;
pub const Rank: type = @import("card/rank.zig").Rank;
pub const Action: type = @import("action.zig").Action;
pub const FlippedChoice: type = @import("action.zig").FlippedChoice;

const game: type = @import("game.zig");
pub const Game: type = game.Game;
pub const GameConfig: type = game.GameConfig;
pub const ScopedState: type = game.ScopedState;
pub const PlayerId: type = game.PlayerId;
pub const Turn: type = game.Turn;
pub const TurnsTaken: type = game.TurnsTaken;
pub const LegalActions: type = game.LegalActions;
pub const CenterCards: type = game.CenterCards;
pub const Hand: type = @import("player.zig").Player.Hand;
