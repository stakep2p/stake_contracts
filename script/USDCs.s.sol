// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {USDCs} from "../src/USDCs.sol";

contract USDCsScript is Script {
    USDCs usdcs;

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address guy = vm.addr(privateKey);
        console.log("Address: ", guy);

        vm.startBroadcast(privateKey);
        usdcs = new USDCs();
        vm.stopBroadcast();
    }
}
