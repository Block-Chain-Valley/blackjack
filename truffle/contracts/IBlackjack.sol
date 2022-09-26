pragma solidity ^0.8.15;

interface IBlackjack {

  enum Stage {
    Bet,
    PlayHand,
    ConcludeHands
  }

  struct Game {
    uint id;
    uint64 startTime;
    uint64 round;
    Stage stage;
    Player dealer;
    Player player;
  }

  struct Player {
    uint bet;
    uint8 score;
    uint[] hand;
  }

  event StageChanged(uint gameId, uint64 round, Stage newStage);
  event NewRound(uint gameId, uint64 round, address player, uint bet);
  event CardDrawn(uint gameId, uint64 round, uint8 cardValue, uint8 score);
  event Result(uint gameId, uint64 round, uint payout, uint8 playerScore, uint8 dealerScore);
  event PlayerHand(uint gameId, uint[] playerHand);
  event Received(address, uint);

  function kill() external;

  /// @dev Start a new round of Blackjack
  function newRound() external payable;

  /// @dev Take one additional card
  function hit() external;

  /// @dev Taking no more cards and ended the game
  function stand() external;

  /// Getters
  /// @dev Get dealer state
  /// @return hand The dealer's hand
  /// @return score The dealer's score
  function getDealerState() external view returns (uint[] memory hand, uint score);

  /// @dev Get player state
  /// @return hand The player's hand
  /// @return score The player's score
  /// @return bet Original bet at start of hand
  function getPlayerState() external view returns (uint[] memory hand, uint score, uint bet);

  /// @dev Get game stage
  /// @return gameId ID for the current Blackjack game
  /// @return startTime Time the current Blackjack game began
  /// @return gameMaxBet Max bet allowed to be placed for new game
  /// @return round Number of round of Blackjack game played
  /// @return stage Stage of the Blackjack game
  function getGameState() external view returns (uint gameId, uint64 startTime, uint gameMaxBet, uint64 round, Stage stage);
  
}