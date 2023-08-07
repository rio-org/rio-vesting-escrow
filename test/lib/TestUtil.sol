// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import 'forge-std/Test.sol';
import {OZVotingAdaptor} from '../../src/adaptors/OZVotingAdaptor.sol';
import {VestingEscrowFactory} from '../../src/VestingEscrowFactory.sol';
import {VestingEscrow} from '../../src/VestingEscrow.sol';
import {OZVotingToken} from './OZVotingToken.sol';

contract TestUtil is Test {
    struct Config {
        uint256 amount;
        address recipient;
        uint40 vestingDuration;
        uint40 vestingStart;
        uint40 cliffLength;
        bool isFullyRevokable;
    }

    address public constant RANDOM_GUY = address(0x123);

    VestingEscrowFactory public factory;
    VestingEscrow public deployedVesting;
    OZVotingAdaptor public ozVotingAdaptor;
    OZVotingToken public token;

    uint256 public amount;
    address public recipient;
    uint40 public startTime;
    uint40 public endTime;
    uint40 public cliffLength;
    bool public isFullyRevokable;

    function deployAndConfigure(Config memory config) public {
        amount = config.amount;
        recipient = config.recipient;
        startTime = config.vestingStart;
        endTime = config.vestingStart + config.vestingDuration;
        cliffLength = config.cliffLength;
        isFullyRevokable = config.isFullyRevokable;

        token = new OZVotingToken();
        ozVotingAdaptor = new OZVotingAdaptor(address(1), address(1), address(1));
        factory = new VestingEscrowFactory(
            address(new VestingEscrow()),
            address(token),
            address(1),
            address(1),
            address(ozVotingAdaptor)
        );

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
}
