// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

interface IVotingAdaptor {
    /// @notice Thrown when the owner is the zero address.
    error INVALID_OWNER();

    /// @notice Thrown when the governor is the zero address.
    error INVALID_GOVERNOR();

    /// @notice Thrown when the voting token is the zero address.
    error INVALID_VOTING_TOKEN();

    /// @notice Emitted when ERC20 tokens are recovered.
    event ERC20Recovered(address token, uint256 amount);

    /// @notice Emitted when ETH is recovered.
    event ETHRecovered(uint256 amount);
}
