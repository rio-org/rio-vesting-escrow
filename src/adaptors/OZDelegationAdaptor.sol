// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IVotes} from '@openzeppelin/contracts/governance/utils/IVotes.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';
import {IVotingAdaptor} from 'src/interfaces/IVotingAdaptor.sol';

contract OZDelegationAdaptor is IVotingAdaptor, Ownable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    /// @notice The voting token contract address.
    address public immutable votingToken;

    constructor(address _votingToken, address _owner) Ownable(_owner) {
        if (_votingToken == address(0)) revert INVALID_VOTING_TOKEN();

        votingToken = _votingToken;
    }

    /// @notice Encode OZ delegate calldata for use in VestingEscrow.
    /// @param delegatee The delegatee address.
    function encodeDelegateCallData(address delegatee) external pure returns (bytes memory) {
        return abi.encode(delegatee);
    }

    /// @notice Delegate OZ votes.
    /// @param params The ABI-encoded delegatee address.
    function delegate(bytes calldata params) external {
        IVotes(votingToken).delegate(abi.decode(params, (address)));
    }

    /// @notice Vote on a proposal (NOT IMPLEMENTED)
    function vote(bytes calldata) external pure {
        revert NOT_IMPLEMENTED();
    }

    /// @notice Vote on a proposal with a reason (NOT IMPLEMENTED)
    function voteWithReason(bytes calldata) external pure {
        revert NOT_IMPLEMENTED();
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
