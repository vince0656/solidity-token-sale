# Algorithmic Token Sale Contract

A [smart contract suite](./contracts/) that allows for the sale of an arbitrary ERC20 token using a nominated pricing model for a defined sale period.

Out of the box an algorithmic linear pricing model is included which will increase the sale price of the token based on buyer demand and suppress the price with selling pressure if buyers decide to change their minds before the sale ends. This algorithmic linear pricing model for token sales is inspired by the Aave Default Interest Rate strategy: https://github.com/aave-dao/aave-v3-origin/blob/main/src/contracts/misc/DefaultReserveInterestRateStrategyV2.sol

Basing the implementation of the linear pricing model on the Aave model has the following advantages:
- Battle tested and optimized for Solidity
- Will increase the price linearly with increasing the buy demand
- Has an interesting step up function which uses a steeper gradient when demand exceeds defined parameters, thus incentivizing earlier sales
- Will decrease the price if buy demand drops i.e. when there are sales due to buyers changing their minds and selling back to the market. 
- By the end of the token sale, a final price is determined through the pricing model thus enabling early price discovery of a token using this mechanism without a DEX which normally requires two-sided liquidity

> note: The linear pricing model is implemented within its own smart contract so as to allow different implementations that match the [`IPriceModel.sol`](./contracts/interfaces/IPriceModel.sol) interface which would be compatible with any algorithmic sale factory. The design space is quite wide open.

# Deployment

The `AlgorithmicSaleFactory` is deployed to the Arbitrum Sepolia test network at:
https://sepolia.arbiscan.io/address/0x8E9fB03b82f79f67ea5cE93e673FBD23d617ab83

# Interacting with the deployed project
## Creating a sale
Creating a sale requires using the `AlgorithmicSaleFactory` at the above address and calling the following function:
```solidity
/// @notice Deploy a token sale contract using CREATE2 and configure it as per the user's arguments
/// @param token The address of the token being sold
/// @param currency The address of the token accepted as payment for the sale
/// @param startingPrice The initial price of 1 token being sold, denominated in the currency specified
/// @param totalNumberOfTokensToSell Maximum number of tokens that will be sold. Any unsold can be claimed back after the sale
/// @param totalLengthOfSale Total duration of the sale
/// @return sale The address of the deployed sale contract
function createTokenSale(
    address token,
    address currency,
    uint256 startingPrice,
    uint256 totalNumberOfTokensToSell,
    uint256 totalLengthOfSale
) external returns (address sale);
```

The function will create a new token sale contract that will escrow the tokens to be sold from the user creating the sale. This means knowing the address of the sale contract ahead of time in order to approve the contract. Because `CREATE2` is used for deployment, the following function can be called on the factory to get the address of the sale contract before deployment:
```solidity
function getTokenSaleAddress(address token) external view returns (address);
```

### Example transaction
https://sepolia.arbiscan.io/tx/0xf02abf3ab8cdf6676d16cc9585401dcf3f5d1e8bc65b6ed0ae674f1ae412be8f

### Example sale contract
https://sepolia.arbiscan.io/address/0x58bfda7ad01bf257cbf4d6ceafe2f6a7410b9912

## Buying tokens
As long as the sale is still active, the user can buy tokens by calling the target function on the sale contract:
```solidity
/// @dev Only permitted when the sale has not ended
/// @param amount of whole tokens being purchased. Specifying whole amounts avoids loss of precision for calculating payment
function buy(uint256 amount) external;
```

As specified in the natspec, whole number of tokens are specified without the decimal places i.e. specifying 50 tokens will be equivalent to buying 50 * 10 ^ DECIMALS number of tokens. 

After buying tokens, the linear price model will adjust the price of the tokens making it more expensive for future participants of the sale.

### Example transaction
https://sepolia.arbiscan.io/tx/0x08c55acfcacd8b6b1e06ebaba7ed9396cfc41c220585b5d101c674fa3608ddae

## Selling tokens
Should a buyer change their mind and want to sell their tokens back to the sale contract (thereby reducing the price), then they can call the target function on the sale contract:
```solidity
/// @dev Only permitted when the sale has not ended
/// @param amount of whole tokens being sold
function sell(uint256 amount) external;
```

## Withdrawing assets after the end
Once the sale concludes, the creator can get any unsold tokens and any money made by calling the following function on the sale contract:
```solidity
/// @notice After the sale is over allow the creator to withdraw assets
/// @dev Can be called by anyone but funds will go to creator
function withdraw() external;
```

# Local Usage

The project is a foundry project. If required, foundry can be installed using the following cli command:
```
curl -L https://foundry.paradigm.xyz | bash
```

## Compiling the smart contracts
```
forge build --sizes
```

## Running the fuzzer and tests
```
forge test
```

## Running coverage
```
forge coverage
```

will output:

```
| File                                  | % Lines         | % Statements      | % Branches     | % Funcs        |
|---------------------------------------|-----------------|-------------------|----------------|----------------|
| contracts/AlgorithmicSale.sol         | 100.00% (53/53) | 100.00% (66/66)   | 79.41% (27/34) | 90.91% (10/11) |
| contracts/AlgorithmicSaleFactory.sol  | 100.00% (11/11) | 100.00% (13/13)   | 87.50% (7/8)   | 75.00% (3/4)   |
| contracts/models/LinearPriceModel.sol | 100.00% (18/18) | 100.00% (21/21)   | 84.62% (11/13) | 100.00% (2/2)  |
| tests/mocks/ERC20Token.sol            | 100.00% (3/3)   | 100.00% (3/3)     | 100.00% (0/0)  | 100.00% (3/3)  |
| Total                                 | 100.00% (85/85) | 100.00% (103/103) | 81.82% (45/55) | 90.00% (18/20) |