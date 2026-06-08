// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../../src/vaults/Subvault.sol";
import "../../src/vaults/Vault.sol";

import "../../src/utils/AaveMigrator.sol";
import "../common/interfaces/IAavePoolV3.sol";

import "./Constants.sol";

contract Deploy is Script, Test {
    address curator = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;

    address collateral = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address debt = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;

    address usdt = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    address usde = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address susde = 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2;

    address aaveV3Pool = 0x925a2A7214Ed92428B5b1B090F80b25700095e12;

    address sourceSubvault = 0xbbF9400C09B0F649F3156989F1CCb9c016f943bb;
    address targetSubvault = 0xa11BE438F1961dB47F6660BDAF59b05C0200ADC5;

    function logState(address holder, string memory name) public view {
        console.log("Aave position of %s", name);
        (uint256 totalCollateralBase, uint256 totalDebtBase,,,, uint256 healthFactor) =
            IAavePool(aaveV3Pool).getUserAccountData(holder);
        console.log("collateral - debt = %s, hf %s", totalCollateralBase - totalDebtBase, healthFactor);

        address aCollateral = IAavePool(aaveV3Pool).getReserveAToken(collateral);
        address variableDebt = IAavePool(aaveV3Pool).getReserveVariableDebtToken(debt);

        console.log("%s collateral: %s", IERC20Metadata(collateral).symbol(), IERC20(aCollateral).balanceOf(holder));
        console.log("%s debt: %s", IERC20Metadata(debt).symbol(), IERC20(variableDebt).balanceOf(holder));
    }

    function run() external {
        // step 1: USDe/USDT0 migration
        {
            collateral = usde;
            debt = usdt;

            AaveMigrator migrator = new AaveMigrator(
                curator,
                aaveV3Pool,
                0x33E0b3fc976DC9C516926BA48CfC0A9E10a2aAA5,
                sourceSubvault, // strETH.subvaultAt(0) source
                targetSubvault, // earnUSDe.subvaultAt(0) target
                collateral, // collateral
                debt, // debt
                1.01 ether,
                1.01 ether,
                1e12,
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
                vm.startPrank(address(targetSubvault));
                IAavePoolV3(aaveV3Pool).setUserEMode(2); // ethena category id
                uint256 amount = 5e6 ether;
                deal(collateral, address(targetSubvault), amount);
                IERC20(collateral).approve(aaveV3Pool, amount);
                IAavePoolV3(aaveV3Pool).supply(collateral, amount, address(targetSubvault), 0);

                vm.stopPrank();
            }

            logState(address(migrator.targetSubvault()), "earnUSDe subvault0");
            logState(address(migrator.sourceSubvault()), "strETH subvault0");

            vm.startPrank(curator);

            uint256 g = gasleft();

            console.log();
            console.log("Migration [0] 50% USDT0 debt with USDe as collateral");
            console.log();
            migrator.migrate(0.175 ether, 5e5);

            console.log("Gas used:", g - gasleft());

            logState(address(migrator.targetSubvault()), "earnUSDe subvault0");
            logState(address(migrator.sourceSubvault()), "strETH subvault0");

            vm.stopPrank();
        }

        console.log();
        console.log("------ collateral switch ------");
        console.log();

        // step 2: sUSDe/USDT0 migration
        {
            collateral = susde;
            debt = usdt;

            AaveMigrator migrator = new AaveMigrator(
                curator,
                aaveV3Pool,
                0x33E0b3fc976DC9C516926BA48CfC0A9E10a2aAA5,
                sourceSubvault, // strETH.subvaultAt(0) source
                targetSubvault, // earnUSDe.subvaultAt(0) target
                collateral, // collateral
                debt, // debt
                1.01 ether,
                1.01 ether,
                1e12,
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

            logState(address(migrator.targetSubvault()), "earnUSDe subvault0");
            logState(address(migrator.sourceSubvault()), "strETH subvault0");

            vm.startPrank(curator);

            uint256 g = gasleft();

            console.log();
            console.log("Migration [1] 25% USDT0 debt with sUSDe as collateral");
            console.log();
            migrator.migrate(0.175 ether, 5e5);
            console.log();

            logState(address(migrator.targetSubvault()), "earnUSDe subvault0");
            logState(address(migrator.sourceSubvault()), "strETH subvault0");

            console.log();
            console.log("Migration [2] 25% USDT0 debt with sUSDe as collateral");
            console.log();
            migrator.migrate(0.175 ether, 1e6);

            console.log("Gas used:", g - gasleft());

            logState(address(migrator.targetSubvault()), "earnUSDe subvault0");
            logState(address(migrator.sourceSubvault()), "strETH subvault0");

            vm.stopPrank();
        }
    }
}
