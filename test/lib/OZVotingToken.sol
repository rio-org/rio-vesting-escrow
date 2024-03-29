// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Votes} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import {ERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {Nonces} from '@openzeppelin/contracts/utils/Nonces.sol';

contract OZVotingToken is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20('OZVotingToken', 'OZ') ERC20Permit('OZ') {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // The functions below are overrides required by Solidity.

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }
}
