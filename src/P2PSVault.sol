// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {SafeERC20} from "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract P2PSVault {
    using SafeERC20 for IERC20;
    address betToken;
    
    address public owner;
    address public feeRecipient;
    address public publisher;
    address public pendingOwner;
    address public pendingPublisher;
    address public betInitiator;
    address public pendingBetInitiator;

    uint256 public fee;
    uint256 public pendingFee;
    uint256 public totalFeeEarned;

    // EVENTS
    event ProposedOwner(address guy);
    event ProposedPublisher(address guy);
    event NewOwner(address guy);
    event NewPublisher(address guy);
    event ProposedBetInitiator(address guy);
    event NewBetInitiator(address guy);
    event BetCreated(uint256, address, uint256, uint256);
    event BetPlaced(uint256 betId, address user, uint256 amount, string side);
    event BetResolved(uint256 betId, string outcome);
    event WinningsClaimed(address user, uint256 amount);
    event BetRefunded(address user, uint256 amount);
    event FeeSet(uint256 fee);
    event BetTokenSet(address token);
    event FeeClaimed(address guy);

    // MODIFIERS
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert("p2pStake__OnlyOwner");
        }
        _;
    }

    modifier onlyPublisher() {
        if (msg.sender != publisher) {
            revert("p2pStake__OnlyPublisher");
        }
        _;
    }

    modifier onlyBetInitiator() {
        if (msg.sender != betInitiator) {
            revert("p2pStake__OnlyBetInitiator");
        }
        _;
    }

    struct Bet {
        uint256 id;
        address creator;
        string text;
        uint256 createdTime;
        string outcome;
        uint256 duration;
        uint256 publishTime;
        bool expired;
        address[] eligibleAddresses;
    }

    struct BetPlacement {
        uint256 betId;
        uint256 amount;
        string side;
        uint256 timestamp;
        string text;
        uint256 expiry;
    }

    Bet[] public bets;

    mapping(address => uint256) betToCreator;
    mapping(address => BetPlacement[]) public userBets;
    mapping(uint256 => mapping(address => uint256)) public betAmounts;
    mapping(uint256 => mapping(string => uint256)) public totalBetAmounts;
    // mapping(uint256 => uint256) public betIdToTotal;

    constructor() {
        owner = msg.sender;
    }

    function createBet(string memory _text, uint256 _duration, address[] memory _eligibleAddresses) external onlyBetInitiator returns (uint256 id) {
        uint256 betId = bets.length;
        bets.push(Bet(betId, msg.sender, _text, block.timestamp, "", block.timestamp + _duration, 0, false, _eligibleAddresses));
        betToCreator[msg.sender] = betId;
        emit BetCreated(betId, msg.sender, block.timestamp, _duration);
        return id;
    }

    function placeBet(uint256 betId, uint256 amount, string memory side) external {
        require(betId < bets.length, "Bet does not exist");
        Bet storage bet = bets[betId];
        require(block.timestamp < bet.createdTime + bet.duration, "Bet has expired");

        if (bet.eligibleAddresses.length > 0) {
            require(isEligible(bet.eligibleAddresses, msg.sender), "Not eligible to stake on this bet");
        }
        require(keccak256(bytes(side)) == keccak256(bytes("YES")) || keccak256(bytes(side)) == keccak256(bytes("NO")), "Invalid side");

        IERC20(betToken).safeTransferFrom(msg.sender, address(this), amount);

        // Calculation of fee
        uint256 feePaid = (amount * fee) / 1000;
        uint256 netAmount = amount - feePaid;

        userBets[msg.sender].push(BetPlacement(betId, netAmount, side, block.timestamp, bet.text, bet.duration));
        betAmounts[betId][msg.sender] += netAmount;
        totalBetAmounts[betId][side] += netAmount;
        pendingFee += feePaid;
        totalFeeEarned += feePaid;

        emit BetPlaced(betId, msg.sender, netAmount, side);
    }

    function resolveBet(uint256 betId, string memory outcome) external onlyPublisher {
        require(betId < bets.length, "Bet does not exist");
        Bet storage bet = bets[betId];
        require(block.timestamp >= bet.createdTime + bet.duration, "Bet duration not ended");
        require(bet.expired == false, "Bet already resolved");
        require(keccak256(bytes(outcome)) == keccak256(bytes("YES")) || keccak256(bytes(outcome)) == keccak256(bytes("NO")) || keccak256(bytes(outcome)) == keccak256(bytes("DRAW")), "Invalid outcome");

        bet.outcome = outcome;
        bet.publishTime = block.timestamp;
        bet.expired = true;

        emit BetResolved(betId, outcome);
    }

    function claimWinning(uint256 _betId) external {
    require(userBets[msg.sender].length > 0, "No bets");
    BetPlacement memory betPlacement = userBets[msg.sender][_betId];
    Bet storage bet = bets[betPlacement.betId];

    require(bet.expired, "Bet not yet resolved");

    if (keccak256(bytes(bet.outcome)) == keccak256(bytes(betPlacement.side))) {
        uint256 userBetAmount = betAmounts[betPlacement.betId][msg.sender];

        // Calculate the total amount bet on the winning side
        uint256 winningAmount = totalBetAmounts[betPlacement.betId][bet.outcome];

        // Calculate the total amount bet on the losing side
        string memory losingSide = keccak256(bytes(bet.outcome)) == keccak256(bytes("YES")) ? "NO" : "YES";
        uint256 losingAmount = totalBetAmounts[betPlacement.betId][losingSide];

        // Calculate the user's percentage share of the total amount bet on the winning side
        uint256 userSharePercentage = (userBetAmount * 1e18) / winningAmount;

        // Calculate the user's share of the losing side's total stake
        uint256 userShareOfLosingAmount = (userSharePercentage * losingAmount) / 1e18;

        // Total winnings is the user's initial bet amount plus their share of the losing amount
        uint256 totalWinnings = userBetAmount + userShareOfLosingAmount;

        // Prevent double claims
        betAmounts[betPlacement.betId][msg.sender] = 0;

        require(totalWinnings > 0, "No winnings to claim");

        // Transfer the winnings to the user
        IERC20(betToken).safeTransfer(msg.sender, totalWinnings);

        emit WinningsClaimed(msg.sender, totalWinnings);
    } else if (keccak256(bytes(bet.outcome)) == keccak256(bytes("DRAW"))) {
        uint256 userBetAmount = betAmounts[betPlacement.betId][msg.sender];

        // Prevent double claims
        betAmounts[betPlacement.betId][msg.sender] = 0;

        require(userBetAmount > 0, "No amount to refund");

        // Refund the stake
        IERC20(betToken).safeTransfer(msg.sender, userBetAmount);

        emit BetRefunded(msg.sender, userBetAmount);
    }
}


    // function claimWinnings() external {
    //     uint256 totalWinnings = 0;
        
    //     if (userBets[msg.sender].length == 0) {
    //         revert("No bets");
    //     }

    //     for (uint256 i = 0; i < userBets[msg.sender].length; i++) {
    //         BetPlacement memory betPlacement = userBets[msg.sender][i];
    //         Bet storage bet = bets[betPlacement.betId];

    //         if (bet.expired && keccak256(bytes(bet.outcome)) == keccak256(bytes(betPlacement.side))) {
    //             uint256 userBetAmount = betAmounts[betPlacement.betId][msg.sender];
    //             uint256 winningAmount = totalBetAmounts[betPlacement.betId]["YES"] + totalBetAmounts[betPlacement.betId]["NO"];
    //             uint256 userShare = (userBetAmount * 1e18) / totalBetAmounts[betPlacement.betId][bet.outcome];
    //             totalWinnings += (userShare * winningAmount) / 1e18;

    //             // prevent double claims
    //             betAmounts[betPlacement.betId][msg.sender] = 0;
    //         }
    //     }

    //     require(totalWinnings > 0, "No winnings to claim");
    //     // payable(msg.sender).transfer(totalWinnings);
    //     emit WinningsClaimed(msg.sender, totalWinnings);
    // }

    function isEligible(address[] memory eligibleAddresses, address user) internal pure returns (bool) {
        for (uint256 i = 0; i < eligibleAddresses.length; i++) {
            if (eligibleAddresses[i] == user) {
                return true;
            }
        }
        return false;
    }

    function getBet(uint256 betId) external view returns (Bet memory bet) {
       require(betId < bets.length);
        bet = bets[betId];
    }

    function getAllBetsCreated() external view returns (Bet[] memory pulledBets) {
        pulledBets = bets;
        // Bet[] memory initBets = new Bet[](bets.length);
        // uint256 betCounts = 0;
        // uint256 betsLength = bets.length;

        // for (uint256 i = 0; i < betsLength; i++) {
        //     if (bets[i].expired == false) {
        //         initBets[betCounts] = bets[i];
        //         betCounts++;
        //     }
        // }

        // pulledBets = new Bet[](betCounts);
        // for (uint256 i = 0; i < betCounts; i++) {
        //     pulledBets[i] = initBets[i];
        // }
        // return pulledBets;
    }

    function getSideTotal(uint256 _betId, string memory _side) external view returns (uint256) {
        return totalBetAmounts[_betId][_side];
    }

    function getUserSideBet(uint256 _betId, address _user) external view returns (uint256) {
        return betAmounts[_betId][_user];
    }

    function getUserBets(address _user) external view returns (BetPlacement[] memory) {
        return userBets[_user];
    }

    function setBetToken(address _betToken) public onlyOwner {
        betToken = _betToken;
        emit BetTokenSet(_betToken);
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        pendingOwner = _newOwner;
        emit ProposedOwner(_newOwner);
    }

    function acceptOwnership() public {
        if (msg.sender != pendingOwner) {
            revert("p2pStake__NotPendingOwner");
        }
        owner = pendingOwner;
        pendingOwner = address(0);
        emit NewOwner(msg.sender);
    }

    function setPublisher(address _newPublisher) public onlyOwner {
        pendingPublisher = _newPublisher;
        emit ProposedPublisher(_newPublisher);
    }

    function acceptPublishingRole() public {
        if (msg.sender != pendingPublisher) {
            revert("p2pStake__NotPendingPublisher");
        }
        publisher = pendingPublisher;
        pendingPublisher = address(0);
        emit NewPublisher(msg.sender);
    }

    function setBetInitiator(address _newBetInitiator) public onlyOwner {
        pendingBetInitiator = _newBetInitiator;
        emit ProposedBetInitiator(_newBetInitiator);
    }

    function acceptBetInitiatorRole() public {
        if (msg.sender != pendingBetInitiator) {
            revert("p2pStake__NotPendingBetInitiator");
        }
        betInitiator = pendingBetInitiator;
        pendingBetInitiator = address(0);
        emit NewBetInitiator(msg.sender);
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
        emit FeeSet(_fee);
    }

    function claimFee() public onlyOwner {
        require(feeRecipient != address(0), "Error zero address");
        IERC20(betToken).safeTransfer(feeRecipient, pendingFee);
        pendingFee = 0;
        emit FeeClaimed(feeRecipient);
    }

    function setFeeRecipient(address _guy) public onlyOwner {
        feeRecipient = _guy;
    }
}
