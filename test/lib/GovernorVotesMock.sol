// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {Governor} from '@openzeppelin/contracts/governance/Governor.sol';
import {GovernorVotes} from '@openzeppelin/contracts/governance/extensions/GovernorVotes.sol';
import {GovernorCountingSimple} from '@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol';
import {IVotes} from '@openzeppelin/contracts/governance/utils/IVotes.sol';

contract GovernorVotesMock is GovernorVotes, GovernorCountingSimple {
    constructor(address _votingToken) GovernorVotes(IVotes(_votingToken)) Governor('MockGovernor') {}

    function quorum(uint256) public pure override returns (uint256) {
        return 0;
    }

    function votingDelay() public pure override returns (uint256) {
        return 0;
    }

    function votingPeriod() public pure override returns (uint256) {
        return 16;
    }
}
