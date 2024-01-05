// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {TestUtil} from 'test/lib/TestUtil.sol';
import {ERC20Token} from 'test/lib/ERC20Token.sol';

contract OZVotingAdaptorTest is TestUtil {
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

    function testRecoverERC20() public {
        ERC20Token token2 = new ERC20Token();
        address _owner = ozVotingAdaptor.owner();

        token2.mint(address(ozVotingAdaptor), amount);

        uint256 ownerBalance = token2.balanceOf(_owner);

        ozVotingAdaptor.recoverERC20(address(token2), amount);

        assertEq(token2.balanceOf(_owner), amount + ownerBalance);
        assertEq(token2.balanceOf(address(ozVotingAdaptor)), 0);
    }

    function testRecoverEther() public {
        vm.deal(address(ozVotingAdaptor), 1 ether);
        assertEq(address(ozVotingAdaptor).balance, 1 ether);

        address _owner = ozVotingAdaptor.owner();
        uint256 ownerBalance = address(_owner).balance;

        ozVotingAdaptor.recoverEther();

        assertEq(address(_owner).balance, ownerBalance + 1 ether);
        assertEq(address(ozVotingAdaptor).balance, 0);
    }

    function testSendEtherReverts() public {
        vm.deal(address(ozVotingAdaptor), 1 ether);
        assertEq(address(ozVotingAdaptor).balance, 1 ether);

        vm.prank(RANDOM_GUY);
        (bool success,) = address(ozVotingAdaptor).call{value: 1 ether}(new bytes(0));
        assertEq(success, false);
    }
}
