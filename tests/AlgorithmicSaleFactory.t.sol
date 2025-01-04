// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {ERC20Token} from "@test/mocks/ERC20Token.sol";
import {AlgorithmicSale} from "@contracts/AlgorithmicSale.sol";
import {AlgorithmicSaleFactory} from "@contracts/AlgorithmicSaleFactory.sol";
import {LinearPriceModel} from "@contracts/models/LinearPriceModel.sol";
import {Errors} from "@contracts/errors/Errors.sol";

contract AlgorithmicSaleFactoryTests is Test {
    AlgorithmicSaleFactory factory;
    LinearPriceModel priceModel;
    address saleImplementation;
    ERC20Token token;
    ERC20Token currency;
    address creator = address(1);

    function setUp() public {
        // Deploy the token sale factory
        token = new ERC20Token("Test Token", "TEST", 18);
        currency = new ERC20Token("Test Currency", "TCUR", 18);
        saleImplementation = address(new AlgorithmicSale());
        priceModel = new LinearPriceModel(
            1e25, // 1% base increase
            5e26, // 50% price appreciation as a target
            2e27, // 200% max appreciation
            5e26  // 50% sold as the breakpoint
        );
        factory = new AlgorithmicSaleFactory(saleImplementation, address(priceModel));
    }

    function testPredictDeterministicAddress() public {
        // First get the predicted address
        address predicted = factory.getTokenSaleAddress(address(token));
        
        // Fund and approve tokens
        vm.startPrank(creator);
        token.mint(creator, 1000 ether);
        token.approve(predicted, 1000 ether);
        
        // Now create a sale and verify the address matches
        address actualSale = factory.createTokenSale(
            address(token),
            address(currency),
            1 ether,
            1000 ether,
            1 hours
        );

        vm.stopPrank();
        
        assertEq(predicted, actualSale, "Predicted address should match actual deployed address");
    }

    function testConstructorZeroAddressChecks() public {
        // Test deploying with zero address for sale implementation
        vm.expectRevert(Errors.InvalidValue.selector);
        new AlgorithmicSaleFactory(address(0), address(priceModel));

        // Test deploying with zero address for price model
        vm.expectRevert(Errors.InvalidValue.selector);
        new AlgorithmicSaleFactory(saleImplementation, address(0));
    }

    function testCreateSaleWithInvalidParams() public {
        // Test with zero address for token
        vm.expectRevert(Errors.InvalidValue.selector);
        factory.createTokenSale(
            address(0),
            address(currency),
            1 ether,
            1000 ether,
            1 hours
        );

        // Test with zero address for currency
        vm.expectRevert(Errors.InvalidValue.selector);
        factory.createTokenSale(
            address(token),
            address(0),
            1 ether,
            1000 ether,
            1 hours
        );

        // Test with zero starting price
        vm.expectRevert(Errors.InvalidValue.selector);
        factory.createTokenSale(
            address(token),
            address(currency),
            0,
            1000 ether,
            1 hours
        );

        // Test with zero tokens to sell
        vm.expectRevert(Errors.InvalidValue.selector);
        factory.createTokenSale(
            address(token),
            address(currency),
            1 ether,
            0,
            1 hours
        );
    }
}
