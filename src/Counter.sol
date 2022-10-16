// SPDX-License-Identifier: UNLICENSED
// import "submodules/vesta-protocol-v1/contracts/TroveManager.sol"
pragma solidity ^0.8.0;

// import "@vesta-protocol/contracts/TroveManager.sol";
// import "forge-std/Vm.sol";
import "../submodules/vesta-protocol-v1/contracts/TroveManager.sol";

contract Counter {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
