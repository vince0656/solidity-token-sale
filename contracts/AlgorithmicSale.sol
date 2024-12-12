pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract AlgorithmicSale is Initializable {

    /// @notice Address of the token available for purchase
    address public token;

    /// @notice Address of the token required for payment
    address public currency;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address token_,
        address currency_
    ) external onlyInitializing {
        token = token_;
        currency = currency_;
    }

}