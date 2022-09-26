pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IBlackjack.sol";

contract Blackjack is IBlackjack, Ownable {

  using SafeMath for *;

  uint8[13] cardValues = [11, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10];
  mapping(address => Game) games;
  uint seed;
  uint maxBet;

  constructor() {
    seed = block.timestamp;
  }

  fallback() external {}

  receive() external payable {
    emit Received(msg.sender, msg.value);

    maxBet = SafeMath.div(address(this).balance, 2);
  }

  function kill() public onlyOwner() {
    selfdestruct(payable(owner()));
  }

  modifier atStage(Stage _stage) {
    require(games[msg.sender].stage == _stage, "Function cannot be called at this time.");
    _;
  }

  /// @dev Make random number modular 52
  function randNumber() private returns(uint num) {
    num = uint(keccak256(abi.encodePacked(block.timestamp, seed))) % 52;
    seed++;
  }

  /// @dev Check the card exists in hand already
  /// @param card Card number which is drawn
  /// @param hand Cards in hand
  /// @return If there is card in hand already, return true
  function checkHands(uint card, uint[] storage hand) private view returns(bool) {
    for (uint8 i = 0; i < hand.length; i++) {
      if (card == hand[i])
        return true;
    }
    return false;
  }

  /// @dev Calculate total score in hands
  /// @param player A player from a Blackjack game, holding a hand
  /// @return score The Blackjack score for the player
  function checkScore(Player storage player) private view returns (uint8 score) {
    uint8 numberOfAces = 0;
    for (uint8 i = 0; i < player.hand.length; i++) {
      uint8 card = (uint8) (player.hand[i] % 13);
      score += cardValues[card];
      if (card == 0) numberOfAces++;
    }
    while (numberOfAces > 0 && score > 21) {
      score -= 10;
      numberOfAces--;
    }
  }

  /// @dev Draw one card to player
  /// @param game The current game containing the player drawing a card
  /// @param player A player from a Blackjack game
  function drawCard(Game storage game, Player storage player) private {
    uint card = randNumber();
    while ( checkHands(card, game.dealer.hand) || checkHands(card, game.player.hand) ) {
      card = randNumber();
    }

    player.hand.push(card);
    player.score = checkScore(player);

    emit CardDrawn(game.id, game.round, cardValues[uint8(card % 13)], player.score);
  }

  /// @dev only at start of hand
  /// @param game The current game which is starting
  function dealCards(Game storage game) private atStage(Stage.Bet) {
    drawCard(game, game.player);
    drawCard(game, game.dealer);
    drawCard(game, game.player);
  }

  /// @dev Step to next stage
  /// @param game The current game which requires stage update
  function nextStage(Game storage game) internal {
    game.stage = Stage(uint(game.stage) + 1);

    emit StageChanged(game.id, game.round, game.stage);
  }

  /// @dev Start a new round of Blackjack
  function newRound() public payable {
    require(msg.value <= maxBet, "Bet must be less than the max bet.");

    uint id = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender)));

    Player memory dealer;
    Player memory player;

    games[msg.sender] = Game(id, uint64(block.timestamp), 0, Stage.Bet, dealer, player);
    Game storage game = games[msg.sender];

    game.player.bet = msg.value;
    game.round++;

    emit NewRound(game.id, game.round, msg.sender, msg.value);

    dealCards(game);
    emit PlayerHand(game.id, game.player.hand);

    nextStage(game);
  }

  /// @dev Draw dealer's cards
  /// @dev Dealer take a card until go over the player
  /// @param game The ended Blackjack game
  function drawDealerCards(Game storage game) private {
    if (game.player.score > 21) {
      drawCard(game, game.dealer);
    } else {
      while (game.dealer.score < game.player.score) {
        drawCard(game, game.dealer);
      }
    }
  }

  /// @dev Calculate how much contract will be payout to player
  /// @param game The ended Blackjack Game
  /// @return payout Amount of ether to transfer to player for winnings [wei]
  function calculatePayout(Game storage game) private view returns (uint payout) {
    Player memory dealer = game.dealer;
    Player memory player = game.player;

    if (player.score == dealer.score) {
      payout = player.bet;
    } else if (dealer.score > 21) {
      payout = SafeMath.mul(player.bet, 2);
    } else {
      payout = 0;
    }
  }

  /// @dev Finish game
  /// @param game The game to end, paying out players if necessary
  function endGame(Game storage game) private {
    uint payout = 0;

    drawDealerCards(game);

    if (game.player.score <= 21) {
      payout = SafeMath.add(payout, calculatePayout(game));
    }

    require(payout <= SafeMath.mul(game.player.bet, 2), "Dealer error - payout is to high.");

    if (payout != 0) {
      address payable _player = payable(msg.sender);
      _player.transfer(payout);
    }

    maxBet = SafeMath.div(address(this).balance, 2);

    emit Result(game.id, game.round, payout, game.player.score, game.dealer.score);
  }

  /// @dev Take one additional card
  function hit() public atStage(Stage.PlayHand) {
    Game storage game = games[msg.sender];

    require(game.player.score < 21);

    drawCard(game, game.player);
    game.player.score = checkScore(game.player);

    if (game.player.score >= 21) {
      nextStage(game);
    }
  }

  /// @dev Taking no more cards and ended the game
  function stand() public atStage(Stage.PlayHand) {
    Game storage game = games[msg.sender];

    nextStage(game);
    endGame(game);
  }

  /// Getters
  /// @dev Get dealer state
  /// @return hand The dealer's hand
  /// @return score The dealer's score
  function getDealerState() public view returns (uint[] memory hand, uint score) {
    Game storage game = games[msg.sender];
    hand = game.dealer.hand;
    score = game.dealer.score;
  }

  /// @dev Get player state
  /// @return hand The player's hand
  /// @return score The player's score
  /// @return bet Original bet at start of hand
  function getPlayerState() public view returns (uint[] memory hand, uint score, uint bet) {
    Game storage game = games[msg.sender];
    hand = game.player.hand;
    score = game.player.score;
    bet = game.player.bet;
  }

  /// @dev Get game stage
  /// @return gameId ID for the current Blackjack game
  /// @return startTime Time the current Blackjack game began
  /// @return gameMaxBet Max bet allowed to be placed for new game
  /// @return round Number of round of Blackjack game played
  /// @return stage Stage of the Blackjack game
  function getGameState() public view returns (uint gameId, uint64 startTime, uint gameMaxBet, uint64 round, Stage stage) {
    Game storage game = games[msg.sender];
    gameId = game.id;
    startTime = game.startTime;
    gameMaxBet = maxBet;
    round = game.round;
    stage = game.stage;
  }
}