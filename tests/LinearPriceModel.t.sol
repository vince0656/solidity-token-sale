// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {LinearPriceModel} from "@contracts/models/LinearPriceModel.sol";
import {Errors} from "@contracts/errors/Errors.sol";
import {LinearPriceModelErrors} from "@contracts/errors/LinearPriceModelErrors.sol";

/// @dev Testing suite for the linear price model leveraging the fuzzer to get deeper coverage
contract LinearPriceModelContractTests is Test {
    
    LinearPriceModel model;

    function setUp() public {
        // Deploy the model as a standalone contract
        model = new LinearPriceModel(
            1e25, // 1% base increase
            5e26, // 50% price appreciation as a target
            2e27, // 200% max appreciation
            5e26  // 50% sold as the breakpoint for escalating the price increase
        );
    }

    function testGetCurrentPriceRevertsWhenTotalTokensBeingSoldIsZero() public {
        uint256 numOfTokensForSale = 0;
        uint256 numOfTokensAvailableForPurchase = 0;
        uint256 startingPrice = 1 ether;
        vm.expectRevert(LinearPriceModelErrors.InvalidNumOfTokensBeingSold.selector);
        model.getCurrentPrice(numOfTokensForSale, numOfTokensAvailableForPurchase, startingPrice);
    }

    /// @dev Fuzzed test. We know when fully sold out the current price will tripple from the starting price due to contract params in the setup
    function testGetCurrentPriceWhenFullySoldOut(uint64 startingPrice) public {
        uint256 numOfTokensForSale = 1_000 ether;
        uint256 numOfTokensAvailableForPurchase = 0;
        if (startingPrice == 0) {
            // a starting price of zero would not be acceptable to the model
            vm.expectRevert(LinearPriceModelErrors.InvalidStartingPrice.selector);
            model.getCurrentPrice(numOfTokensForSale, numOfTokensAvailableForPurchase, uint256(startingPrice));
        } else {
            assertCurrentPriceReflectsAllTokensAreSoldOut(numOfTokensForSale, numOfTokensAvailableForPurchase, uint256(startingPrice));
        }
    }

    /// @dev Fuzzed test. We know when nothing is sold, the current price will equal starting price
    function testGetCurrentPriceWhenNothingSold(uint256 startingPrice) public {
        uint256 numOfTokensForSale = 1_000 ether;
        uint256 numOfTokensAvailableForPurchase = numOfTokensForSale;
        if (startingPrice == 0) {
            // a starting price of zero would not be acceptable to the model
            vm.expectRevert(LinearPriceModelErrors.InvalidStartingPrice.selector);
            model.getCurrentPrice(numOfTokensForSale, numOfTokensAvailableForPurchase, startingPrice);
        } else {
            assertCurrentPriceReflectsAllTokensAreAvailable(numOfTokensForSale, numOfTokensAvailableForPurchase, startingPrice);
        }
    }

    /// @dev Fuzzed test. The number of tokens available to purchase will affect the current price unless it equals the total being sold
    function testGetCurrentPriceWithVaryingAmountsOfSoldTokens(uint256 numOfTokensAvailableForPurchase) public {
        uint256 numOfTokensForSale = 50_000 ether;
        uint256 startingPrice = 0.05 ether;
        
        if (numOfTokensAvailableForPurchase > numOfTokensForSale) {
            // getCurrentPrice should complain about tokens sold exceeding the number for sale
            vm.expectRevert(LinearPriceModelErrors.InvalidRemainingNumOfTokens.selector);
            model.getCurrentPrice(numOfTokensForSale, numOfTokensAvailableForPurchase, startingPrice);
        } else {
            if (numOfTokensAvailableForPurchase == 0) {
                assertCurrentPriceReflectsAllTokensAreSoldOut(numOfTokensForSale, numOfTokensAvailableForPurchase, startingPrice);
            } else if (numOfTokensAvailableForPurchase == numOfTokensForSale) {
                assertCurrentPriceReflectsAllTokensAreAvailable(numOfTokensForSale, numOfTokensAvailableForPurchase, startingPrice);
            } else {
                // The current price has to be greater than the starting irrespective of the specific number avail to purchase - the beauty of fuzzing!
                assertGt(
                    model.getCurrentPrice(numOfTokensForSale, numOfTokensAvailableForPurchase, startingPrice),
                    startingPrice
                );
            }
        }
    }

    function assertCurrentPriceReflectsAllTokensAreSoldOut(
        uint256 numOfTokensForSale,
        uint256 numOfTokensAvailableForPurchase,
        uint256 startingPrice
    ) internal view {
        // We know when fully sold out the current price will tripple from the starting price due to contract params in the setup
        assertEq(
            model.getCurrentPrice(numOfTokensForSale, numOfTokensAvailableForPurchase, startingPrice),
            startingPrice * 3
        );
    }

    function assertCurrentPriceReflectsAllTokensAreAvailable(
        uint256 numOfTokensForSale,
        uint256 numOfTokensAvailableForPurchase,
        uint256 startingPrice
    ) internal view {
        // We know when nothing is sold, the current price will equal starting price
        assertEq(
            model.getCurrentPrice(numOfTokensForSale, numOfTokensAvailableForPurchase, startingPrice),
            startingPrice
        );
    }
}