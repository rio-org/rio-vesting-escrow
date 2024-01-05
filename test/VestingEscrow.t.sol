// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {TestUtil} from 'test/lib/TestUtil.sol';
import {IVestingEscrow} from 'src/interfaces/IVestingEscrow.sol';
import {OZVotingAdaptor} from 'src/adaptors/OZVotingAdaptor.sol';
import {ERC20NoReturnToken} from 'test/lib/ERC20NoReturnToken.sol';
import {ERC20Token} from 'test/lib/ERC20Token.sol';

contract VestingEscrowTest is TestUtil {
    function setUp() public {
        setUpProtocol(ProtocolConfig({owner: address(1), manager: address(2)}));
        deployVestingEscrow(
            VestingEscrowConfig({
                amount: 1 ether,
                recipient: address(this),
                vestingDuration: 365 days,
                vestingStart: uint40(block.timestamp),
                cliffLength: 90 days,
                isFullyRevokable: true,
                initialDelegateParams: new bytes(0)
            })
        );
    }

    function testInitializeFromNonFactoryReverts() public {
        address _owner = factory.owner();

        vm.prank(_owner);
        vm.expectRevert(abi.encodeWithSelector(IVestingEscrow.NOT_FACTORY.selector, _owner));
        deployedVesting.initialize(true, new bytes(0));
    }

    function testClaimNonRecipientReverts() public {
        vm.warp(endTime);
        vm.prank(RANDOM_GUY);

        vm.expectRevert(abi.encodeWithSelector(IVestingEscrow.NOT_RECIPIENT.selector, RANDOM_GUY));
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
        uint256 expectedAmount = (amount * (block.timestamp - startTime)) / (endTime - startTime);

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
        vm.warp(block.timestamp + ((endTime - startTime) / 2));
        vm.prank(recipient);

        deployedVesting.claim(recipient, type(uint256).max);
        uint256 expectedAmount = (amount * (block.timestamp - startTime)) / (endTime - startTime);

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

    function testInitialDelegate() public {
        deployVestingEscrow(
            VestingEscrowConfig({
                amount: 1 ether,
                recipient: address(this),
                vestingDuration: 365 days,
                vestingStart: uint40(block.timestamp),
                cliffLength: 90 days,
                isFullyRevokable: false,
                initialDelegateParams: ozVotingAdaptor.encodeDelegateCallData(RANDOM_GUY)
            })
        );

        assertEq(token.delegates(address(deployedVesting)), RANDOM_GUY);
    }

    function testInitialDelegateEmptySkipsDelegation() public {
        deployVestingEscrow(
            VestingEscrowConfig({
                amount: 1 ether,
                recipient: address(this),
                vestingDuration: 365 days,
                vestingStart: uint40(block.timestamp),
                cliffLength: 90 days,
                isFullyRevokable: false,
                initialDelegateParams: new bytes(0)
            })
        );

        assertEq(token.delegates(address(deployedVesting)), address(0));
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

    function testDelegateAdaptorNotSetReverts() public {
        bytes memory params = ozVotingAdaptor.encodeDelegateCallData(RANDOM_GUY);

        vm.prank(factory.owner());
        factory.updateVotingAdaptor(address(0));

        vm.prank(recipient);
        vm.expectRevert(IVestingEscrow.VOTING_ADAPTOR_NOT_SET.selector);
        deployedVesting.delegate(params);
    }

    function testVote() public {
        vm.prank(recipient);
        deployedVesting.delegate(ozVotingAdaptor.encodeDelegateCallData(address(deployedVesting)));

        uint256 proposalId = createProposal();
        uint256 votingBalance = token.getVotes(address(deployedVesting));

        vm.roll(block.number + 1);

        vm.prank(recipient);
        deployedVesting.vote(ozVotingAdaptor.encodeVoteCallData(proposalId, uint8(VoteType.For)));

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(forVotes, votingBalance);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function testVoteAfterClaimAll() public {
        vm.warp(endTime);

        vm.prank(recipient);
        deployedVesting.delegate(ozVotingAdaptor.encodeDelegateCallData(address(deployedVesting)));

        vm.prank(recipient);
        deployedVesting.claim(recipient, type(uint256).max);

        assertEq(token.balanceOf(address(deployedVesting)), 0);

        uint256 proposalId = createProposal();
        vm.roll(block.number + 1);

        vm.prank(recipient);
        deployedVesting.vote(ozVotingAdaptor.encodeVoteCallData(proposalId, uint8(VoteType.For)));

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function testVoteAfterUpgrade() public {
        vm.prank(recipient);
        deployedVesting.delegate(ozVotingAdaptor.encodeDelegateCallData(address(deployedVesting)));

        address newVotingAdaptor = address(new OZVotingAdaptor(address(governor), address(token), factory.owner()));

        vm.prank(factory.owner());
        factory.updateVotingAdaptor(newVotingAdaptor);

        uint256 proposalId = createProposal();
        uint256 votingBalance = token.getVotes(address(deployedVesting));

        vm.roll(block.number + 1);

        vm.prank(recipient);
        deployedVesting.vote(ozVotingAdaptor.encodeVoteCallData(proposalId, uint8(VoteType.For)));

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(forVotes, votingBalance);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function testVoteAdaptorNotSetReverts() public {
        uint256 proposalId = createProposal();
        bytes memory params = ozVotingAdaptor.encodeVoteCallData(proposalId, uint8(VoteType.For));

        vm.prank(factory.owner());
        factory.updateVotingAdaptor(address(0));

        vm.roll(block.number + 1);

        vm.prank(recipient);
        vm.expectRevert(IVestingEscrow.VOTING_ADAPTOR_NOT_SET.selector);
        deployedVesting.vote(params);
    }

    function testVoteFromNonRecipientReverts() public {
        uint256 proposalId = createProposal();
        bytes memory params = ozVotingAdaptor.encodeVoteCallData(proposalId, uint8(VoteType.For));

        vm.roll(block.number + 1);

        vm.prank(RANDOM_GUY);
        vm.expectRevert(abi.encodeWithSelector(IVestingEscrow.NOT_RECIPIENT.selector, RANDOM_GUY));
        deployedVesting.vote(params);
    }

    function testVoteWithReason() public {
        vm.prank(recipient);
        deployedVesting.delegate(ozVotingAdaptor.encodeDelegateCallData(address(deployedVesting)));

        uint256 proposalId = createProposal();
        uint256 votingBalance = token.getVotes(address(deployedVesting));

        vm.roll(block.number + 1);

        vm.prank(recipient);
        deployedVesting.voteWithReason(
            ozVotingAdaptor.encodeVoteWithReasonCallData(proposalId, uint8(VoteType.For), 'Reason')
        );

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(forVotes, votingBalance);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function testVoteWithReasonAfterClaimAll() public {
        vm.warp(endTime);

        vm.prank(recipient);
        deployedVesting.delegate(ozVotingAdaptor.encodeDelegateCallData(address(deployedVesting)));

        vm.prank(recipient);
        deployedVesting.claim(recipient, type(uint256).max);

        assertEq(token.balanceOf(address(deployedVesting)), 0);

        uint256 proposalId = createProposal();
        vm.roll(block.number + 1);

        vm.prank(recipient);
        deployedVesting.voteWithReason(
            ozVotingAdaptor.encodeVoteWithReasonCallData(proposalId, uint8(VoteType.For), 'Reason')
        );

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function testVoteWithReasonAfterUpgrade() public {
        vm.prank(recipient);
        deployedVesting.delegate(ozVotingAdaptor.encodeDelegateCallData(address(deployedVesting)));

        address newVotingAdaptor = address(new OZVotingAdaptor(address(governor), address(token), factory.owner()));

        vm.prank(factory.owner());
        factory.updateVotingAdaptor(newVotingAdaptor);

        uint256 proposalId = createProposal();
        uint256 votingBalance = token.getVotes(address(deployedVesting));

        vm.roll(block.number + 1);

        vm.prank(recipient);
        deployedVesting.voteWithReason(
            ozVotingAdaptor.encodeVoteWithReasonCallData(proposalId, uint8(VoteType.For), 'Reason')
        );

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(forVotes, votingBalance);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function testVoteWithReasonAdaptorNotSetReverts() public {
        uint256 proposalId = createProposal();
        bytes memory params = ozVotingAdaptor.encodeVoteWithReasonCallData(proposalId, uint8(VoteType.For), 'Reason');

        vm.prank(factory.owner());
        factory.updateVotingAdaptor(address(0));

        vm.roll(block.number + 1);

        vm.prank(recipient);
        vm.expectRevert(IVestingEscrow.VOTING_ADAPTOR_NOT_SET.selector);
        deployedVesting.voteWithReason(params);
    }

    function testVoteWithReasonFromNonRecipientReverts() public {
        uint256 proposalId = createProposal();
        bytes memory params = ozVotingAdaptor.encodeVoteWithReasonCallData(proposalId, uint8(VoteType.For), 'Reason');

        vm.roll(block.number + 1);

        vm.prank(RANDOM_GUY);
        vm.expectRevert(abi.encodeWithSelector(IVestingEscrow.NOT_RECIPIENT.selector, RANDOM_GUY));
        deployedVesting.voteWithReason(params);
    }

    function testLockedUnclaimed() public {
        assertEq(deployedVesting.locked(), deployedVesting.totalLocked());
        assertEq(deployedVesting.unclaimed(), 0);

        vm.warp(endTime);
        assertEq(deployedVesting.locked(), 0);
        assertEq(deployedVesting.unclaimed(), deployedVesting.totalLocked());

        vm.prank(recipient);
        deployedVesting.claim(recipient, type(uint256).max);
        assertEq(deployedVesting.unclaimed(), 0);
    }

    function testRecoverNonVestedToken() public {
        ERC20Token token2 = new ERC20Token();

        token2.mint(recipient, amount);
        token2.transfer(address(deployedVesting), amount);

        deployedVesting.recoverERC20(address(token2), amount);
        assertEq(token2.balanceOf(recipient), amount);
    }

    function testRecoverNonVestedTokenWithBadImpl() public {
        ERC20NoReturnToken token2 = new ERC20NoReturnToken();

        token2.mint(address(deployedVesting), amount);

        deployedVesting.recoverERC20(address(token2), amount);
        assertEq(token2.balanceOf(recipient), amount);
    }

    function testRecoverLockedTokens() public {
        deployedVesting.recoverERC20(address(token), amount);
        assertEq(token.balanceOf(recipient), 0);
    }

    function testRecoverExtraLockedTokens() public {
        uint256 extra = 10 ** 17;
        token.mint(address(deployedVesting), extra);

        deployedVesting.recoverERC20(address(token), amount);
        assertEq(token.balanceOf(recipient), extra);
    }

    function testRecoverExtraLockedTokensPartiallyClaimed() public {
        uint256 extra = 10 ** 17;
        uint256 claimAmount = 3 * extra;

        token.mint(address(deployedVesting), extra);

        vm.warp(endTime);
        vm.prank(recipient);
        deployedVesting.claim(RANDOM_GUY, claimAmount);
        deployedVesting.recoverERC20(address(token), amount);

        assertEq(token.balanceOf(recipient), extra);
        assertEq(token.balanceOf(RANDOM_GUY), claimAmount);
    }

    function testRecoverLockedTokensAfterEnd() public {
        vm.warp(endTime + 1);
        deployedVesting.recoverERC20(address(token), amount);

        assertEq(token.balanceOf(recipient), 0);
        assertEq(deployedVesting.locked(), 0);
        assertEq(deployedVesting.unclaimed(), amount);
    }

    function testRecoverLockedTokensAfterEndPartiallyClaimed() public {
        vm.warp(endTime + 1);
        uint256 claimAmount = 10 ** 17;

        vm.prank(recipient);
        deployedVesting.claim(RANDOM_GUY, claimAmount);
        deployedVesting.recoverERC20(address(token), amount);

        assertEq(token.balanceOf(recipient), 0);
        assertEq(deployedVesting.locked(), 0);
        assertEq(deployedVesting.unclaimed(), amount - claimAmount);
    }

    function testRecoverEther() public {
        vm.deal(address(deployedVesting), 1 ether);
        assertEq(address(deployedVesting).balance, 1 ether);

        uint256 balanceBefore = recipient.balance;

        deployedVesting.recoverEther();
        assertEq(recipient.balance, balanceBefore + 1 ether);
        assertEq(address(deployedVesting).balance, 0);
    }

    function testRecoverExtraAfterRevokeUnvested() public {
        uint256 extra = 10 ** 17;
        token.mint(address(deployedVesting), extra);

        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeUnvested();

        assertEq(token.balanceOf(factory.owner()), amount + ownerBalance);

        deployedVesting.recoverERC20(address(token), extra + 1);
        assertEq(token.balanceOf(recipient), extra);
    }

    function testRecoverExtraAfterRevokeUnvestedPartially() public {
        uint256 extra = 10 ** 17;
        token.mint(address(deployedVesting), extra);

        vm.warp(block.timestamp + ((endTime - startTime) / 2));

        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeUnvested();

        uint256 vested = (amount * (block.timestamp - startTime)) / (endTime - startTime);
        uint256 expectedAmount = amount - vested;

        assertEq(token.balanceOf(factory.owner()), expectedAmount + ownerBalance);

        deployedVesting.recoverERC20(address(token), extra + 1);
        assertEq(token.balanceOf(recipient), extra);

        deployedVesting.claim(recipient, type(uint256).max);
        assertEq(token.balanceOf(recipient), extra + amount - expectedAmount);
    }

    function testRecoverExtraAfterRevokeAll() public {
        uint256 extra = 10 ** 17;
        token.mint(address(deployedVesting), extra);

        vm.warp(block.timestamp + ((endTime - startTime) / 2));

        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeAll();

        assertEq(token.balanceOf(factory.owner()), amount + ownerBalance);

        deployedVesting.recoverERC20(address(token), amount);
        assertEq(token.balanceOf(recipient), extra);
    }

    function testNonOwnerRevokeAllReverts() public {
        vm.prank(RANDOM_GUY);
        vm.expectRevert(abi.encodeWithSelector(IVestingEscrow.NOT_OWNER.selector, RANDOM_GUY));
        deployedVesting.revokeAll();
    }

    function testRevokeAllNonFullyRevocableReverts() public {
        deployVestingEscrow(
            VestingEscrowConfig({
                amount: 1 ether,
                recipient: address(this),
                vestingDuration: 365 days,
                vestingStart: uint40(block.timestamp),
                cliffLength: 90 days,
                isFullyRevokable: false,
                initialDelegateParams: new bytes(0)
            })
        );

        vm.prank(factory.owner());
        vm.expectRevert(IVestingEscrow.NOT_FULLY_REVOKABLE.selector);
        deployedVesting.revokeAll();
    }

    function testRevokeAllAfterPermanentlyDisablingFullRevocationReverts() public {
        vm.prank(factory.owner());
        deployedVesting.permanentlyDisableFullRevocation();

        vm.prank(factory.owner());
        vm.expectRevert(IVestingEscrow.NOT_FULLY_REVOKABLE.selector);
        deployedVesting.revokeAll();
    }

    function testRevokeAllTwiceReverts() public {
        vm.startPrank(factory.owner());
        deployedVesting.revokeAll();

        vm.expectRevert(IVestingEscrow.ALREADY_FULLY_REVOKED.selector);
        deployedVesting.revokeAll();
    }

    function testRevokeAll() public {
        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeAll();

        assertEq(deployedVesting.disabledAt(), block.timestamp);
        assertEq(deployedVesting.unclaimed(), 0);
        assertEq(deployedVesting.locked(), 0);
        assertEq(token.balanceOf(factory.owner()), amount + ownerBalance);
    }

    function testRevokeAllAfterEndTime() public {
        vm.warp(endTime + 1);

        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeAll();

        assertEq(deployedVesting.disabledAt(), block.timestamp);
        assertEq(deployedVesting.unclaimed(), 0);
        assertEq(deployedVesting.locked(), 0);
        assertEq(token.balanceOf(factory.owner()), amount + ownerBalance);
        assertEq(token.balanceOf(recipient), 0);
    }

    function testRevokeAllBeforeStartTime() public {
        vm.warp(startTime - 1);

        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeAll();

        vm.prank(recipient);
        deployedVesting.claim(recipient, type(uint256).max);

        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.balanceOf(factory.owner()), amount + ownerBalance);
    }

    function testClaimAfterRevokeAll() public {
        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeAll();

        vm.warp(endTime);

        vm.prank(recipient);
        deployedVesting.claim(recipient, type(uint256).max);

        assertEq(deployedVesting.unclaimed(), 0);
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.balanceOf(factory.owner()), amount + ownerBalance);
    }

    function testRevokeAllAfterPartialClaim() public {
        vm.warp(startTime + 10 days);

        vm.prank(recipient);
        uint256 claimAmount = deployedVesting.claim(recipient, type(uint256).max);

        vm.warp(endTime);

        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeAll();

        assertEq(deployedVesting.unclaimed(), 0);

        assertEq(token.balanceOf(recipient), claimAmount);
        assertEq(token.balanceOf(factory.owner()), amount - claimAmount + ownerBalance);
    }

    function testRevokeAllAfterRevokeUnvested() public {
        vm.warp(block.timestamp + ((endTime - startTime) / 2));

        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeUnvested();

        uint256 expectedAmount = (amount * (block.timestamp - startTime)) / (endTime - startTime);

        assertEq(token.balanceOf(factory.owner()), amount - expectedAmount + ownerBalance);

        vm.prank(factory.owner());
        deployedVesting.revokeAll();

        assertEq(token.balanceOf(factory.owner()), amount + ownerBalance);
    }

    function testRevokeAllAfterRevokeUnvestedAndClaim() public {
        vm.warp(endTime);

        vm.prank(recipient);
        deployedVesting.claim(recipient, type(uint256).max);

        vm.prank(factory.owner());
        vm.expectRevert(IVestingEscrow.NOTHING_TO_REVOKE.selector);
        deployedVesting.revokeAll();
    }

    function testRevokeUnvestedNonOwnerOrManagerReverts() public {
        vm.prank(RANDOM_GUY);
        vm.expectRevert(abi.encodeWithSelector(IVestingEscrow.NOT_OWNER_OR_MANAGER.selector, RANDOM_GUY));
        deployedVesting.revokeUnvested();
    }

    function testNonOwnerPermanentlyDisableFullRevocationReverts() public {
        vm.prank(RANDOM_GUY);
        vm.expectRevert(abi.encodeWithSelector(IVestingEscrow.NOT_OWNER.selector, RANDOM_GUY));
        deployedVesting.permanentlyDisableFullRevocation();
    }

    function testDisabledAtIsInitiallyEndTime() public {
        assertEq(deployedVesting.disabledAt(), endTime);
    }

    function testRevokeUnvested() public {
        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeUnvested();

        assertEq(deployedVesting.disabledAt(), block.timestamp);
        assertEq(deployedVesting.locked(), 0);
        assertEq(token.balanceOf(factory.owner()), amount + ownerBalance);
    }

    function testRevokeUnvestedFromManager() public {
        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.manager());
        deployedVesting.revokeUnvested();

        assertEq(deployedVesting.disabledAt(), block.timestamp);
        assertEq(deployedVesting.locked(), 0);
        assertEq(token.balanceOf(factory.owner()), amount + ownerBalance);
    }

    function testRevokeUnvestedAfterEndTime() public {
        vm.warp(endTime + 1);

        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        vm.expectRevert(IVestingEscrow.NOTHING_TO_REVOKE.selector);
        deployedVesting.revokeUnvested();

        vm.prank(recipient);
        deployedVesting.claim(recipient, type(uint256).max);

        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.balanceOf(factory.owner()), ownerBalance);
    }

    function testRevokeUnvestedBeforeStartTime() public {
        vm.warp(startTime - 1);

        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeUnvested();

        vm.warp(endTime);

        vm.prank(recipient);
        deployedVesting.claim(recipient, type(uint256).max);

        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.balanceOf(factory.owner()), deployedVesting.totalLocked() + ownerBalance);
    }

    function testRevokeUnvestedPartiallyUnclaimed() public {
        vm.warp(startTime + 100 days);

        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeUnvested();

        vm.prank(recipient);
        deployedVesting.claim(recipient, amount);

        uint256 expectedAmount = (amount * (block.timestamp - startTime)) / (endTime - startTime);

        assertEq(token.balanceOf(recipient), expectedAmount);
        assertEq(token.balanceOf(factory.owner()), deployedVesting.totalLocked() - expectedAmount + ownerBalance);
    }

    function testRevokeUnvestedPartiallyClaimed() public {
        vm.warp(startTime + 100 days);

        vm.prank(recipient);
        uint256 claimAmount = deployedVesting.claim(recipient, type(uint256).max);
        uint256 ownerBalance = token.balanceOf(factory.owner());

        vm.prank(factory.owner());
        deployedVesting.revokeUnvested();

        assertEq(token.balanceOf(recipient), claimAmount);
        assertEq(token.balanceOf(factory.owner()), amount - claimAmount + ownerBalance);
    }
}
