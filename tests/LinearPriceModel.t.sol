// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {LinearPriceModel} from "@contracts/models/LinearPriceModel.sol";
import {Errors} from "@contracts/errors/Errors.sol";
import {LinearPriceModelErrors} from "@contracts/errors/LinearPriceModelErrors.sol";

/// @dev Testing suite for the linear price model leveraging the fuzzer to get deeper coverage
/// @author Vincent Almeida @ DEL Blockchain Solutions
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

    function testPriceAtExactBreakpoint() public view {
        uint256 totalTokensBeingSold = 1000 ether;
        uint256 startingPrice = 1 ether;
        
        // Calculate tokens remaining at breakpoint (50%)
        uint256 remainingAtBreakpoint = totalTokensBeingSold - (totalTokensBeingSold * model.breakpointInRAY() / 1e27);
        
        // Get price at exactly the breakpoint
        uint256 priceAtBreakpoint = model.getCurrentPrice(
            totalTokensBeingSold,
            remainingAtBreakpoint,
            startingPrice
        );
        
        // At breakpoint (50% sold), the multiplier should be optimalPriceIncreaseInRAY (5e26)
        // So price = startingPrice + (startingPrice * 5e26 / 1e27)
        uint256 expectedPrice = startingPrice + ((startingPrice * model.optimalPriceIncreaseInRAY()) / 1e27);
        assert(priceAtBreakpoint >= expectedPrice);
        
        // Test price just before and after breakpoint
        uint256 priceJustBefore = model.getCurrentPrice(
            totalTokensBeingSold,
            remainingAtBreakpoint + 1,
            startingPrice
        );
        
        uint256 priceJustAfter = model.getCurrentPrice(
            totalTokensBeingSold,
            remainingAtBreakpoint - 1,
            startingPrice
        );
        
        assert(priceJustBefore <= priceAtBreakpoint);
        assert(priceJustAfter >= priceAtBreakpoint);
    }

    function testPriceWithExtremeValues() public view {
        uint256 totalTokensBeingSold = 1000 ether;  // Use a reasonable amount
        uint256 startingPrice = 1 ether;  // Use 1 ether to avoid rounding issues
        
        // Test with very small remaining amount (almost all sold)
        uint256 priceNearEnd = model.getCurrentPrice(
            totalTokensBeingSold,
            1 wei,  // Only 1 wei remaining
            startingPrice
        );
        
        // At max (almost all sold), the multiplier should be close to maxPriceIncreaseInRAY (2e27)
        // So price = startingPrice * (1 + 2) = startingPrice * 3
        uint256 expectedMaxPrice = startingPrice * 3;  // 3 ether
        assert(priceNearEnd >= expectedMaxPrice - 1);  // Allow 1 wei rounding error
        
        // Test with amount just sold (almost none sold)
        uint256 priceAtStart = model.getCurrentPrice(
            totalTokensBeingSold,
            totalTokensBeingSold - 1 wei,  // Only 1 wei sold
            startingPrice
        );
        
        // With just 1 wei sold, the multiplier should be very close to basePriceIncreaseInRay (1e25)
        // So price = startingPrice * (1 + 0.01) = startingPrice * 1.01
        uint256 expectedStartPrice = startingPrice + (startingPrice / 100);  // 1.01 ether
        assert(priceAtStart >= expectedStartPrice - 1);  // Allow 1 wei rounding error
        assert(priceAtStart <= startingPrice + (startingPrice / 50));  // Allow some margin for rounding
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