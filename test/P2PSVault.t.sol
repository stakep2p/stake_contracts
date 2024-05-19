// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {P2PSVault} from "../src/P2PSVault.sol";

contract P2PSVaultTest is Test {
    P2PSVault public p2pSVault;
    address owner = makeAddr("owner");
    address publisher = makeAddr("publisher");

    function setUp() public {
        vm.prank(owner);
        p2pSVault = new P2PSVault();
    }

    function test_SetPublisher() public {
        assertEq(p2pSVault.pendingPublisher(), address(0));
        assertEq(p2pSVault.publisher(), address(0));

        vm.prank(owner);
        p2pSVault.setPublisher(publisher);
        assertEq(p2pSVault.pendingPublisher(), publisher);

        vm.prank(publisher);
        p2pSVault.acceptPublishingRole();

        assertEq(p2pSVault.pendingPublisher(), address(0));
        assertEq(p2pSVault.publisher(), publisher);
    }

    function test_TransferOwnership() public {
        
    }
}
