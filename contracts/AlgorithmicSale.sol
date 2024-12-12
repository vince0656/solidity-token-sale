pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Errors} from "@contracts/errors/Errors.sol";
import {SaleErrors} from "@contracts/errors/SaleErrors.sol";
import {IPriceModel} from "@contracts/interfaces/IPriceModel.sol";

contract AlgorithmicSale is Initializable {
    using SafeERC20 for IERC20;
    
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 price);

    /// @notice Address of the token available for purchase
    IERC20 public token;

    /// @notice Address of the token required for payment
    IERC20 public currency;

    /// @notice Address of the model that regulates the sale price according to demand
    IPriceModel public priceModel;

    /// @notice The initial price of 1 token denominated in the `currency`
    uint256 public startingPrice;

    /// @notice Maximum number of tokens that can be purchased during the sale
    uint256 public totalNumberOfTokensBeingSold;

    /// @notice Total duration of the token sale
    uint256 public totalLengthOfSaleInSeconds;

    /// @notice The start of the sale
    uint256 public startTimestamp;

    /// @notice Number of tokens sold during the sale
    uint256 public numberOfTokensSold;

    constructor() {
        _disableInitializers();
    }

    /// @param token_ Address of the token being sold
    /// @param currency_ Address of the payment currency (native token must be wrapped if required)
    function initialize(
        address token_,
        address currency_,
        address priceModel_,
        uint256 startingPrice_,
        uint256 totalNumberOfTokensBeingSold_,
        address creator_,
        uint256 totalLengthOfSaleInSeconds_
    ) external onlyInitializing {
        // Validation
        require(token_ != address(0), Errors.InvalidValue());
        require(currency_ != address(0), Errors.InvalidValue());
        require(priceModel_ != address(0), Errors.InvalidValue());
        require(startingPrice_ > 0, Errors.InvalidValue());
        require(totalNumberOfTokensBeingSold_ > 0, Errors.InvalidValue());
        require(creator_ != address(0), Errors.InvalidValue());
        require(totalLengthOfSaleInSeconds_ >= 1 hours, SaleErrors.SaleTooShort());

        // Effects
        token = IERC20(token_);
        currency = IERC20(currency_);
        priceModel = IPriceModel(priceModel_);
        startingPrice = startingPrice_;
        totalNumberOfTokensBeingSold = totalNumberOfTokensBeingSold_;
        totalLengthOfSaleInSeconds = totalLengthOfSaleInSeconds_;
        startTimestamp = block.timestamp;

        // Interaction
        token.safeTransferFrom(creator_, address(this), totalNumberOfTokensBeingSold);
    }

    function buy(uint256 amount) external {
        // Ensure the sale hasn't ended
        uint256 end = startTimestamp + totalLengthOfSaleInSeconds;
        require(block.timestamp < end, SaleErrors.SaleFinished());

        // Ensure it has not sold out
        uint256 sold = numberOfTokensSold + amount;
        require(sold <= totalNumberOfTokensBeingSold, SaleErrors.ExceedsMaxAmount());

        // Record the number of tokens being sold
        totalNumberOfTokensBeingSold += amount;

        // Get the price of the asset based on how much has been sold and pull the funds
        uint256 currentPrice = priceModel.getCurrentPrice(
            totalNumberOfTokensBeingSold,
            totalNumberOfTokensBeingSold - sold,
            startingPrice
        );

        currency.safeTransferFrom(msg.sender, address(this), currentPrice * amount);

        // Send the user the tokens
        token.transfer(msg.sender, amount);

        emit TokensPurchased(msg.sender, amount, currentPrice);
    }

    function sell() external {
        
    }

    function withdraw() external {

    }

}