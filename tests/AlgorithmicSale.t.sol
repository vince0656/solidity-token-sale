// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {ERC20Token} from "@test/mocks/ERC20Token.sol";

import {AlgorithmicSale} from "@contracts/AlgorithmicSale.sol";
import {AlgorithmicSaleFactory} from "@contracts/AlgorithmicSaleFactory.sol";
import {LinearPriceModel} from "@contracts/models/LinearPriceModel.sol";
import {Errors} from "@contracts/errors/Errors.sol";
import {SaleErrors} from "@contracts/errors/SaleErrors.sol";

/// @author Vincent Almeida @ DEL Blockchain Solutions
contract AlgorithmicSaleContractTests is Test {

    address saleImplementation;
    AlgorithmicSaleFactory saleFactory;
    LinearPriceModel priceModel;
    ERC20Token token;
    ERC20Token currency;
    AlgorithmicSale sale;
    address userOne = vm.addr(1);
    address userTwo = vm.addr(2);
    address userThree = vm.addr(3);
    uint256 maxTokenSaleAmount = 5_000_000 ether;

    function setUp() public {
        // Deploy the token sale factory
        token = new ERC20Token("Test Token", "TEST", 18);
        currency = new ERC20Token("Test Currency", "TCUR", 18);
        saleImplementation = address(new AlgorithmicSale());
        priceModel = new LinearPriceModel(
            1e25, // 1% base increase
            5e26, // 50% price appreciation as a target
            2e27, // 200% max appreciation
            5e26  // 50% sold as the breakpoint for escalating the price increase
        );
        saleFactory = new AlgorithmicSaleFactory(saleImplementation, address(priceModel));

        // Airdrop tokens
        token.mint(userOne, maxTokenSaleAmount);
        token.mint(userTwo, maxTokenSaleAmount);
        token.mint(userThree, maxTokenSaleAmount);

        currency.mint(userOne, maxTokenSaleAmount);
        currency.mint(userTwo, maxTokenSaleAmount);
        currency.mint(userThree, maxTokenSaleAmount);
    }

    function testDeployment() public view {
        assertEq(saleFactory.saleContractImplementation(), saleImplementation);
        assertEq(saleFactory.priceModel(), address(priceModel));
    }

    /// @dev Fuzzed test for creating a sale and checking the revert conditions
    function testCreateSale(uint256 startingPrice, uint128 length, uint256 totalNumOfTokensToSell) public {
        vm.assume(totalNumOfTokensToSell <= maxTokenSaleAmount);

        if (length < 1 hours) {
            deploySaleExpectingRevert(userOne, startingPrice, totalNumOfTokensToSell, length, SaleErrors.SaleTooShort.selector);
            return;
        } 

        if (startingPrice < 1 wei || totalNumOfTokensToSell < 1 wei) {
            deploySaleExpectingRevert(userOne, startingPrice, totalNumOfTokensToSell, length, Errors.InvalidValue.selector);
            return;
        }

        uint256 wholeNumberOfTokensBeingSold = totalNumOfTokensToSell / 1 ether;
        uint256 parsedWholeNumberOfTokensBeingSold = wholeNumberOfTokensBeingSold * 1 ether;
        if (totalNumOfTokensToSell != parsedWholeNumberOfTokensBeingSold) {
            deploySaleExpectingRevert(userOne, startingPrice, totalNumOfTokensToSell, length, SaleErrors.InvalidTotalNumberOfTokensBeingSold.selector);
            return;
        }

        // Deploy a non-reverting sale
        deploySale(userOne, startingPrice, totalNumOfTokensToSell, length);
        assertEq(token.balanceOf(address(sale)), totalNumOfTokensToSell);
        assertEq(sale.getCurrentPrice(), startingPrice);
        assertEq(sale.creator(), userOne);
        assertEq(sale.totalLengthOfSaleInSeconds(), length);
    }

    function testBuyingTokensCausesPriceIncrease(uint128 length) public {
        // Create the sale
        vm.assume(length >= 1 hours);
        uint256 startingPrice = 0.1 ether;
        uint256 totalNumOfTokensToSell = 500_000 ether;
        deploySale(userOne, startingPrice, totalNumOfTokensToSell, length);

        // Buy some tokens, calculating how much to approve ahead of time
        uint256 numberOfWholeTokensToPurchase = 50;
        uint256 numberOfTokensBeingPurchased = sale.parseWholeTokenAmount(numberOfWholeTokensToPurchase);
        uint256 previewPrice = sale.previewAssetPriceForPurchase(numberOfTokensBeingPurchased);
        console.log("Preview price", previewPrice);

        uint256 userTwoTokenBalanceBefore = token.balanceOf(userTwo);
        vm.startPrank(userTwo);
        currency.approve(address(sale), numberOfWholeTokensToPurchase * previewPrice);
        sale.buy(numberOfWholeTokensToPurchase);
        vm.stopPrank();

        assertEq(token.balanceOf(userTwo) - userTwoTokenBalanceBefore, numberOfTokensBeingPurchased);

        // To buy the same number of tokens should now be more expensive
        uint256 previewPriceAfterFirstSale = sale.previewAssetPriceForPurchase(numberOfTokensBeingPurchased);
        console.log("Preview price after sale", previewPriceAfterFirstSale);
        assertGt(previewPriceAfterFirstSale, previewPrice);
    }

    function testUserBuysAllTheTokensAndPaysTrippleBasePrice(uint256 startingPrice, uint128 length) public {
        // Create the sale
        vm.assume(startingPrice > 0 && startingPrice <= 1.5 ether); // Due to allowances we restrict
        vm.assume(length >= 1 hours);
        uint256 totalNumOfTokensToSell = 500_000 ether;
        deploySale(userOne, startingPrice, totalNumOfTokensToSell, length);

        // Buy the full supply as a wave
        uint256 userTwoTokenBalanceBefore = token.balanceOf(userTwo);
        vm.startPrank(userTwo);
        currency.approve(address(sale), startingPrice * 3 * (totalNumOfTokensToSell / 1 ether)); // Based on model params we know there is a 200% markup
        sale.buy(totalNumOfTokensToSell / 1 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(userTwo) - userTwoTokenBalanceBefore, totalNumOfTokensToSell);

        // Cannot sell the tokens back once they are sold out
        vm.expectRevert(SaleErrors.SoldOut.selector);
        sale.sell(totalNumOfTokensToSell / 1 ether);
    }

    function testUserThatBuysCanSellBackToTheContractReducingThePriceAfterwards(uint128 length) public {
        // Deploy the sale
        vm.assume(length >= 1 hours);
        uint256 startingPrice = 1 ether;
        uint256 totalNumOfTokensToSell = 500_000 ether;
        deploySale(userOne, startingPrice, totalNumOfTokensToSell, length);

        // Buy half of the tokens
        uint256 buyAmount = (totalNumOfTokensToSell / 2) / 1 ether;
        uint256 cost = (startingPrice + 0.5 ether) * buyAmount;
        vm.startPrank(userTwo);
        currency.approve(address(sale), cost); // Based on model params we know half sold means 50% increase
        sale.buy(buyAmount);
        vm.stopPrank();

        // Sell back the tokens
        uint256 userTwoCurrencyBalanceBeforeSale = currency.balanceOf(userTwo);
        vm.startPrank(userTwo);
        token.approve(address(sale), buyAmount * 1 ether);
        sale.sell(buyAmount);
        vm.stopPrank();

        assertEq(currency.balanceOf(userTwo) - userTwoCurrencyBalanceBeforeSale, cost);

        // Price should have dropped
        assertEq(sale.getCurrentPrice(), startingPrice);
    }

    function testWithdrawAfterSale(uint128 length) public {
        // Deploy the sale
        vm.assume(length >= 1 hours);
        uint256 startingPrice = 1 ether;
        uint256 totalNumOfTokensToSell = 500_000 ether;
        deploySale(userOne, startingPrice, totalNumOfTokensToSell, length);

        // Buy half of the tokens
        uint256 buyAmount = (totalNumOfTokensToSell / 2) / 1 ether;
        uint256 cost = (startingPrice + 0.5 ether) * buyAmount; // 50% increase in price
        vm.startPrank(userTwo);
        currency.approve(address(sale), cost); // Based on model params we know half sold means 50% increase
        sale.buy(buyAmount);
        vm.stopPrank();

        // Fast forward to the end
        vm.warp(block.timestamp + length + 5 minutes);

        // Withdraw assets from the contract
        uint256 totalNumOfTokensBeforeWithdraw = token.balanceOf(userOne);
        uint256 totalNumOfCurrencyTokensBeforeWithdraw = currency.balanceOf(userOne);
        sale.withdraw(); // Anyone can call but only the creator will get the relevant assets

        // Check balances that the withdraw succeeded
        assertEq(token.balanceOf(userOne) - totalNumOfTokensBeforeWithdraw, totalNumOfTokensToSell / 2);
        assertEq(currency.balanceOf(userOne) - totalNumOfCurrencyTokensBeforeWithdraw, cost);
    }

    function testBuyWhenAlmostSoldOut() public {
        // Use fixed values instead of fuzzing to avoid issues with random inputs
        uint256 length = 1 days;
        uint256 startingPrice = 1 ether;
        uint256 totalNumOfTokensToSell = 10 ether;  // 10 tokens in wei
        
        // Deploy sale with userOne's tokens
        vm.startPrank(userOne);
        address predictedSale = saleFactory.getTokenSaleAddress(address(token));
        token.approve(predictedSale, totalNumOfTokensToSell);
        address saleAddr = saleFactory.createTokenSale(
            address(token),
            address(currency),
            startingPrice,
            totalNumOfTokensToSell,
            length
        );
        sale = AlgorithmicSale(saleAddr);
        vm.stopPrank();

        // Buy almost all tokens except 1
        uint256 almostAll = 9;  // 9 whole tokens
        uint256 numberOfTokensBeingPurchased = sale.parseWholeTokenAmount(almostAll);
        uint256 cost = sale.previewAssetPriceForPurchase(numberOfTokensBeingPurchased);

        vm.startPrank(userTwo);
        currency.mint(userTwo, cost);
        currency.approve(address(sale), cost * almostAll);
        sale.buy(almostAll);
        vm.stopPrank();

        // Try to buy more than remaining
        vm.startPrank(userThree);
        vm.expectRevert(bytes4(keccak256("ExceedsMaxAmount()")));
        sale.previewAssetPriceForPurchase(2 ether);
        currency.mint(userThree, cost);
        currency.approve(address(sale), cost * 2);
        vm.expectRevert(bytes4(keccak256("ExceedsMaxAmount()")));
        sale.buy(2);
        vm.stopPrank();

        // Buy the last remaining token
        vm.startPrank(userThree);
        uint256 finalCost = sale.previewAssetPriceForPurchase(1 ether);
        currency.mint(userThree, finalCost);
        currency.approve(address(sale), finalCost);
        sale.buy(1);
        vm.stopPrank();

        // Verify sale is now sold out
        assertEq(sale.numberOfTokensSold(), totalNumOfTokensToSell);
    }

    function testSaleActiveModifierAtExactEndTime(uint128 length) public {
        vm.assume(length >= 1 hours);
        uint256 startingPrice = 1 ether;
        uint256 totalNumOfTokensToSell = 100 ether;
        deploySale(userOne, startingPrice, totalNumOfTokensToSell, length);

        // Move time to exactly the end of sale
        vm.warp(block.timestamp + length);

        // Try to buy - should revert
        vm.startPrank(userTwo);
        currency.approve(address(sale), startingPrice);
        vm.expectRevert(SaleErrors.SaleFinished.selector);
        sale.buy(1);
        vm.stopPrank();

        // Try to sell - should also revert
        vm.startPrank(userTwo);
        token.approve(address(sale), 1 ether);
        vm.expectRevert(SaleErrors.SaleFinished.selector);
        sale.sell(1);
        vm.stopPrank();
    }

    function testParseWholeTokenAmountWithDifferentDecimals() public {
        // Deploy a token with 6 decimals
        ERC20Token token6Dec = new ERC20Token("Token6Dec", "T6D", 6);
        
        // Deploy sale with 6 decimal token
        uint256 startingPrice = 1 ether;
        uint256 totalNumOfTokensToSell = 5 * 10**6;  // 5 tokens in wei (6 decimals)
        
        // Get predicted address and approve
        address predictedSale = saleFactory.getTokenSaleAddress(address(token6Dec));
        vm.startPrank(userOne);
        token6Dec.mint(userOne, totalNumOfTokensToSell);
        token6Dec.approve(predictedSale, totalNumOfTokensToSell);
        
        // Deploy sale
        address saleAddr = saleFactory.createTokenSale(
            address(token6Dec),
            address(currency),
            startingPrice,
            totalNumOfTokensToSell,
            1 hours
        );
        sale = AlgorithmicSale(saleAddr);
        vm.stopPrank();
        
        // Buy 1 whole token
        vm.startPrank(userTwo);
        uint256 cost = sale.previewAssetPriceForPurchase(1 * 10**6);  // 1 whole token
        currency.mint(userTwo, cost);
        currency.approve(address(sale), cost);
        sale.buy(1);
        vm.stopPrank();
        
        // Check balance is correct
        assertEq(token6Dec.balanceOf(userTwo), 10**6);  // 1 token in 6 decimals
    }

    function deploySale(
        address creator,
        uint256 startingPrice, 
        uint256 totalNumberOfTokensToSell,
        uint256 totalLengthOfSale
    ) internal {
        vm.startPrank(creator);

        // Use CREATE2 to conveniently work out which address to approve ahead of time for the sale
        token.approve(saleFactory.getTokenSaleAddress(address(token)), totalNumberOfTokensToSell);

        sale = AlgorithmicSale(saleFactory.createTokenSale(
            address(token), 
            address(currency), 
            startingPrice, 
            totalNumberOfTokensToSell, 
            totalLengthOfSale
        ));

        vm.stopPrank();
    }

    function deploySaleExpectingRevert(
        address creator,
        uint256 startingPrice, 
        uint256 totalNumberOfTokensToSell,
        uint256 totalLengthOfSale,
        bytes4 errorSelector
    ) internal {
        vm.startPrank(creator);
        vm.expectRevert(errorSelector);
        AlgorithmicSale(saleFactory.createTokenSale(
            address(token), 
            address(currency), 
            startingPrice, 
            totalNumberOfTokensToSell, 
            totalLengthOfSale
        ));
        vm.stopPrank();
    }
}