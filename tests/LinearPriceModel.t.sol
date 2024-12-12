pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {LinearPriceModel} from "@contracts/models/LinearPriceModel.sol";

contract LinearPriceModelContractTests is Test {
    
    LinearPriceModel model;

    function setUp() public {
        model = new LinearPriceModel(
            1e25, // 1%
            5e26, // 50%
            2e27, // 200%
            5e26  // 50%
        );
    }

    /// @dev Fuzzed test. We know when fully sold out the current price will tripple due to contract params
    function testGetCurrentPriceWhenFullySoldOut(uint64 price) public view {
        vm.assume(price > 0);
        assertEq(model.getCurrentPrice(1_000, 0, uint256(price)), uint256(price) * 3);
    }

    /// @dev Fuzzed test. We know when nothing is sold, the current price will equal starting prive
    function testGetCurrentPriceWhenNothingSold(uint256 price) public view {
        vm.assume(price > 0);
        assertEq(model.getCurrentPrice(1_000, 1_000, price), price);
    }

}