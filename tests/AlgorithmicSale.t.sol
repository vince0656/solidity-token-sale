// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {AlgorithmicSale} from "@contracts/AlgorithmicSale.sol";
import {AlgorithmicSaleFactory} from "@contracts/AlgorithmicSaleFactory.sol";
import {LinearPriceModel} from "@contracts/models/LinearPriceModel.sol";

contract AlgorithmicSaleContractTests is Test {
    
    address saleImplementation;
    AlgorithmicSaleFactory saleFactory;
    LinearPriceModel priceModel;
    
    function setUp() public {
        saleImplementation = address(new AlgorithmicSale());
        priceModel = new LinearPriceModel(
            1e25, // 1%
            5e26, // 50%
            2e27, // 200%
            5e26  // 50%
        );
        saleFactory = new AlgorithmicSaleFactory(saleImplementation, address(priceModel));
    }

    function testDeployment() public view {
        assertEq(saleFactory.saleContractImplementation(), saleImplementation);
    }
}