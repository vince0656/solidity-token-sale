pragma solidity 0.8.28;

import {Errors} from "@contracts/errors/Errors.sol";
import {LinearPriceModelErrors} from "@contracts/errors/LinearPriceModelErrors.sol";
import {IPriceModel} from "@contracts/interfaces/IPriceModel.sol";

contract LinearPriceModel is IPriceModel { 

    /// @notice Scaling value as used in Aave calculations
    uint256 public constant RAY = 1e27;

    /// @notice Minimum price increase once tokens start selling
    uint256 public basePriceIncreaseInRay;

    /// @notice Price increase at the breakpoint number of sales
    uint256 public optimalPriceIncreaseInRAY;

    /// @notice Price increase for tokens when all of the remaining tokens are being sold
    uint256 public maxPriceIncreaseInRAY;
    
    /// @notice Slope increase at the breakpoint
    uint256 public breakpointInRAY;

    constructor(
        uint256 basePriceIncreaseInRay_,
        uint256 optimalPriceIncreaseInRAY_,
        uint256 maxPriceIncreaseInRAY_,
        uint256 breakpointInRAY_
    ) {
        require(optimalPriceIncreaseInRAY_ >= basePriceIncreaseInRay_, LinearPriceModelErrors.InvalidBaseIncrease());
        require(maxPriceIncreaseInRAY_ >= optimalPriceIncreaseInRAY_, LinearPriceModelErrors.InvalidOptimalIncrease());
        basePriceIncreaseInRay = basePriceIncreaseInRay_;
        optimalPriceIncreaseInRAY = optimalPriceIncreaseInRAY_;
        maxPriceIncreaseInRAY = maxPriceIncreaseInRAY_;
        breakpointInRAY = breakpointInRAY_;
    }

    /// @inheritdoc IPriceModel
    function getCurrentPrice(uint256 totalTokensBeingSold, uint256 remainingTokensAvailableForPurchase, uint256 startingPrice) external override view returns (uint256 currentPrice) {
        // Perform validation
        require(totalTokensBeingSold > 0, Errors.InvalidValue());
        require(totalTokensBeingSold >= remainingTokensAvailableForPurchase, Errors.InvalidValue());
        require(startingPrice > 0, Errors.InvalidValue());

        // When there are no tokens sold, we don't need to perform calculations and can simply return the starting price as the current
        if (totalTokensBeingSold == remainingTokensAvailableForPurchase) {
            return startingPrice;
        }

        // Let's calculate the percentage of tokens sold to work out the appropriate price increase
        uint256 sold = totalTokensBeingSold - remainingTokensAvailableForPurchase;
        uint256 percentageSoldInRay = (RAY * sold) / totalTokensBeingSold;
        
        // The percentage increase will depend on whether we have hit the breakpoint or not
        uint256 multiplier;
        if (percentageSoldInRay < breakpointInRAY) {
            // This will tend towards optimalPriceIncreaseInRAY the closer we get to the breakpoint
            multiplier = basePriceIncreaseInRay + ((optimalPriceIncreaseInRAY - basePriceIncreaseInRay) * percentageSoldInRay) / breakpointInRAY;
        } else {
            // The gradient switches here for something steeper but still linear
            multiplier = optimalPriceIncreaseInRAY + ((maxPriceIncreaseInRAY - optimalPriceIncreaseInRAY) * (percentageSoldInRay - breakpointInRAY)) / (RAY - breakpointInRAY);
        }

        // Finally return the current price based on the computed percentage increase
        return ((startingPrice * multiplier) / RAY) + startingPrice;
    }
}