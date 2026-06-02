// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../../src/vaults/Subvault.sol";
import "../../src/vaults/Vault.sol";

import "../../src/utils/AaveMigrator.sol";

import "./Constants.sol";

contract Deploy is Script, Test {
    address curator = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;

    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address aaveV3Pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    Vault strETH = Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5));

    function logState(address holder, string memory name) public view {
        console.log("Aave position of %s", name);
        (uint256 totalCollateralBase, uint256 totalDebtBase,,,, uint256 healthFactor) =
            IAavePool(aaveV3Pool).getUserAccountData(holder);
        console.log("collateral - debt = %s, hf %s", totalCollateralBase - totalDebtBase, healthFactor);

        address aWstETH = IAavePool(aaveV3Pool).getReserveAToken(wsteth);

        address aWETHDebt = IAavePool(aaveV3Pool).getReserveVariableDebtToken(weth);
        console.log("wsteth collateral: %s", IERC20(aWstETH).balanceOf(holder));
        console.log("weth debt: %s", IERC20(aWETHDebt).balanceOf(holder));
    }

    function run() external {
        AaveMigrator migrator = new AaveMigrator(
            curator,
            Constants.AAVE_CORE,
            Constants.AAVE_V3_ORACLE,
            strETH.subvaultAt(1), // source
            strETH.subvaultAt(0), // target
            Constants.WSTETH, // collateral
            Constants.WETH, // debt
            1.01 ether,
            1.01 ether,
            0.01 ether,
            1e6 // 0.01$
        );

        {
            // grant required permissions in strETH verifier
            vm.mockCall(
                address(IVerifierModule(migrator.sourceSubvault()).verifier()),
                abi.encodePacked(IVerifier.verifyCall.selector),
                abi.encode()
            );
            vm.mockCall(
                address(IVerifierModule(migrator.targetSubvault()).verifier()),
                abi.encodePacked(IVerifier.verifyCall.selector),
                abi.encode()
            );
        }

        {
            ICallModule targetSubvault = ICallModule(strETH.subvaultAt(0));
            vm.startPrank(address(targetSubvault));
            IAavePoolV3(Constants.AAVE_CORE).setUserEMode(1);
            uint256 amount = 10000 ether;
            deal(wsteth, address(targetSubvault), amount);
            IERC20(wsteth).approve(Constants.AAVE_CORE, amount);
            IAavePoolV3(Constants.AAVE_CORE).supply(wsteth, amount, address(targetSubvault), 0);

            vm.stopPrank();
        }

        logState(address(migrator.targetSubvault()), "strETH subvault0");
        logState(address(migrator.sourceSubvault()), "strETH subvault1");

        vm.startPrank(curator);

        uint256 g = gasleft();

        migrator.migrate(0.175 ether, 1e5);

        migrator.migrate(0.175 ether, 1e5);

        migrator.migrate(0.175 ether, 3e5);

        migrator.migrate(0.175 ether, 1e6);

        console.log("Gas used:", g - gasleft());

        logState(address(migrator.sourceSubvault()), "strETH subvault1");
        logState(address(migrator.targetSubvault()), "strETH subvault0");

        vm.stopPrank();
    }
}
