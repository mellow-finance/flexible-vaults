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
    address public immutable USDT0 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    address public immutable USDe = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address public immutable sUSDe = 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2;
    address public immutable syrupUSDT = 0xC4374775489CB9C56003BF2C9b12495fC64F0771;

    address public immutable aavePool = 0x925a2A7214Ed92428B5b1B090F80b25700095e12;

    AaveMigrator public immutable migrator_USDe_USDT0 = AaveMigrator(0x00000000B984aFe3a14618768662829a78928bbe);
    AaveMigrator public immutable migrator_sUSDe_USDT0 = AaveMigrator(0x00000000e8887A95a9bE39de46143c8E58794bE4);
    AaveMigrator public immutable migrator_syrupUSDT_USDT0 = AaveMigrator(0x00000000C7Bf3227130841e959FD73EEDDB16537);

    address public immutable mellowLazyAdmin = 0xAbE20D266Ae54b9Ae30492dEa6B6407bF18fEeb5;
    address public immutable lidoLazyAdmin = 0x0Dd73341d6158a72b4D224541f1094188f57076E;

    function logState(address holder, address collateral0, address collateral1, address debt, string memory name)
        public
        view
    {
        console.log("Aave position of %s", name);
        (uint256 totalCollateralBase, uint256 totalDebtBase,,,, uint256 healthFactor) =
            IAavePool(aavePool).getUserAccountData(holder);
        if (healthFactor > 1e20) {
            console.log("collateral - debt = %s, hf +inf", totalCollateralBase - totalDebtBase);
        } else {
            console.log("collateral - debt = %s, hf %s", totalCollateralBase - totalDebtBase, healthFactor);
        }

        address aCollateral0 = IAavePool(aavePool).getReserveAToken(collateral0);
        console.log(
            "%s collateral 0: %s", IERC20Metadata(aCollateral0).symbol(), IERC20(aCollateral0).balanceOf(holder)
        );

        if (collateral1 != address(0)) {
            address aCollateral1 = IAavePool(aavePool).getReserveAToken(collateral1);
            console.log(
                "%s collateral 1: %s", IERC20Metadata(aCollateral1).symbol(), IERC20(aCollateral1).balanceOf(holder)
            );
        }

        address variableDebt = IAavePool(aavePool).getReserveVariableDebtToken(debt);
        console.log("%s debt: %s", IERC20Metadata(debt).symbol(), IERC20(variableDebt).balanceOf(holder));
        console.log();
        console.log();
    }

    function _grantRequiredPermissions(AaveMigrator migrator) internal {
        // source subvault permissions
        vm.startPrank(mellowLazyAdmin);
        {
            ICallModule subvault = migrator.sourceSubvault();
            IVerifier verifier = subvault.verifier();

            IVerifier.CompactCall[] memory calls = new IVerifier.CompactCall[](3);
            calls[0] = IVerifier.CompactCall({
                who: address(migrator),
                where: address(migrator.debt()),
                selector: IERC20.approve.selector
            });
            calls[1] = IVerifier.CompactCall({
                who: address(migrator),
                where: address(migrator.pool()),
                selector: IAavePoolV3.repay.selector
            });
            calls[2] = IVerifier.CompactCall({
                who: address(migrator),
                where: address(migrator.pool()),
                selector: IAavePoolV3.withdraw.selector
            });

            IAccessControl(verifier.vault()).grantRole(Permissions.ALLOW_CALL_ROLE, mellowLazyAdmin);
            IAccessControl(verifier.vault()).grantRole(Permissions.CALLER_ROLE, address(migrator));
            verifier.allowCalls(calls);
        }
        vm.stopPrank();

        // target subvault permissions
        vm.startPrank(lidoLazyAdmin);
        {
            ICallModule subvault = migrator.targetSubvault();
            IVerifier verifier = subvault.verifier();

            IVerifier.CompactCall[] memory calls = new IVerifier.CompactCall[](4);
            calls[0] = IVerifier.CompactCall({
                who: address(migrator),
                where: address(migrator.debt()),
                selector: IERC20.transfer.selector
            });
            calls[1] = IVerifier.CompactCall({
                who: address(migrator),
                where: address(migrator.collateral()),
                selector: IERC20.approve.selector
            });
            calls[2] = IVerifier.CompactCall({
                who: address(migrator),
                where: address(migrator.pool()),
                selector: IAavePoolV3.borrow.selector
            });
            calls[3] = IVerifier.CompactCall({
                who: address(migrator),
                where: address(migrator.pool()),
                selector: IAavePoolV3.supply.selector
            });
            IAccessControl(verifier.vault()).grantRole(Permissions.ALLOW_CALL_ROLE, lidoLazyAdmin);
            IAccessControl(verifier.vault()).grantRole(Permissions.CALLER_ROLE, address(migrator));
            verifier.allowCalls(calls);
        }
        vm.stopPrank();
    }

    function run() external {
        console.log("migration for subvault 0");

        // subvault0 migration
        {
            address sourceSubvault0 = address(migrator_USDe_USDT0.sourceSubvault());
            address targetSubvault0 = address(migrator_USDe_USDT0.targetSubvault());

            console.log("------------------------------------------");
            console.log("before migration");
            logState(sourceSubvault0, USDe, sUSDe, USDT0, "strETH subvault0");
            logState(targetSubvault0, USDe, sUSDe, USDT0, "earnUSDe subvault0");
            console.log("------------------------------------------");

            // step 0: USDe 4.5m supply on Aave plasma subvault0
            {
                uint256 amount = 4.5e6 ether;
                vm.startPrank(targetSubvault0);

                deal(USDe, targetSubvault0, amount);
                IERC20(USDe).approve(aavePool, amount);
                IAavePoolV3(aavePool).setUserEMode(2);
                IAavePoolV3(aavePool).supply(USDe, amount, targetSubvault0, 0);
                vm.stopPrank();
            }

            console.log("------------------------------------------");
            console.log("after initial supply");
            logState(sourceSubvault0, USDe, sUSDe, USDT0, "strETH subvault0");
            logState(targetSubvault0, USDe, sUSDe, USDT0, "earnUSDe subvault0");
            console.log("------------------------------------------");

            // step 1: sUSDe/USDT0 migration
            {
                _grantRequiredPermissions(migrator_sUSDe_USDT0);
                vm.startPrank(migrator_sUSDe_USDT0.owner());
                migrator_sUSDe_USDT0.migrate(0.4 ether, 613155);
                vm.stopPrank();
            }

            // step 2: USDe/USDT0 migration
            {
                _grantRequiredPermissions(migrator_USDe_USDT0);
                vm.startPrank(migrator_USDe_USDT0.owner());
                migrator_USDe_USDT0.migrate(0.2 ether, 0.5e6);
                migrator_USDe_USDT0.migrate(0.22 ether, 1e6);
                vm.stopPrank();
            }

            console.log("------------------------------------------");
            console.log("after migration:");
            logState(sourceSubvault0, USDe, sUSDe, USDT0, "strETH subvault0");
            logState(targetSubvault0, USDe, sUSDe, USDT0, "earnUSDe subvault0");
            console.log("------------------------------------------");
        }

        console.log("migration for subvault 1");

        // subvault1 migration
        {
            address sourceSubvault1 = address(migrator_syrupUSDT_USDT0.sourceSubvault());
            address targetSubvault1 = address(migrator_syrupUSDT_USDT0.targetSubvault());

            console.log("------------------------------------------");
            console.log("before migration");
            logState(sourceSubvault1, syrupUSDT, address(0), USDT0, "strETH subvault1");
            logState(targetSubvault1, syrupUSDT, address(0), USDT0, "earnUSDe subvault1");
            console.log("------------------------------------------");

            // step 0: syrupUSDT 5m supply on Aave plasma subvault1
            {
                uint256 amount = 5e12;
                vm.startPrank(targetSubvault1);

                deal(syrupUSDT, targetSubvault1, amount);
                IERC20(syrupUSDT).approve(aavePool, amount);
                IAavePoolV3(aavePool).setUserEMode(11);
                IAavePoolV3(aavePool).supply(syrupUSDT, amount, targetSubvault1, 0);
                vm.stopPrank();
            }

            console.log("------------------------------------------");
            console.log("after initial supply");
            logState(sourceSubvault1, syrupUSDT, address(0), USDT0, "strETH subvault1");
            logState(targetSubvault1, syrupUSDT, address(0), USDT0, "earnUSDe subvault1");
            console.log("------------------------------------------");

            // step 1: sUSDe/USDT0 migration
            {
                _grantRequiredPermissions(migrator_syrupUSDT_USDT0);
                vm.startPrank(migrator_syrupUSDT_USDT0.owner());
                migrator_syrupUSDT_USDT0.migrate(0.4 ether, 0.66e6);
                migrator_syrupUSDT_USDT0.migrate(0.26 ether, 1e6);
                vm.stopPrank();
            }

            console.log("------------------------------------------");
            console.log("after migration:");
            logState(sourceSubvault1, syrupUSDT, address(0), USDT0, "strETH subvault1");
            logState(targetSubvault1, syrupUSDT, address(0), USDT0, "earnUSDe subvault1");
            console.log("------------------------------------------");
        }
    }
}
