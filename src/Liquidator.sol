// SPDX-License-Identifier: UNLICENSED
// import "submodules/vesta-protocol-v1/contracts/TroveManager.sol"
pragma solidity ^0.8.0;

// import "@vesta-protocol/contracts/TroveManager.sol";
// import "forge-std/Vm.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IFlashLoanRecipient.sol";
import "./interfaces/IUniswapV2Pair.sol";

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


contract Liquidator is Test, IFlashLoanRecipient  {
    ISortedTroves sortedTroves = ISortedTroves(0x62842ceDFe0F7D203FC4cFD086a6649412d904B5);
    ITroveManager troveManager = ITroveManager(0x100EC08129e0FD59959df93a8b914944A3BbD5df);
    address gOHM_address = 0x8D9bA570D6cb60C7e3e0F31343Efe75AB8E65FB1;
    address VST_address = 0x64343594Ab9b56e99087BfA6F2335Db24c2d1F17;

    IStabilityPool gOHM_sp = IStabilityPool(0x6e53D20d674C27b858a005Cf4A72CFAaf4434ECB);
    MockPriceFeed mockPriceFeed;

    IVault balancerVault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);



    IERC20 gOHM = IERC20(gOHM_address);
    IERC20 VST = IERC20(VST_address);
    IERC20 WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    IUniswapV2Pair sushi_gOHM_WETH = IUniswapV2Pair(0xaa5bD49f2162ffdC15634c87A77AC67bD51C6a6D);

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


 





    
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {

        liquidateFirst_gOHM();

        VST.transfer(address(balancerVault), amounts[0]);

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


    function swapAllSushi() public {
        uint kLast = sushi_gOHM_WETH.kLast();
        (uint reserve0, uint reserve1, ) = sushi_gOHM_WETH.getReserves();
        uint ourbalance = gOHM.balanceOf(address(this));
        uint inAmount_adj = (ourbalance*996)/(1000);
        uint outAmount = reserve0 - kLast/(reserve1 + inAmount_adj);
        gOHM.transfer(address(sushi_gOHM_WETH), ourbalance);
        sushi_gOHM_WETH.swap(outAmount, 0, address(this), hex"");

    }

    function testSwapgW() public {
        deal(address(gOHM), address(this), 3e18);
        swapAllSushi();
    }


    function test_swap_WETH_VST_balancer() public {
        deal(address(WETH), address(this), 1e18);
        WETH.approve(address(balancerVault), 1e18);

        console.log("weth: ", WETH.balanceOf(address(this)));
        console.log("vst: ", VST.balanceOf(address(this)));
        swap_WETH_VST_balancer(); 
        console.log("weth: ", WETH.balanceOf(address(this)));
        console.log("vst: ", VST.balanceOf(address(this)));

    }

    function swap_WETH_VST_balancer() public {
        uint weth_balance = WETH.balanceOf(address(this));
        IVault.BatchSwapStep[] memory steps = new IVault.BatchSwapStep[](2);
        steps[0] =  IVault.BatchSwapStep(0x64541216bafffeec8ea535bb71fbc927831d0595000100000000000000000002,
            0,
            1,
            weth_balance,
            hex""
            )
         ;

        steps[1] = IVault.BatchSwapStep(0x5a5884fc31948d59df2aeccca143de900d49e1a300000000000000000000006f,
            1,
            2,
            0,
            hex""
            )
         ;


        IVault.FundManagement memory fmgt = IVault.FundManagement(address(this),
        false,
        payable(address(this)),
        false);

        address[] memory assets = new address[](3);
        assets[0] = address(WETH);
        assets[1] = address(USDC);
        assets[2] = address(VST);

        int[] memory limits = new int[](3);
        
        limits[0] = int(weth_balance);
        limits[1] = 0;
        limits[2] = 0;


        balancerVault.batchSwap(
            IVault.SwapKind.GIVEN_IN,
            steps,
            assets,
            fmgt,
            limits,
            block.timestamp + 600
        );

    }


    function liquidateFirst_gOHM() public { 
        deal(VST_address, address(this), 1e21);

        addAllToStabilityPool(address(gOHM_sp));

        troveManager.liquidateTroves(address(gOHM), 1);


        withdrawAllFromStabilityPool(address(gOHM_sp));

        mockPriceFeed.setPrice(address(gOHM), 2640805551785200000000);
        withdrawAllFromStabilityPool(address(gOHM_sp));
        swapAllSushi();
        WETH.approve(address(balancerVault), WETH.balanceOf(address(this)) );
        swap_WETH_VST_balancer();


    }


    function test_all() public {
    
        address[] memory tokens = new address[](1);
        tokens[0] = address(VST);
        uint[] memory amounts = new uint[](1);
        amounts[0] = VST.balanceOf(address(balancerVault));


        balancerVault.flashLoan(address(this),
        tokens,
        amounts,
        hex""
        );

        // console.log("VST net bal: ", VST.balanceOf(address(this)) - 1e21);

        
    }


    // function testLiquidateFirst() public {
    //     address trove = sortedTroves.getFirst(gOHM_address);

    //     deal(VST_address, address(this), 1e21);
    //     addAllToStabilityPool(address(gOHM_sp));
    //     console.log("vst bal: ", VST.balanceOf(address(this)));
    //     console.log("gOHM bal: ", gOHM.balanceOf(address(this)));
    //     console.log("VST deposit: ", gOHM_sp.getCompoundedVSTDeposit(address(this)));

    //     console.log("Starting liquididation");
    //     troveManager.liquidateTroves(address(gOHM), 1);
    //     console.log("Finished liquididation");
    //     console.log(gOHM_sp.getCompoundedVSTDeposit(address(this)));


    //     console.log("vst bal: ", VST.balanceOf(address(this)));
    //     console.log("gOHM bal: ", gOHM.balanceOf(address(this)));


    //     console.log("Attempting withdraw");
    //     withdrawAllFromStabilityPool(address(gOHM_sp));
    //     console.log("vst bal: ", VST.balanceOf(address(this)));
    //     console.log("gOHM bal: ", gOHM.balanceOf(address(this)));

    //     // reset price
    //     console.log("Resetting price and withdrawing");
    //     mockPriceFeed.setPrice(address(gOHM), 2640805551785200000000);
    //     withdrawAllFromStabilityPool(address(gOHM_sp));
    //     console.log("vst bal: ", VST.balanceOf(address(this)));
    //     console.log("gOHM bal: ", gOHM.balanceOf(address(this)));



    //     // troveManager.getCurrentICR(gOHM_address, trove, 0);



    //     swapAllSushi();
    //     WETH.approve(address(balancerVault), WETH.balanceOf(address(this)) );
    //     swap_WETH_VST_balancer();

    //     console.log("VST bal: ", VST.balanceOf(address(this)));
    //     console.log("WETH bal: ", WETH.balanceOf(address(this)));
    //     console.log("gOHM bal: ", gOHM.balanceOf(address(this)));

    //     console.log("VST bal: ", VST.balanceOf(address(this)));
    //     console.log("WETH bal: ", WETH.balanceOf(address(this)));
    //     console.log("gOHM bal: ", gOHM.balanceOf(address(this)));

    // }

}
