// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {ERC20Token} from "@test/mocks/ERC20Token.sol";

import {AlgorithmicSale} from "@contracts/AlgorithmicSale.sol";
import {AlgorithmicSaleFactory} from "@contracts/AlgorithmicSaleFactory.sol";
import {LinearPriceModel} from "@contracts/models/LinearPriceModel.sol";

contract AlgorithmicSaleContractTests is Test {

    address saleImplementation;
    AlgorithmicSaleFactory saleFactory;
    LinearPriceModel priceModel;
    ERC20Token token;
    ERC20Token currency;
    AlgorithmicSale sale;
    address userOne = vm.addr(1);
    address userTwo = vm.addr(2);
    uint256 maxTokenSaleAmount = 1_000_000 ether;

    function setUp() public {
        // Deploy the token sale factory
        token = new ERC20Token();
        currency = new ERC20Token();
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

        currency.mint(userOne, maxTokenSaleAmount);
        currency.mint(userTwo, maxTokenSaleAmount);
    }

    function testDeployment() public view {
        assertEq(saleFactory.saleContractImplementation(), saleImplementation);
        assertEq(saleFactory.priceModel(), address(priceModel));
    }

    function testCreateSale(uint256 startingPrice, uint256 length) public {
        vm.assume(length >= 1 hours);
        vm.assume(startingPrice >= 1 wei);
        uint256 totalNumOfTokensToSell = 50_000 ether;
        deploySale(userOne, startingPrice, totalNumOfTokensToSell, length);
        
        assertEq(token.balanceOf(address(sale)), totalNumOfTokensToSell);
        assertEq(sale.getCurrentPrice(), startingPrice);
        assertEq(sale.creator(), userOne);
        assertEq(sale.totalLengthOfSaleInSeconds(), length);
    }

    function testBuyTokens() public {
        // Create the sale
        uint256 startingPrice = 0.1 ether;
        uint256 length = 12 hours;
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
}