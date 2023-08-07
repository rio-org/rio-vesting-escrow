// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import 'forge-std/Test.sol';
import {OZVotingAdaptor} from '../../src/adaptors/OZVotingAdaptor.sol';
import {VestingEscrowFactory} from '../../src/VestingEscrowFactory.sol';
import {VestingEscrow} from '../../src/VestingEscrow.sol';
import {GovernorVotesMock} from './GovernorVotesMock.sol';
import {OZVotingToken} from './OZVotingToken.sol';

contract TestUtil is Test {
    struct ProtocolConfig {
        address owner;
        address manager;
    }

    struct VestingEscrowConfig {
        uint256 amount;
        address recipient;
        uint40 vestingDuration;
        uint40 vestingStart;
        uint40 cliffLength;
        bool isFullyRevokable;
    }

    address public constant RANDOM_GUY = address(0x123);

    VestingEscrowFactory public factory;
    OZVotingAdaptor public ozVotingAdaptor;

    GovernorVotesMock public governor;
    OZVotingToken public token;

    VestingEscrow public deployedVesting;

    uint256 public amount;
    address public recipient;
    uint40 public startTime;
    uint40 public endTime;
    uint40 public cliffLength;
    bool public isFullyRevokable;

    function setUpProtocol(ProtocolConfig memory config) public {
        token = new OZVotingToken();
        governor = new GovernorVotesMock(address(token));
        ozVotingAdaptor = new OZVotingAdaptor(address(governor), address(token), config.owner);
        factory = new VestingEscrowFactory(
            address(new VestingEscrow()),
            address(token),
            config.owner,
            config.manager,
            address(ozVotingAdaptor)
        );

        vm.deal(RANDOM_GUY, 100 ether);
    }

    function deployVestingEscrow(VestingEscrowConfig memory config) public {
        amount = config.amount;
        recipient = config.recipient;
        startTime = config.vestingStart;
        endTime = config.vestingStart + config.vestingDuration;
        cliffLength = config.cliffLength;
        isFullyRevokable = config.isFullyRevokable;

        vm.startPrank(recipient);
        token.mint(recipient, amount);
        token.approve(address(factory), type(uint256).max);
        deployedVesting = VestingEscrow(
            factory.deployVestingContract(
                amount, recipient, config.vestingDuration, startTime, cliffLength, isFullyRevokable
            )
        );
        vm.stopPrank();
    }

    receive() external payable {}
}
