//auto SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDCs is ERC20 {
  constructor() ERC20("USDCs", "USDCs") {}

  function decimals() public view override returns (uint8) {
    return 6;
  }

  function mint(address _guy, uint256 _amount) external {
    _mint(_guy, _amount);
  }
}