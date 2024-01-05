// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IGovernor} from '@openzeppelin/contracts/governance/IGovernor.sol';
import {IVotes} from '@openzeppelin/contracts/governance/utils/IVotes.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';
import {IVotingAdaptor} from 'src/interfaces/IVotingAdaptor.sol';

contract OZVotingAdaptor is IVotingAdaptor, Ownable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    /// @notice The governor contract address.
    address public immutable governor;

    /// @notice The voting token contract address.
    address public immutable votingToken;

    constructor(address _governor, address _votingToken, address _owner) {
        if (_owner == address(0)) revert INVALID_OWNER();
        if (_governor == address(0)) revert INVALID_GOVERNOR();
        if (_votingToken == address(0)) revert INVALID_VOTING_TOKEN();

        governor = _governor;
        votingToken = _votingToken;

        _transferOwnership(_owner);
    }

    /// @notice Encode OZ delegate calldata for use in VestingEscrow.
    /// @param delegatee The delegatee address.
    function encodeDelegateCallData(address delegatee) external pure returns (bytes memory) {
        return abi.encode(delegatee);
    }

    /// @notice Encode OZ vote calldata for use in VestingEscrow.
    /// @param proposalId The proposal id.
    /// @param support The support value.
    function encodeVoteCallData(uint256 proposalId, uint8 support) external pure returns (bytes memory) {
        return abi.encode(proposalId, support);
    }

    // forgefmt: disable-next-item
    /// @notice Encode OZ vote with reason calldata for use in VestingEscrow.
    /// @param proposalId The proposal id.
    /// @param support The support value.
    /// @param reason The vote reason.
    function encodeVoteWithReasonCallData(uint256 proposalId, uint8 support, string calldata reason) external pure returns (bytes memory) {
        return abi.encode(proposalId, support, reason);
    }

    /// @notice Delegate votes.
    /// @param params The ABI-encoded delegatee address.
    function delegate(bytes calldata params) external {
        IVotes(votingToken).delegate(abi.decode(params, (address)));
    }

    /// @notice Vote on an OZ proposal.
    /// @param params The ABI-encoded proposal id and support value.
    function vote(bytes calldata params) external {
        (uint256 proposalId, uint8 support) = abi.decode(params, (uint256, uint8));
        IGovernor(governor).castVote(proposalId, support);
    }

    /// @notice Vote on a proposal with a reason.
    /// @param params The ABI-encoded proposal id, support value, and reason.
    function voteWithReason(bytes calldata params) external {
        (uint256 proposalId, uint8 support, string memory reason) = abi.decode(params, (uint256, uint8, string));
        IGovernor(governor).castVoteWithReason(proposalId, support, reason);
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
}
