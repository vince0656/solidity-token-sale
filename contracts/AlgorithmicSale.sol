pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract AlgorithmicSale is Initializable {

    /// @notice Address of the token available for purchase
    address public token;

    /// @notice Address of the token required for payment
    address public currency;

    /// @notice Address of the model that regulates the sale price according to demand
    address public priceModel;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address token_,
        address currency_,
        address priceModel_
    ) external onlyInitializing {
        token = token_;
        currency = currency_;
        priceModel = priceModel_;
    }

}