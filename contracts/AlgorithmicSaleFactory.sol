pragma solidity 0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AlgorithmicSale} from "@contracts/AlgorithmicSale.sol";

contract AlgorithmicSaleFactory {
    // Use EIP-1167 for cheap CREATE 2 deployments
    using Clones for address;

    /// @notice Emitted when a user creates a new token sale
    event TokenSaleCreated(address indexed token, address indexed sale);

    /// @notice Address of the sale contract that is cloned for new deployments
    address public saleContractImplementation;

    constructor(address saleContractImplementation_) {
        saleContractImplementation = saleContractImplementation_;
    }

    /// @notice Deploy a token sale contract and configure it as per the user's arguments
    function createTokenSale(
        address token,
        address currency
    ) external returns (address sale) {
        sale = saleContractImplementation.cloneDeterministic(
            getDeploymentSaltFromToken(token)
        );

        AlgorithmicSale(sale).initialize(token, currency);

        emit TokenSaleCreated(token, sale);
    }

    /// @notice Perform a lookup of the address of the token sale contract from the token address using CREATE2
    /// @dev The beauty of this is that no storage mapping is required making deployment cheaper
    function getTokenSaleAddress(address token) external view returns (address) {
        return saleContractImplementation.predictDeterministicAddress(
            getDeploymentSaltFromToken(token),
            address(this)
        );
    }

    /// @notice Generate the CREATE2 deployment salt from the address of the token being sold
    function getDeploymentSaltFromToken(address token) public pure returns (bytes32) {
        return keccak256(abi.encode(token));
    }
}