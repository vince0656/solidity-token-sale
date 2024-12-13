// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @author Vincent Almeida @ DEL Blockchain Solutions
interface IPriceModel {
    /// @notice Calculate the price of an asset based on tokens sold and the params of the models equation
    /// @param totalTokensBeingSold Number of tokens that are being sold
    /// @param remainingTokensAvailableForPurchase Total number of tokens available to buy
    /// @param startingPrice The initial price of the asset
    /// @return currentPrice The calculated price based on the model variables and the inputs
    function getCurrentPrice(
        uint256 totalTokensBeingSold, 
        uint256 remainingTokensAvailableForPurchase, 
        uint256 startingPrice
    ) external view returns (uint256 currentPrice);
}