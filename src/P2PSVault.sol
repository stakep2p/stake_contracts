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

    // DATA STRUCTURES

    enum Sides {
        YES,
        NO
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
    }

    Bet[] public bets;

    mapping(address => uint256) betToCreator;

    constructor() {
        owner = msg.sender;
    }

    function createBet(string memory _text, uint256 _duration) external onlyBetInitiator returns (uint256 id) {
        uint256 betId = bets.length;
        bets.push(Bet(betId, msg.sender, _text, block.timestamp, "", _duration, 0, false));
        betToCreator[msg.sender] = betId;
        emit BetCreated(betId, msg.sender, block.timestamp, _duration);
        return id;
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
