pragma solidity 0.8.28;

interface ILinearPriceModel {
    function getCurrentPrice(
        uint256 totalTokensBeingSold, 
        uint256 remainingTokensAvailableForPurchase, 
        uint256 startingPrice
    ) external view returns (uint256 currentPrice);
}