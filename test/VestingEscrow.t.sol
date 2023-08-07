// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import 'forge-std/Test.sol';
import {TestUtil} from './lib/TestUtil.sol';
import {IVestingEscrow} from '../src/interfaces/IVestingEscrow.sol';
import {OZVotingAdaptor} from '../src/adaptors/OZVotingAdaptor.sol';

contract VestingEscrowTest is TestUtil {
    function setUp() public {
        setUpProtocol(ProtocolConfig({owner: address(1), manager: address(2)}));
        deployVestingEscrow(
            VestingEscrowConfig({
                amount: 1e18,
                recipient: address(this),
                vestingDuration: 365 days,
                vestingStart: uint40(block.timestamp),
                cliffLength: 90 days,
                isFullyRevokable: false
            })
        );
    }

    function testClaimNonRecipientReverts() public {
        vm.warp(endTime);
        vm.prank(RANDOM_GUY);

        vm.expectRevert();
        deployedVesting.claim(RANDOM_GUY, type(uint256).max);
    }

    function testClaimFull() public {
        vm.warp(endTime);
        assertEq(token.balanceOf(recipient), 0);

        vm.prank(recipient);
        assertEq(deployedVesting.claim(recipient, type(uint256).max), amount);
        assertEq(token.balanceOf(recipient), amount);
    }

    function testClaimLess() public {
        vm.warp(endTime);
        assertEq(token.balanceOf(recipient), 0);

        vm.prank(recipient);
        assertEq(deployedVesting.claim(recipient, amount / 10), amount / 10);
        assertEq(token.balanceOf(recipient), amount / 10);
    }

    function testClaimBeneficiary() public {
        vm.warp(endTime);
        assertEq(token.balanceOf(RANDOM_GUY), 0);

        vm.prank(recipient);
        deployedVesting.claim(RANDOM_GUY, type(uint256).max);

        assertEq(token.balanceOf(RANDOM_GUY), amount);
    }

    function testClaimBeforeStart() public {
        vm.warp(startTime - 1);
        vm.prank(recipient);

        assertEq(deployedVesting.claim(recipient, type(uint256).max), 0);
        assertEq(token.balanceOf(recipient), 0);
    }

    function testClaimBeforeCliff() public {
        vm.warp(startTime + cliffLength - 1);
        vm.prank(recipient);

        deployedVesting.claim(recipient, type(uint256).max);

        assertEq(token.balanceOf(recipient), 0);
    }

    function testClaimAfterCliff() public {
        vm.warp(startTime + cliffLength + 1);
        vm.prank(recipient);

        uint256 amountClaimed = deployedVesting.claim(recipient, type(uint256).max);
        uint256 expectedAmount = amount * (block.timestamp - startTime) / (endTime - startTime);

        assertEq(amountClaimed, expectedAmount);
        assertEq(token.balanceOf(recipient), expectedAmount);
        assertEq(deployedVesting.totalClaimed(), expectedAmount);
    }

    function testClaimAfterEnd() public {
        vm.warp(endTime + 1);
        deployedVesting.claim(recipient, type(uint256).max);

        assertEq(token.balanceOf(recipient), amount);
    }

    function testClaimPartial() public {
        vm.warp((endTime - startTime) / 2);
        vm.prank(recipient);

        deployedVesting.claim(recipient, type(uint256).max);
        uint256 expectedAmount = amount * (block.timestamp - startTime) / (endTime - startTime);

        assertEq(token.balanceOf(recipient), expectedAmount);
        assertEq(deployedVesting.totalClaimed(), expectedAmount);
    }

    function testClaimMultiple() public {
        vm.warp(startTime);

        uint256 recipientBalance = 0;
        for (uint256 i = 1; i <= 11; i++) {
            vm.warp(((endTime - startTime) / 10) * i);

            deployedVesting.claim(recipient, type(uint256).max);
            uint256 newBalance = token.balanceOf(recipient);

            if (block.timestamp < startTime + cliffLength) {
                assertEq(newBalance, recipientBalance);
            } else {
                assertTrue(newBalance > recipientBalance);
            }
            recipientBalance = newBalance;
        }

        assertEq(token.balanceOf(recipient), recipientBalance);
    }

    function testDelegate() public {
        assertEq(token.delegates(address(deployedVesting)), address(0));

        vm.prank(recipient);
        deployedVesting.delegate(ozVotingAdaptor.encodeDelegateCallData(RANDOM_GUY));
        assertEq(token.delegates(address(deployedVesting)), RANDOM_GUY);
    }

    function testDelegateAfterUpgrade() public {
        assertEq(token.delegates(address(deployedVesting)), address(0));

        address newVotingAdaptor = address(new OZVotingAdaptor(address(governor), address(token), factory.owner()));

        vm.prank(factory.owner());
        factory.updateVotingAdaptor(newVotingAdaptor);

        vm.prank(recipient);
        deployedVesting.delegate(ozVotingAdaptor.encodeDelegateCallData(RANDOM_GUY));
        assertEq(token.delegates(address(deployedVesting)), RANDOM_GUY);
    }

    function testDelegateFromNonRecipientReverts() public {
        bytes memory params = ozVotingAdaptor.encodeDelegateCallData(RANDOM_GUY);

        vm.prank(RANDOM_GUY);
        vm.expectRevert(abi.encodeWithSelector(IVestingEscrow.NOT_RECIPIENT.selector, RANDOM_GUY));
        deployedVesting.delegate(params);
    }
}
