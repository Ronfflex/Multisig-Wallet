// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RevertingContract {
    receive() external payable {
        revert("I always revert");
    }
}
