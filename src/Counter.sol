// SPDX-License-Identifier: UNLICENSED
// import "submodules/vesta-protocol-v1/contracts/TroveManager.sol"
pragma solidity ^0.8.0;

// import "@vesta-protocol/contracts/TroveManager.sol";
// import "forge-std/Vm.sol";
import "./interfaces/vesta/ISortedTroves.sol";
import "./interfaces/vesta/ITroveManager.sol";

contract Counter {
    ISortedTroves sortedTroves = ISortedTroves(0x62842ceDFe0F7D203FC4cFD086a6649412d904B5);
    ISortedTroves troveManager = ITroveManager(0x100EC08129e0FD59959df93a8b914944A3BbD5df);
    address gOHM_address = 0x8d9ba570d6cb60c7e3e0f31343efe75ab8e65fb1;
    

    function testFind() public {
        sortedTroves.getFirst(gOHM_address);

    }


    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
