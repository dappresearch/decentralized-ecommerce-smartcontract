// SPDX-License-Identifier: No License
pragma solidity ^0.8.7;

import "forge-std/console.sol";

// This is mock contract for testing purpose.
// Only needs to return answer.
// https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol
contract MockAggregratorV3Interface {

    // Chailink oracle returns price with artifically inflated to 10^8 decimal places.
    int256 mockPrice = 3200 * (10**8);

    function latestRoundData()
        external
        view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        return (0, mockPrice, 1736221945, 0, 0);
    }
}
