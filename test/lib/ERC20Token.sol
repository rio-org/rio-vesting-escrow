// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract ERC20Token is ERC20 {
    constructor() ERC20('ERC20Token', 'ERC20') {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
