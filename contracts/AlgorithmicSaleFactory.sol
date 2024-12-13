// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AlgorithmicSale} from "@contracts/AlgorithmicSale.sol";
import {Errors} from "@contracts/errors/Errors.sol";

/// @notice Smart contract to allow any wallet to deploy a sale for a new token that they create
/// @author Vincent Almeida @ DEL Blockchain Solutions
contract AlgorithmicSaleFactory {
    // Use EIP-1167 for cheap CREATE 2 deployments
    using Clones for address;

    /// @notice Emitted when a user creates a new token sale
    event TokenSaleCreated(address indexed token, address indexed sale);

    /// @notice Address of the sale contract that is cloned for new deployments
    address public saleContractImplementation;

    /// @notice Address of the price model used by the deployed sale contracts
    address public priceModel;

    /// @notice Configuration of the sale and price model for new token sales
    /// @param saleContractImplementation_ Deployed address of the sale logic specific to this factory
    /// @param priceModel_ Address of the pricing model sales contracts will use to calculate sale price
    constructor(
        address saleContractImplementation_,
        address priceModel_
    ) {
        require(saleContractImplementation_ != address(0), Errors.InvalidValue());
        require(priceModel_ != address(0), Errors.InvalidValue());
        saleContractImplementation = saleContractImplementation_;
        priceModel = priceModel_;
    }

    /// @notice Deploy a token sale contract using CREATE2 and configure it as per the user's arguments
    /// @param token The address of the token being sold
    /// @param currency The address of the token accepted as payment for the sale
    /// @param totalLengthOfSale Total duration of the sale
    /// @return sale The address of the deployed sale contract
    function createTokenSale(
        address token,
        address currency,
        uint256 startingPrice,
        uint256 totalNumberOfTokensToSell,
        uint256 totalLengthOfSale
    ) external returns (address sale) {
        sale = saleContractImplementation.cloneDeterministic(getDeploymentSaltFromToken(token));
        AlgorithmicSale(sale).initialize(
            token,
            currency,
            priceModel,
            startingPrice,
            totalNumberOfTokensToSell,
            msg.sender,
            totalLengthOfSale
        );

        emit TokenSaleCreated(token, sale);
    }

    /// @notice Perform a lookup of the address of the token sale contract from the token address using CREATE2
    /// @dev The beauty of this is that no storage mapping is required making deployment cheaper
    /// @param token The address of the token being sold
    function getTokenSaleAddress(address token) external view returns (address) {
        require(token != address(0), Errors.InvalidValue());
        return saleContractImplementation.predictDeterministicAddress(
            getDeploymentSaltFromToken(token),
            address(this)
        );
    }

    /// @notice Generate the CREATE2 deployment salt from the address of the token being sold
    /// @param token The address of the token being sold
    function getDeploymentSaltFromToken(address token) public pure returns (bytes32) {
        require(token != address(0), Errors.InvalidValue());
        return keccak256(abi.encode(token));
    }
}