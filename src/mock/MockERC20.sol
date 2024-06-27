// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDCF is ERC20 {
    constructor() ERC20("USDC.f", "USDC.f") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
