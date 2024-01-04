// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

interface IVestingEscrowFactory {
    /// @notice Thrown when the vesting duration is zero
    error INVALID_VESTING_DURATION();

    /// @notice Thrown when the vesting cliff is greater than the vesting duration
    error INVALID_VESTING_CLIFF();

    /// @notice Thrown when the recipient is the zero address
    error INVALID_RECIPIENT();

    /// @notice Thrown when the amount is zero
    error INVALID_AMOUNT();

    /// @notice Thrown when the vesting escrow implementation is the zero address
    error INVALID_VESTING_ESCROW_IMPL();

    /// @notice Thrown when the token is the zero address
    error INVALID_TOKEN();

    /// @notice Thrown when the owner is the zero address
    error INVALID_OWNER();

    /// @notice Thrown when a transfer fails.
    error TRANSFER_FAILED();

    /// @notice Emitted when a vesting escrow is created.
    event VestingEscrowCreated(address indexed creator, address indexed recipient, address escrow);

    /// @notice Emitted when an ERC20 token is recovered.
    event ERC20Recovered(address token, uint256 amount);

    /// @notice Emitted when ETH is recovered.
    event ETHRecovered(uint256 amount);

    /// @notice Emitted when the voting adaptor is upgraded.
    event VotingAdaptorUpgraded(address votingAdaptor);

    /// @notice Emitted when the manager is changed.
    event ManagerChanged(address manager);

    function votingAdaptor() external view returns (address);
    function owner() external view returns (address);
    function manager() external view returns (address);
}
