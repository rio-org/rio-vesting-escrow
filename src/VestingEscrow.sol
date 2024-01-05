// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {Clone} from '@solady/utils/Clone.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IVestingEscrowFactory} from 'src/interfaces/IVestingEscrowFactory.sol';
import {IVestingEscrow} from 'src/interfaces/IVestingEscrow.sol';
import {IVotingAdaptor} from 'src/interfaces/IVotingAdaptor.sol';

contract VestingEscrow is IVestingEscrow, Clone {
    using SafeERC20 for IERC20;
    using Address for address;
    using Address for address payable;

    /// @notice The factory that created this VestingEscrow instance.
    function factory() public pure returns (IVestingEscrowFactory) {
        return IVestingEscrowFactory(_getArgAddress(0));
    }

    /// @notice The token.
    function token() public pure returns (IERC20) {
        return IERC20(_getArgAddress(20));
    }

    /// @notice The token recipient.
    function recipient() public pure returns (address) {
        return _getArgAddress(40);
    }

    /// @notice The vesting start timestamp.
    function startTime() public pure returns (uint40) {
        return _getArgUint40(60);
    }

    /// @notice The vesting end timestamp.
    function endTime() public pure returns (uint40) {
        return _getArgUint40(65);
    }

    /// @notice The vesting cliff length.
    function cliffLength() public pure returns (uint40) {
        return _getArgUint40(70);
    }

    /// @notice The total amount of tokens locked.
    function totalLocked() public pure returns (uint256) {
        return _getArgUint256(75);
    }

    /// @notice The total amount of tokens that have been claimed.
    uint256 public totalClaimed;

    /// @notice The vesting end time or the time at which vesting was revoked.
    uint40 public disabledAt;

    /// @notice Whether vesting is fully revokable.
    bool public isFullyRevokable;

    /// @notice Whether vesting has been fully revoked.
    bool public isFullyRevoked;

    /// @notice Throws if called by any account other than the owner.
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /// @notice Throws if called by any account other than the owner or manager.
    modifier onlyOwnerOrManager() {
        _checkOwnerOrManager();
        _;
    }

    /// @notice Throws if called by any account other than the recipient.
    modifier onlyRecipient() {
        _checkRecipient();
        _;
    }

    /// @notice Throws if the voting adaptor is not set.
    modifier whenVotingAdaptorIsSet() {
        _checkVotingAdaptorIsSet();
        _;
    }

    /// @notice Initializes the contract.
    /// @param _isFullyRevokable Whether the tokens are fully revokable.
    /// @param _initialDelegateParams The optional initial delegate information (skipped if empty bytes).
    function initialize(bool _isFullyRevokable, bytes calldata _initialDelegateParams) external {
        address _factory = address(factory());
        uint256 _totalLocked = totalLocked();
        uint40 _endTime = endTime();
        IERC20 _token = token();

        if (msg.sender != _factory) revert NOT_FACTORY(msg.sender);
        if (_token.balanceOf(address(this)) < _totalLocked) revert INSUFFICIENT_BALANCE();

        disabledAt = _endTime; // Set to maximum time
        isFullyRevokable = _isFullyRevokable;

        if (_initialDelegateParams.length != 0) _delegate(_initialDelegateParams);

        emit VestingEscrowInitialized(
            _factory,
            recipient(),
            address(_token),
            _totalLocked,
            startTime(),
            _endTime,
            cliffLength(),
            _isFullyRevokable
        );
    }

    /// @notice Get the number of unclaimed, vested tokens for recipient.
    function unclaimed() public view returns (uint256) {
        if (isFullyRevoked) return 0;

        uint256 claimTime = Math.min(block.timestamp, disabledAt);
        return _totalVestedAt(claimTime) - totalClaimed;
    }

    /// @notice Get the number of locked tokens for recipient.
    function locked() public view returns (uint256) {
        if (block.timestamp >= disabledAt) return 0;

        return totalLocked() - _totalVestedAt(block.timestamp);
    }

    /// @notice Claim tokens which have vested.
    /// @param beneficiary Address to transfer claimed tokens to.
    /// @param amount Amount of tokens to claim.
    function claim(address beneficiary, uint256 amount) external onlyRecipient returns (uint256) {
        uint256 claimable = Math.min(unclaimed(), amount);
        totalClaimed += claimable;

        token().safeTransfer(beneficiary, claimable);
        emit Claim(beneficiary, claimable);

        return claimable;
    }

    /// @notice Delegate voting power of all available tokens.
    /// @param params The ABI-encoded delegate params.
    function delegate(bytes calldata params) external onlyRecipient returns (bytes memory) {
        return _delegate(params);
    }

    /// @notice Participate in a governance vote using all available tokens on the contract's balance.
    /// @param params The ABI-encoded data for call. Can be obtained from VotingAdaptor.encodeVoteCalldata.
    function vote(bytes calldata params) external onlyRecipient whenVotingAdaptorIsSet returns (bytes memory) {
        return _votingAdaptor().functionDelegateCall(abi.encodeCall(IVotingAdaptor.vote, (params)));
    }

    // forgefmt: disable-next-item
    /// @notice Participate in a governance vote with a reason using all available tokens on the contract's balance.
    /// @param params The ABI-encoded data for call. Can be obtained from VotingAdaptor.encodeVoteWithReasonCalldata.
    function voteWithReason(bytes calldata params) external onlyRecipient whenVotingAdaptorIsSet returns (bytes memory) {
        return _votingAdaptor().functionDelegateCall(abi.encodeCall(IVotingAdaptor.voteWithReason, (params)));
    }

    /// @notice Disable further flow of tokens and revoke the unvested part to owner.
    function revokeUnvested() external onlyOwnerOrManager {
        uint256 revokable = locked();
        if (revokable == 0) revert NOTHING_TO_REVOKE();

        disabledAt = uint40(block.timestamp);

        token().safeTransfer(_owner(), revokable);
        emit UnvestedTokensRevoked(msg.sender, revokable);
    }

    /// @notice Disable further flow of tokens and revoke all tokens to owner.
    function revokeAll() external onlyOwner {
        if (!isFullyRevokable) revert NOT_FULLY_REVOKABLE();
        if (isFullyRevoked) revert ALREADY_FULLY_REVOKED();

        uint256 revokable = locked() + unclaimed();
        if (revokable == 0) revert NOTHING_TO_REVOKE();

        isFullyRevoked = true;
        disabledAt = uint40(block.timestamp);

        token().safeTransfer(_owner(), revokable);
        emit VestingFullyRevoked(msg.sender, revokable);
    }

    /// @notice Permanently disable full token revocation.
    function permanentlyDisableFullRevocation() external onlyOwner {
        if (!isFullyRevokable) revert NOT_FULLY_REVOKABLE();

        isFullyRevokable = false;
        emit FullRevocationPermanentlyDisabled(msg.sender);
    }

    /// @notice Recover any ERC20 token to the recipient.
    /// @param token_ Address of the ERC20 token to recover.
    /// @param amount Amount of tokens to recover.
    function recoverERC20(address token_, uint256 amount) external {
        uint256 recoverable = amount;
        if (token_ == address(token())) {
            uint256 available = token().balanceOf(address(this)) - (locked() + unclaimed());
            recoverable = Math.min(recoverable, available);
        }
        if (recoverable > 0) {
            IERC20(token_).safeTransfer(recipient(), recoverable);
            emit ERC20Recovered(token_, recoverable);
        }
    }

    /// @notice Recover any ETH to the recipient.
    function recoverEther() external {
        uint256 amount = address(this).balance;
        if (amount > 0) {
            payable(recipient()).sendValue(amount);
            emit ETHRecovered(amount);
        }
    }

    /// @dev Returns the factory owner.
    function _owner() internal view returns (address) {
        return factory().owner();
    }

    /// @dev Returns the factory manager.
    function _manager() internal view returns (address) {
        return factory().manager();
    }

    /// @dev Returns the factory voting adaptor.
    function _votingAdaptor() internal view returns (address) {
        return factory().votingAdaptor();
    }

    /// @dev Throws if called by any account other than the owner.
    function _checkOwner() internal view {
        if (msg.sender != _owner()) {
            revert NOT_OWNER(msg.sender);
        }
    }

    /// @dev Throws if called by any account other than the owner or manager.
    function _checkOwnerOrManager() internal view {
        if (msg.sender != _owner() && msg.sender != _manager()) {
            revert NOT_OWNER_OR_MANAGER(msg.sender);
        }
    }

    /// @dev Throws if called by any account other than the recipient.
    function _checkRecipient() internal view {
        if (msg.sender != recipient()) {
            revert NOT_RECIPIENT(msg.sender);
        }
    }

    /// @dev Throws if the voting adaptor is not set.
    function _checkVotingAdaptorIsSet() internal view {
        if (_votingAdaptor() == address(0)) {
            revert VOTING_ADAPTOR_NOT_SET();
        }
    }

    /// @notice Delegate voting power of all available tokens.
    /// @param params The ABI-encoded delegate params.
    function _delegate(bytes calldata params) internal whenVotingAdaptorIsSet returns (bytes memory) {
        return _votingAdaptor().functionDelegateCall(abi.encodeCall(IVotingAdaptor.delegate, params));
    }

    /// @dev Returns the vested token amount at a specific time.
    /// @param time The time to retrieve the vesting amount for.
    function _totalVestedAt(uint256 time) internal pure returns (uint256) {
        uint40 _startTime = startTime();
        uint256 _totalLocked = totalLocked();
        if (time < _startTime + cliffLength()) {
            return 0;
        }
        return Math.min(_totalLocked * (time - _startTime) / (endTime() - _startTime), _totalLocked);
    }
}
