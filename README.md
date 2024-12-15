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

# Usage

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
| contracts/AlgorithmicSale.sol         | 100.00% (53/53) | 100.00% (66/66)   | 67.65% (23/34) | 90.91% (10/11) |
| contracts/AlgorithmicSaleFactory.sol  | 100.00% (11/11) | 100.00% (13/13)   | 50.00% (4/8)   | 75.00% (3/4)   |
| contracts/models/LinearPriceModel.sol | 100.00% (18/18) | 100.00% (21/21)   | 84.62% (11/13) | 100.00% (2/2)  |
| tests/mocks/ERC20Token.sol            | 100.00% (1/1)   | 100.00% (1/1)     | 100.00% (0/0)  | 100.00% (1/1)  |
| Total                                 | 100.00% (83/83) | 100.00% (101/101) | 69.09% (38/55) | 88.89% (16/18) |
```