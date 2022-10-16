// SPDX-License-Identifier: UNLICENSED
// import "submodules/vesta-protocol-v1/contracts/TroveManager.sol"
pragma solidity ^0.8.0;

// import "@vesta-protocol/contracts/TroveManager.sol";
// import "forge-std/Vm.sol";
import "./interfaces/vesta/ISortedTroves.sol";
import "./interfaces/vesta/ITroveManager.sol";
import "./interfaces/vesta/IPriceFeed.sol";
import "./interfaces/vesta/IVestaParameters.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "forge-std/Test.sol";


contract MockPriceFeed is IPriceFeed{

    mapping(address => uint) prices;


	// --- Function ---
	function addOracle(
		address _token,
		address _chainlinkOracle,
		address _chainlinkIndexOracle
	) external{

    }

    function setPrice(address token, uint price) public {
        prices[ token ] = price;

    }

	function fetchPrice(address token ) external returns (uint256){
        return prices[token];

    }

}


contract Liquidator is Test {
    ISortedTroves sortedTroves = ISortedTroves(0x62842ceDFe0F7D203FC4cFD086a6649412d904B5);
    ITroveManager troveManager = ITroveManager(0x100EC08129e0FD59959df93a8b914944A3BbD5df);
    address gOHM_address = 0x8D9bA570D6cb60C7e3e0F31343Efe75AB8E65FB1;
    address VST_address = 0x64343594Ab9b56e99087BfA6F2335Db24c2d1F17;
    IStabilityPool gOHM_sp = IStabilityPool(0x6e53D20d674C27b858a005Cf4A72CFAaf4434ECB);
    MockPriceFeed mockPriceFeed;

    IERC20 gOHM = IERC20(gOHM_address);
    IERC20 VST = IERC20(VST_address);

    function setUp() public {

        address vestaParamsAddress = address(troveManager.vestaParams());


        mockPriceFeed = new MockPriceFeed();

        OwnableUpgradeable vestaParams = OwnableUpgradeable(vestaParamsAddress);
        console.log(vestaParams.owner());
        console.log("old price", IVestaParameters(vestaParamsAddress).priceFeed().fetchPrice(gOHM_address));
        vm.prank(0x4A4651B31d747D1DdbDDADCF1b1E24a5f6dcc7b0);
        IVestaParameters(vestaParamsAddress).setPriceFeed(address(mockPriceFeed));

        console.log("new price", IVestaParameters(vestaParamsAddress).priceFeed().fetchPrice(gOHM_address));

    }


    function addAllToStabilityPool(address pool) public {
        IStabilityPool(pool).provideToSP(VST.balanceOf(address(this)));
    }

    function withdrawAllFromStabilityPool(address pool) public {
        try IStabilityPool(pool).withdrawFromSP(IStabilityPool(pool).getAssetBalance()) {

        } catch {

        }
    }
    function addToStabilityPool(uint amount) public {
        gOHM_sp.provideToSP(amount);
    }
    



    function testAddToSP() public {
        deal(VST_address, address(this), 1e21);
        addToStabilityPool(1e21);
    }
    

    function testLiquidateFirst() public {
        address trove = sortedTroves.getFirst(gOHM_address);

        deal(VST_address, address(this), 1e21);
        addAllToStabilityPool(address(gOHM_sp));
        console.log("vst bal: ", VST.balanceOf(address(this)));
        console.log("gOHM bal: ", gOHM.balanceOf(address(this)));
        console.log("VST deposit: ", gOHM_sp.getCompoundedVSTDeposit(address(this)));

        console.log("Starting liquididation");
        troveManager.liquidate(gOHM_address, trove);
        console.log("Finished liquididation");
        console.log(gOHM_sp.getCompoundedVSTDeposit(address(this)));


        console.log("vst bal: ", VST.balanceOf(address(this)));
        console.log("gOHM bal: ", gOHM.balanceOf(address(this)));


        console.log("Attempting withdraw");
        withdrawAllFromStabilityPool(address(gOHM_sp));
        console.log("vst bal: ", VST.balanceOf(address(this)));
        console.log("gOHM bal: ", gOHM.balanceOf(address(this)));

        // reset price
        console.log("Resetting price and withdrawing");
        mockPriceFeed.setPrice(address(gOHM), 2640805551785200000000);
        withdrawAllFromStabilityPool(address(gOHM_sp));
        console.log("vst bal: ", VST.balanceOf(address(this)));
        console.log("gOHM bal: ", gOHM.balanceOf(address(this)));

        // troveManager.getCurrentICR(gOHM_address, trove, 0);

    }

}
