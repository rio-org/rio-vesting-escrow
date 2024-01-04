// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

interface IVestingEscrow {
    /// @notice Thrown when the caller is not the owner.
    error NOT_OWNER(address account);

    /// @notice Thrown when the caller is not the owner or manager.
    error NOT_OWNER_OR_MANAGER(address account);

    /// @notice Thrown when the caller is not the recipient.
    error NOT_RECIPIENT(address account);

    /// @notice Throws if called by any account other than the factory.
    error NOT_FACTORY(address account);

    /// @notice Throws if the contract token balance is insufficient.
    error INSUFFICIENT_BALANCE();

    /// @notice Thrown when tokens are not fully revokable.
    error NOT_FULLY_REVOKABLE();

    /// @notice Thrown when tokens are already fully revoked.
    error ALREADY_FULLY_REVOKED();

    /// @notice Thrown when there are no tokens to revoke.
    error NOTHING_TO_REVOKE();

    /// @notice Thrown when the voting adaptor is not set.
    error VOTING_ADAPTOR_NOT_SET();

    /// @notice Emitted when the vesting escrow is initialized.
    event VestingEscrowInitialized(
        address indexed factory,
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint40 startTime,
        uint40 endTime,
        uint40 cliffLength,
        bool isFullyRevokable
    );

    /// @notice Emitted when vested tokens are claimed.
    event Claim(address indexed beneficiary, uint256 claimed);

    /// @notice Emitted when unvested tokens are revoked.
    event UnvestedTokensRevoked(address indexed recoverer, uint256 revoked);

    /// @notice Emitted when all tokens are revoked.
    event VestingFullyRevoked(address indexed recoverer, uint256 revoked);

    /// @notice Emitted when full revocation power is permanently disabled.
    event FullRevocationPermanentlyDisabled(address indexed owner);

    /// @notice Emitted when ERC20 tokens are recovered.
    event ERC20Recovered(address token, uint256 amount);

    /// @notice Emitted when ETH is recovered.
    event ETHRecovered(uint256 amount);

    /// @notice Initializes the contract.
    /// @param isFullyRevokable Whether the tokens are fully revokable.
    /// @param initialDelegateParams The optional initial delegate information (skipped if empty bytes).
    function initialize(bool isFullyRevokable, bytes calldata initialDelegateParams) external;
}
