// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {Test} from 'forge-std/Test.sol';
import {OZVotingAdaptor} from 'src/adaptors/OZVotingAdaptor.sol';
import {VestingEscrowFactory} from 'src/VestingEscrowFactory.sol';
import {GovernorVotesMock} from 'test/lib/GovernorVotesMock.sol';
import {OZVotingToken} from 'test/lib/OZVotingToken.sol';
import {VestingEscrow} from 'src/VestingEscrow.sol';

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
        bytes initialDelegateParams;
    }

    enum VoteType {
        Against,
        For,
        Abstain
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
    bytes public initialDelegateParams;

    function setUpProtocol(ProtocolConfig memory config) public {
        token = new OZVotingToken();
        governor = new GovernorVotesMock(address(token));
        ozVotingAdaptor = new OZVotingAdaptor(address(governor), address(token), config.owner);
        factory = new VestingEscrowFactory(
            address(new VestingEscrow()), address(token), config.owner, config.manager, address(ozVotingAdaptor)
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
        initialDelegateParams = config.initialDelegateParams;

        vm.startPrank(recipient);
        token.mint(recipient, amount);
        token.approve(address(factory), type(uint256).max);
        deployedVesting = VestingEscrow(
            factory.deployVestingContract(
                amount,
                recipient,
                config.vestingDuration,
                startTime,
                cliffLength,
                isFullyRevokable,
                initialDelegateParams
            )
        );
        vm.stopPrank();
    }

    function createProposal() public returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = address(0xdead);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        string memory description = 'Test Proposal';

        return governor.propose(targets, values, calldatas, description);
    }

    receive() external payable {}
}
