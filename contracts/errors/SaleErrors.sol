// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @author Vincent Almeida @ DEL Blockchain Solutions
library SaleErrors {
    error SaleTooShort();
    error ExceedsMaxAmount();
    error SaleFinished();
    error SaleNotFinished();
    error InvalidSellAmount();
    error InvalidTotalNumberOfTokensBeingSold();
}