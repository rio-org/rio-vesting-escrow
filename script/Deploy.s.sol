// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from 'forge-std/Script.sol';
import {OZDelegationAdaptor} from 'src/adaptors/OZDelegationAdaptor.sol';
import {VestingEscrowFactory} from 'src/VestingEscrowFactory.sol';
import {VestingEscrow} from 'src/VestingEscrow.sol';

contract Deploy is Script {
    function run() public returns (VestingEscrowFactory factory, address vestingEscrowImpl, address votingAdaptor) {
        uint256 deployerKey = vm.envUint('DEPLOYER_PRIVATE_KEY');
        vm.startBroadcast(deployerKey);

        address token = vm.envAddress('TOKEN_ADDRESS');
        address owner = vm.envAddress('OWNER_ADDRESS');
        address manager = vm.envAddress('MANAGER_ADDRESS');
        bool areTokensLocked = vm.envBool('ARE_TOKENS_LOCKED');

        vestingEscrowImpl = address(new VestingEscrow());
        votingAdaptor = address(new OZDelegationAdaptor(token, owner));
        factory = new VestingEscrowFactory(vestingEscrowImpl, token, owner, manager, votingAdaptor, areTokensLocked);
        vm.stopBroadcast();
    }
}
