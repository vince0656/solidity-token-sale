# Algorithmic Token Sale Contract

A smart contract suite that allows for the sale of an arbitrary token using a nominated pricing model within a defined sale period. 

Out of the box an algorithmic linear pricing model is included which will increase the sale price of the token based on buyer demand and suppress the price with selling pressure if buyers decide to change their minds. This algorithmic linear pricing model for token sales is inspired by the Aave Default Interest Rate strategy: https://github.com/aave-dao/aave-v3-origin/blob/main/src/contracts/misc/DefaultReserveInterestRateStrategyV2.sol

Basing the implementation of the linear pricing model on the Aave model has the following advantages:
- Battle tested and optimized for Solidity
- Will increase the price linearly with increasing the buy demand
- Has an interesting step up function which uses a steeper gradient when demand exceeds defined parameters, thus incentivizing earlier sales
- Will decrease the price if buy demand drops i.e. when there are sales due to buyers changing their minds and selling back to the market. 
- By the end of the token sale, a final price is determined through the pricing model thus enabling early price discovery of a token using this mechanism without a DEX which normally requires two-sided liquidity

# Usage
## Build
```
forge build --sizes
```

## Test
```
forge test
```