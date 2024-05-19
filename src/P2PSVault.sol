// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract P2PSVault {
    address public owner;
    address public publisher;
    address public pendingOwner;
    address public pendingPublisher;

    // EVENTS
    event ProposedOwner(address indexed);
    event ProposedPublisher(address indexed);
    event NewOwner(address indexed);
    event NewPublisher(address indexed);

    // MODIFIERS
    modifier onlyOwner {
        if (msg.sender != owner)  {
            revert("p2pStake__OnlyOwner");
        }
        _;
    }

    modifier onlyPublisher {
        if (msg.sender != publisher) {
            revert("p2pStake__OnlyPublisher");
        }
        _;
    }

    constructor() {
        owner = msg.sender;
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
        emit NewOwner(pendingOwner);
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
        emit NewPublisher(pendingPublisher);
    }
}
