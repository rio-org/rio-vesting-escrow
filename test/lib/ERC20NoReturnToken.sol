// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract ERC20NoReturnToken is ERC20 {
    constructor() ERC20('ERC20NoReturnToken', 'ERC20NR') {}

    function transfer(address to, uint256 amount) public override returns (bool) {
        super.transfer(to, amount);
        assembly {
            return(0, 0)
        }
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        super.transferFrom(from, to, amount);
        assembly {
            return(0, 0)
        }
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        super.approve(spender, amount);
        assembly {
            return(0, 0)
        }
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
