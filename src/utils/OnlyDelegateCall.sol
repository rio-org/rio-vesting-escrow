// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

/// @notice This contract implements logic to allow only delegate calls.
abstract contract OnlyDelegateCall {
    /// @notice Throws when called directly.
    error CALL_NOT_DELEGATE_CALL();

    /// @dev The address of the original contract that was deployed.
    address private immutable _ORIGINAL;

    /// @dev Sets the original contract address.
    constructor() {
        _ORIGINAL = address(this);
    }

    /// @notice Only allows delegate calls.
    modifier onlyDelegateCall() {
        if (address(this) == _ORIGINAL) revert CALL_NOT_DELEGATE_CALL();
        _;
    }
}
