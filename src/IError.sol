// SPDX-License-Identifier: No License
pragma solidity ^0.8.20;

interface IError {
    error InValidQuantity(uint256 quantity);

    error InValidAmount(uint256 amount);

    error AlreadyShipped(uint32 orderNo);

    error WithdrawAmountUnavailable(uint8 amount);

    error InsufficientBuyerPayment(uint256 amount);

    error AlreadyCancelled(uint32 orderNo);

    error InValidCollector(address buyer);

    error OrderNotCancelled(uint32 orderNo);

    error AlreadyRefund(uint32 orderNo);

    error InValidOrderLength(uint256 orderNo);

    error InValidPrice(uint256 price);

    error InValidShippingCost(uint256 price);

    error InValidStatus(uint32 orderNo);

    error ContractNotPaused();

    error ContractPaused();

    error TransferFailed(address buyer, uint256 changeAmount);

    error NotAuthorized(address authorized);
}