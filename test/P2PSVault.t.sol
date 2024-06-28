// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {P2PSVault} from "../src/P2PSVault.sol";
import {USDCF} from "../src/mock/MockERC20.sol";

contract P2PSVaultTest is Test {
    P2PSVault public p2pSVault;
    address owner = makeAddr("owner");
    address newOwner = makeAddr("newOwner");
    address publisher = makeAddr("publisher");
    address betInitiator = makeAddr("betInitiator");
    address feeCollector = makeAddr("feeCollector");
    USDCF USDC;

    function setUp() public {
        vm.startPrank(owner);
        USDC = new USDCF();
        uint256 amount = 10000 ether;
        USDC.mint(owner, amount);
        p2pSVault = new P2PSVault();
        p2pSVault.setBetToken(address(USDC));
        p2pSVault.setFee(25);
        vm.stopPrank();
    }

    function test_SetPublisher() public {
        // assertEq(p2pSVault.pendingPublisher(), address(0));
        // assertEq(p2pSVault.publisher(), address(0));

        vm.prank(owner);
        p2pSVault.setPublisher(publisher);
        // assertEq(p2pSVault.pendingPublisher(), publisher);

        vm.prank(publisher);
        p2pSVault.acceptPublishingRole();

        // assertEq(p2pSVault.pendingPublisher(), address(0));
        // assertEq(p2pSVault.publisher(), publisher);
    }

    function test_TransferOwnership() public {
        // assertEq(p2pSVault.pendingPublisher(), address(0));
        // assertEq(p2pSVault.owner(), owner);

        vm.prank(owner);
        p2pSVault.transferOwnership(newOwner);
        // assertEq(p2pSVault.pendingOwner(), newOwner);

        vm.prank(newOwner);
        p2pSVault.acceptOwnership();

        // assertEq(p2pSVault.pendingOwner(), address(0));
        // assertEq(p2pSVault.owner(), newOwner);
    }

    function test_setBetInitiator() public {
        // assertEq(p2pSVault.pendingBetInitiator(), address(0));
        // assertEq(p2pSVault.betInitiator(), address(0));

        vm.prank(owner);
        p2pSVault.setBetInitiator(betInitiator);
        // assertEq(p2pSVault.pendingBetInitiator(), betInitiator);

        vm.prank(betInitiator);
        p2pSVault.acceptBetInitiatorRole();

        // assertEq(p2pSVault.pendingBetInitiator(), address(0));
        // assertEq(p2pSVault.betInitiator(), betInitiator);
    }

    function test_setFeeRecipient() public {
        console.log("Fee collector before set: ", p2pSVault.feeRecipient());

        vm.prank(owner);
        p2pSVault.setFeeRecipient(feeCollector);

        console.log("Fee collector after set: ", p2pSVault.feeRecipient());
    }

    function test_createBuddyBet() public {
        test_setBetInitiator();
        test_SetPublisher();
        test_setFeeRecipient();

        vm.prank(betInitiator);

        string memory text = "Trump will win the 2024 US General Elections?";
        string memory image = "";
        uint256 duration = 259200; // 3 days
        address[] memory eligibleAddr = new address[](5);

        eligibleAddr[0] = address(111111);
        eligibleAddr[1] = address(222222);
        eligibleAddr[2] = address(333333);
        eligibleAddr[3] = address(444444);
        eligibleAddr[4] = address(555555);

        uint256 betId = p2pSVault.createBuddyBet(text, image, duration, eligibleAddr);

        console.log("Created bet with ID: ", betId);
    }

    function test_createPublicBet() public {
        test_setBetInitiator();
        test_SetPublisher();
        test_setFeeRecipient();

        vm.prank(betInitiator);

        string memory text = "Trump will win the 2024 US General Elections?";
        string memory image = "";
        uint256 duration = 259200; // 3 days

        uint256 betId = p2pSVault.createBet(text, image, duration);

        console.log("Created bet with ID: ", betId);
    }

    function test_placeBet() public {
        test_createBuddyBet();

        vm.startPrank(owner);
        USDC.transfer(address(111111), 1e18);
        USDC.transfer(address(222222), 2e18);
        USDC.transfer(address(333333), 3e18);
        USDC.transfer(address(444444), 4e18);
        USDC.transfer(address(555555), 5e18);
        vm.stopPrank();

        vm.startPrank(address(111111));
        USDC.approve(address(p2pSVault), 1e18);
        p2pSVault.placeBet(0, 1e18, "YES");
        vm.stopPrank();

        vm.startPrank(address(222222));
        USDC.approve(address(p2pSVault), 2e18);
        p2pSVault.placeBet(0, 2e18, "NO");
        vm.stopPrank();

        vm.startPrank(address(333333));
        USDC.approve(address(p2pSVault), 3e18);
        p2pSVault.placeBet(0, 3e18, "YES");
        vm.stopPrank();

        vm.startPrank(address(444444));
        USDC.approve(address(p2pSVault), 4e18);
        p2pSVault.placeBet(0, 4e18, "NO");
        vm.stopPrank();

        vm.startPrank(address(555555));
        USDC.approve(address(p2pSVault), 5e18);
        p2pSVault.placeBet(0, 5e18, "YES");
        vm.stopPrank();

        uint256 totalYesBets = p2pSVault.totalBetAmounts(0, "YES");
        uint256 totalNoBets = p2pSVault.totalBetAmounts(0, "NO");

        console.log("TOTAL YES BET: ", totalYesBets);
        console.log("TOTAL NO BET: ", totalNoBets);

        console.log("CONTRACT BAL AFTER BETS: ", USDC.balanceOf(address(p2pSVault)));
    }

    function test_placePublicBet() public {
        test_createPublicBet();

        vm.startPrank(owner);
        USDC.transfer(address(111111), 1e18);
        USDC.transfer(address(222222), 2e18);
        USDC.transfer(address(333333), 3e18);
        USDC.transfer(address(444444), 4e18);
        USDC.transfer(address(555555), 5e18);
        vm.stopPrank();

        vm.startPrank(address(111111));
        USDC.approve(address(p2pSVault), 1e18);
        p2pSVault.placeBet(0, 1e18, "YES");
        vm.stopPrank();

        vm.startPrank(address(222222));
        USDC.approve(address(p2pSVault), 2e18);
        p2pSVault.placeBet(0, 2e18, "NO");
        vm.stopPrank();

        vm.startPrank(address(333333));
        USDC.approve(address(p2pSVault), 3e18);
        p2pSVault.placeBet(0, 3e18, "YES");
        vm.stopPrank();

        vm.startPrank(address(444444));
        USDC.approve(address(p2pSVault), 4e18);
        p2pSVault.placeBet(0, 4e18, "NO");
        vm.stopPrank();

        vm.startPrank(address(555555));
        USDC.approve(address(p2pSVault), 5e18);
        p2pSVault.placeBet(0, 5e18, "YES");
        vm.stopPrank();

        uint256 totalYesBets = p2pSVault.totalBetAmounts(0, "YES");
        uint256 totalNoBets = p2pSVault.totalBetAmounts(0, "NO");

        console.log("TOTAL YES BET: ", totalYesBets);
        console.log("TOTAL NO BET: ", totalNoBets);

        console.log("CONTRACT BAL AFTER BETS: ", USDC.balanceOf(address(p2pSVault)));
    }

    function test_resolveBet() public {
        test_placeBet();

        vm.warp(block.timestamp + 3 days + 1 minutes);

        vm.prank(publisher);
        p2pSVault.resolveBet(0, "YES");
    }

    function test_resolvePublicBet() public {
        test_placePublicBet();

        vm.warp(block.timestamp + 3 days + 1 minutes);

        vm.prank(publisher);
        p2pSVault.resolveBet(0, "YES");
    }

    function test_claimWinning() public {
        test_resolveBet();

        vm.prank(address(111111));
        p2pSVault.claimWinning(0);

        vm.prank(address(333333));
        p2pSVault.claimWinning(0);

        vm.prank(address(555555));
        p2pSVault.claimWinning(0);

        console.log("Pending Fee: ", p2pSVault.pendingFee());
        console.log("Total Fee: ", p2pSVault.totalFeeEarned());

        console.log("CONTRACT BAL AFTER WINNING CLAIMS: ", USDC.balanceOf(address(p2pSVault)));

        console.log("USER 1 BAL: ", USDC.balanceOf(address(111111)));
        console.log("USER 3 BAL: ", USDC.balanceOf(address(333333)));
        console.log("USER 5 BAL: ", USDC.balanceOf(address(555555)));

        vm.prank(owner);
        p2pSVault.claimFee();

        console.log("FEE COLLECTOR BAL AFTER FEE CLAIMS: ", USDC.balanceOf(address(feeCollector)));
        console.log("CONTRACT BAL AFTER FEE CLAIMS: ", USDC.balanceOf(address(p2pSVault)));
    }

    function test_claimWinningPublicBet() public {
        test_resolvePublicBet();

        vm.prank(address(111111));
        p2pSVault.claimWinning(0);

        vm.prank(address(333333));
        p2pSVault.claimWinning(0);

        vm.prank(address(555555));
        p2pSVault.claimWinning(0);

        console.log("Pending Fee: ", p2pSVault.pendingFee());
        console.log("Total Fee: ", p2pSVault.totalFeeEarned());

        console.log("CONTRACT BAL AFTER WINNING CLAIMS: ", USDC.balanceOf(address(p2pSVault)));

        console.log("USER 1 BAL: ", USDC.balanceOf(address(111111)));
        console.log("USER 3 BAL: ", USDC.balanceOf(address(333333)));
        console.log("USER 5 BAL: ", USDC.balanceOf(address(555555)));

        vm.prank(owner);
        p2pSVault.claimFee();

        console.log("FEE COLLECTOR BAL AFTER FEE CLAIMS: ", USDC.balanceOf(address(feeCollector)));
        console.log("CONTRACT BAL AFTER FEE CLAIMS: ", USDC.balanceOf(address(p2pSVault)));
    }
}
