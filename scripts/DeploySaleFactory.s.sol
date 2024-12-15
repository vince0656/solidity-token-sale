// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

import {LinearPriceModel} from "@contracts/models/LinearPriceModel.sol";
import {AlgorithmicSale} from "@contracts/AlgorithmicSale.sol";
import {AlgorithmicSaleFactory} from "@contracts/AlgorithmicSaleFactory.sol";

contract DeploySaleFactory is Script {

    function run() external {
        uint256 pk = 1;
        vm.startBroadcast(pk);

        // Deploy the sale contract implementation
        address saleImplementation = address(new AlgorithmicSale());

        // Deploy price model
        address priceModel = address(
            new LinearPriceModel(
                1e25, // 1% base increase
                5e26, // 50% price appreciation as a target
                2e27, // 200% max appreciation
                5e26  // 50% sold as the breakpoint for escalating the price increase
            )
        );

        // Deploy the factory
        AlgorithmicSaleFactory factory = new AlgorithmicSaleFactory(saleImplementation, priceModel);

        console.log("Sale factory", address(factory));

        vm.stopBroadcast();
    }
}