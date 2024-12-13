// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Errors} from "@contracts/errors/Errors.sol";
import {SaleErrors} from "@contracts/errors/SaleErrors.sol";
import {IPriceModel} from "@contracts/interfaces/IPriceModel.sol";

/// @notice Token sale contract that algorithmicly adjusts the price of the token based on how many tokens are being purchased or sold back to the contract
/// @author Vincent Almeida @ DEL Blockchain Solutions
contract AlgorithmicSale is Initializable {
    using SafeERC20 for IERC20;

    /// @notice Emitted when a user buys tokens on sale
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 price);

    /// @notice Emitted when a user decides to sell back tokens to the sale contract
    event TokensSold(address indexed seller, uint256 amount, uint256 price);

    /// @notice Account that deployed the sale
    address public creator;

    /// @notice Address of the token available for purchase
    IERC20 public token;

    /// @notice Token decimals cached for convenience
    uint256 public tokenDecimals;

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

    /// @notice Ensure functions are accessible when the sale is still active
    modifier whenSaleActive() {
        uint256 end = startTimestamp + totalLengthOfSaleInSeconds;
        require(block.timestamp < end, SaleErrors.SaleFinished());
        _;
    }

    /// @notice Ensure functions are accessible when the sale is ended
    modifier whenSaleNotActive() {
        uint256 end = startTimestamp + totalLengthOfSaleInSeconds;
        require(block.timestamp > end, SaleErrors.SaleNotFinished());
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /// @param token_ Address of the token being sold
    /// @param currency_ Address of the payment currency (native token must be wrapped if required)
    /// @param priceModel_ Address of the model used to calculate the price users must pay
    /// @param startingPrice_ Initial price of 1 token being sold
    /// @param totalNumberOfTokensBeingSold_ Maximum number of tokens being sold
    /// @param creator_ Wallet that created the sale and funds the tokens being sold
    /// @param totalLengthOfSaleInSeconds_ Duration of the sale
    function initialize(
        address token_,
        address currency_,
        address priceModel_,
        uint256 startingPrice_,
        uint256 totalNumberOfTokensBeingSold_,
        address creator_,
        uint256 totalLengthOfSaleInSeconds_
    ) external onlyInitializing {
        // Validation (Checks)
        require(token_ != address(0), Errors.InvalidValue());
        require(currency_ != address(0), Errors.InvalidValue());
        require(priceModel_ != address(0), Errors.InvalidValue());
        require(startingPrice_ >= 1 wei, Errors.InvalidValue());
        require(totalNumberOfTokensBeingSold_ >= 1 wei, Errors.InvalidValue());
        require(creator_ != address(0), Errors.InvalidValue());
        require(totalLengthOfSaleInSeconds_ >= 1 hours, SaleErrors.SaleTooShort());

        // Effects
        creator = creator_;
        token = IERC20(token_);
        tokenDecimals = IERC20Metadata(token_).decimals();
        currency = IERC20(currency_);
        priceModel = IPriceModel(priceModel_);
        startingPrice = startingPrice_;
        totalNumberOfTokensBeingSold = totalNumberOfTokensBeingSold_;
        totalLengthOfSaleInSeconds = totalLengthOfSaleInSeconds_;
        startTimestamp = block.timestamp;   // Start the sale immediately

        // Check that the number of tokens being sold corresponds to a whole number and not a fraction by dividing to check for precision loss
        uint256 wholeNumberOfTokensBeingSold = totalNumberOfTokensBeingSold_ / tokenDecimals;
        require(wholeNumberOfTokensBeingSold * tokenDecimals == totalNumberOfTokensBeingSold_, SaleErrors.InvalidTotalNumberOfTokensBeingSold());

        // Interaction
        token.safeTransferFrom(creator_, address(this), totalNumberOfTokensBeingSold);
    }

    /// @notice Purchase tokens
    /// @dev Only permitted when the sale has not ended
    /// @param amount of whole tokens being purchased
    function buy(uint256 amount) external whenSaleActive {
        // Ensure user is not buying zero tokens and that they are not buying more than permitted
        require(amount > 0, Errors.InvalidValue());

        uint256 amountOfTokensBeingPurchased = amount * tokenDecimals;
        require(numberOfTokensSold + amountOfTokensBeingPurchased <= totalNumberOfTokensBeingSold, SaleErrors.ExceedsMaxAmount());

        // Record the number of tokens being sold
        numberOfTokensSold += amountOfTokensBeingPurchased;

        // Get the price of the asset based on the updated amount of tokens that will have been sold
        uint256 currentPrice = getCurrentPrice();

        // Request payment from the sender
        currency.safeTransferFrom(msg.sender, address(this), currentPrice * amount);

        // Send the user the tokens
        token.transfer(msg.sender, amountOfTokensBeingPurchased);

        // Log the purchase
        emit TokensPurchased(msg.sender, amountOfTokensBeingPurchased, currentPrice);
    }

    /// @notice Sell tokens back to the contract
    /// @dev Only permitted when the sale has not ended
    /// @param amount of whole tokens being sold
    function sell(uint256 amount) external whenSaleActive {
        // Ensure user is not selling more than the sale offered
        require(amount > 0, Errors.InvalidValue());
        uint256 amountOfTokensBeingSold = amount * tokenDecimals;
        require(amountOfTokensBeingSold <= numberOfTokensSold, SaleErrors.InvalidSellAmount());

        // Record the number of tokens being sold
        numberOfTokensSold -= amountOfTokensBeingSold;

        // Get the new price of the asset based on the new sold number of tokens which may yield a profit or loss depending on purchase price
        uint256 currentPrice = getCurrentPrice();

        // Request the tokens from the user and refund the payment based on the new asset price
        token.safeTransferFrom(msg.sender, address(this), amountOfTokensBeingSold);
        currency.transfer(msg.sender, amount * currentPrice);

        // Log the sale amount
        emit TokensSold(msg.sender, amountOfTokensBeingSold, currentPrice);
    }

    /// @notice After the sale is over allow the creator to withdraw assets
    /// @dev Can be called by anyone but funds will go to creator
    function withdraw() external whenSaleNotActive {
        // Return any unsold tokens
        uint256 unsold = totalNumberOfTokensBeingSold - numberOfTokensSold;
        if (unsold > 0) {
            token.transfer(creator, unsold);
        }

        // Transfer any money made from sold tokens
        uint256 totalPayments = currency.balanceOf(address(this));
        if (totalPayments > 0) {
            currency.transfer(creator, totalPayments);
        }
    }

    /// @notice Observe the current asset price based on how many tokens have been sold (useful for a user interface)
    function getCurrentPrice() public view returns (uint256) {
        uint256 totalTokensBeingSold = totalNumberOfTokensBeingSold;
        return priceModel.getCurrentPrice(
            totalTokensBeingSold,
            totalTokensBeingSold - numberOfTokensSold,  // Total number of tokens available for purchase
            startingPrice
        );
    }

    /// @notice Calculate the price of the asset based on the number of tokens that a user wishes to purchase (useful for a user interface)
    function previewAssetPriceForPurchase(uint256 amountToPurchase) external view returns (uint256) {
        require(numberOfTokensSold + amountToPurchase <= totalNumberOfTokensBeingSold, SaleErrors.ExceedsMaxAmount());
        return priceModel.getCurrentPrice(
            totalNumberOfTokensBeingSold,
            totalNumberOfTokensBeingSold - (numberOfTokensSold + amountToPurchase), // Total number of tokens available for purchase after accounting for the additional purchase
            startingPrice
        );
    }

}