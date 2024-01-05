// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {LibClone} from '@solady/utils/LibClone.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IVestingEscrowFactory} from 'src/interfaces/IVestingEscrowFactory.sol';
import {IVestingEscrow} from 'src/interfaces/IVestingEscrow.sol';

contract VestingEscrowFactory is IVestingEscrowFactory, Ownable2Step {
    using LibClone for address;
    using SafeERC20 for IERC20;
    using Address for address payable;

    /// @notice The vesting escrow implementation contract.
    address public immutable vestingEscrowImpl;

    /// @notice The ERC20 token that will be locked in the vesting contracts.
    address public immutable token;

    /// @notice The adaptor that will be used to delegate and/or vote from the vesting contracts.
    address public votingAdaptor;

    /// @notice The account that will manage the vesting contracts.
    address public manager;

    constructor(address _vestingEscrowImpl, address _token, address _owner, address _manager, address _votingAdaptor) {
        if (_vestingEscrowImpl == address(0)) revert INVALID_VESTING_ESCROW_IMPL();
        if (_token == address(0)) revert INVALID_TOKEN();
        if (_owner == address(0)) revert INVALID_OWNER();

        vestingEscrowImpl = _vestingEscrowImpl;
        token = _token;
        manager = _manager;
        votingAdaptor = _votingAdaptor;

        _transferOwnership(_owner);
    }

    /// @notice Deploy and fund a new vesting contract.
    /// @param amount The amount of tokens to lock in the vesting contract.
    /// @param recipient The recipient of the vesting contract.
    /// @param vestingDuration The duration of the vesting contract.
    /// @param vestingStart The start of the vesting contract.
    /// @param cliffLength The cliff length of the vesting contract.
    /// @param isFullyRevokable Whether the vesting contract is fully revokable.
    /// @param initialDelegateParams The optional initial delegate information (skipped if empty bytes).
    function deployVestingContract(
        uint256 amount,
        address recipient,
        uint40 vestingDuration,
        uint40 vestingStart,
        uint40 cliffLength,
        bool isFullyRevokable,
        bytes calldata initialDelegateParams
    ) external returns (address escrow) {
        if (vestingDuration == 0) revert INVALID_VESTING_DURATION();
        if (cliffLength > vestingDuration) revert INVALID_VESTING_CLIFF();
        if (recipient == address(0)) revert INVALID_RECIPIENT();
        if (amount == 0) revert INVALID_AMOUNT();

        escrow = vestingEscrowImpl.clone(
            abi.encodePacked(
                address(this), token, recipient, vestingStart, vestingStart + vestingDuration, cliffLength, amount
            )
        );

        IERC20(token).safeTransferFrom(msg.sender, escrow, amount);
        IVestingEscrow(escrow).initialize(isFullyRevokable, initialDelegateParams);

        emit VestingEscrowCreated(msg.sender, recipient, escrow);
    }

    /// @notice Recover any ERC20 to the owner.
    /// @param token_ The ERC20 token to recover.
    /// @param amount The amount to recover.
    function recoverERC20(address token_, uint256 amount) external {
        if (amount > 0) {
            IERC20(token_).safeTransfer(owner(), amount);
            emit ERC20Recovered(token_, amount);
        }
    }

    /// @notice Recover any ETH to the owner.
    function recoverEther() external {
        uint256 amount = address(this).balance;
        if (amount > 0) {
            payable(owner()).sendValue(amount);
            emit ETHRecovered(amount);
        }
    }

    /// @notice Change the voting adaptor of the vesting contracts.
    function updateVotingAdaptor(address _votingAdaptor) external onlyOwner {
        votingAdaptor = _votingAdaptor;
        emit VotingAdaptorUpgraded(_votingAdaptor);
    }

    /// @notice Change the manager of the vesting contracts.
    function changeManager(address _manager) external onlyOwner {
        manager = _manager;
        emit ManagerChanged(_manager);
    }

    /// @notice The address of the current owner.
    function owner() public view override(Ownable, IVestingEscrowFactory) returns (address) {
        return super.owner();
    }
}
