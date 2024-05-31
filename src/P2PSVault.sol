// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract P2PSVault {
    address public owner;
    address public publisher;
    address public pendingOwner;
    address public pendingPublisher;
    address public betInitiator;
    address public pendingBetInitiator;

    // EVENTS
    event ProposedOwner(address);
    event ProposedPublisher(address);
    event NewOwner(address);
    event NewPublisher(address);
    event ProposedBetInitiator(address);
    event NewBetInitiator(address);
    event BetCreated(uint256, address, uint256, uint256);
    event BetPlaced(uint256 betId, address indexed user, uint256 amount, string side);
    event BetResolved(uint256 betId, string outcome);
    event WinningsClaimed(address indexed user, uint256 amount);

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
    }

    Bet[] public bets;

    mapping(address => uint256) betToCreator;
    mapping(address => BetPlacement[]) public userBets;
    mapping(uint256 => mapping(address => uint256)) public betAmounts;
    mapping(uint256 => mapping(string => uint256)) public totalBetAmounts;

    constructor() {
        owner = msg.sender;
    }

    function createBet(string memory _text, uint256 _duration, address[] memory _eligibleAddresses) external onlyBetInitiator returns (uint256 id) {
        uint256 betId = bets.length;
        bets.push(Bet(betId, msg.sender, _text, block.timestamp, "", _duration, 0, false, _eligibleAddresses));
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

        userBets[msg.sender].push(BetPlacement(betId, amount, side, block.timestamp));
        betAmounts[betId][msg.sender] += amount;
        totalBetAmounts[betId][side] += amount;

        emit BetPlaced(betId, msg.sender, amount, side);
    }

    function resolveBet(uint256 betId, string memory outcome) external onlyPublisher {
        require(betId < bets.length, "Bet does not exist");
        Bet storage bet = bets[betId];
        require(block.timestamp >= bet.createdTime + bet.duration, "Bet duration not ended");
        require(bet.expired == false, "Bet already resolved");
        require(keccak256(bytes(outcome)) == keccak256(bytes("YES")) || keccak256(bytes(outcome)) == keccak256(bytes("NO")), "Invalid outcome");

        bet.outcome = outcome;
        bet.publishTime = block.timestamp;
        bet.expired = true;

        emit BetResolved(betId, outcome);
    }

    function claimWinnings() external {
        uint256 totalWinnings = 0;

        for (uint256 i = 0; i < userBets[msg.sender].length; i++) {
            BetPlacement memory betPlacement = userBets[msg.sender][i];
            Bet storage bet = bets[betPlacement.betId];

            if (bet.expired && keccak256(bytes(bet.outcome)) == keccak256(bytes(betPlacement.side))) {
                uint256 userBetAmount = betAmounts[betPlacement.betId][msg.sender];
                uint256 winningAmount = totalBetAmounts[betPlacement.betId]["YES"] + totalBetAmounts[betPlacement.betId]["NO"];
                uint256 userShare = (userBetAmount * 1e18) / totalBetAmounts[betPlacement.betId][bet.outcome];
                totalWinnings += (userShare * winningAmount) / 1e18;

                // prevent double claims
                betAmounts[betPlacement.betId][msg.sender] = 0;
            }
        }

        require(totalWinnings > 0, "No winnings to claim");
        // payable(msg.sender).transfer(totalWinnings);
        emit WinningsClaimed(msg.sender, totalWinnings);
    }

    function isEligible(address[] memory eligibleAddresses, address user) internal pure returns (bool) {
        for (uint256 i = 0; i < eligibleAddresses.length; i++) {
            if (eligibleAddresses[i] == user) {
                return true;
            }
        }
        return false;
    }

    function getAllBetsCreated() external view returns (Bet[] memory pulledBets) {
        Bet[] memory initBets = new Bet[](bets.length);
        uint256 betCounts = 0;
        uint256 betsLength = bets.length;

        for (uint256 i = 0; i < betsLength; i++) {
            if (bets[i].expired == false) {
                initBets[betCounts] = bets[i];
                betCounts++;
            }
        }

        pulledBets = new Bet[](betCounts);
        for (uint256 i = 0; i < betCounts; i++) {
            pulledBets[i] = initBets[i];
        }
        return pulledBets;
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
}
