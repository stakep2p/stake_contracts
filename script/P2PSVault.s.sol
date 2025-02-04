// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {P2PSVault} from "../src/P2PSVault.sol";

contract P2PSVaultScript is Script {
    P2PSVault p2pSVault;

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address guy = vm.addr(privateKey);
        console.log("Address: ", guy);

        vm.startBroadcast(privateKey);
        p2pSVault = new P2PSVault();
        vm.stopBroadcast();
    }
}
