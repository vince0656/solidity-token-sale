// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20("ERC20Token", "ERC20") {
    function mint(address wallet, uint256 amount) external {
        _mint(wallet, amount);
    }
}