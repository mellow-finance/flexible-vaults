// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

import "../../scripts/ethereum/Constants.sol";
import "../../scripts/ethereum/StrETHSolvencyLibrary.sol";

contract StrETHSolvencyTest is Test {
    using RandomLib for RandomLib.Storage;

    RandomLib.Storage rnd;
    StrETHSolvencyLibrary.State $;

    function setUp() external {
        // logic below is used to prevent STAKE_LIMIT error in stETH contract
        bytes32 slot_ = 0xa3678de4a579be090bed1177e0a24f77cc29d181ac22fd7688aca344d8938015;
        bytes32 value = vm.load(Constants.STETH, slot_);
        bytes32 new_value = bytes32(uint256(value) & type(uint160).max); // nullify maxStakeLimit
        vm.store(Constants.STETH, slot_, new_value);

        $.users.push(0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3);
        $.users.push(0x4d551d74e851Bd93Ce44D5F588Ba14623249CDda);
        $.users.push(0xE4a0F0F3284A3665245e4Cd9aB01Aef70Ab10E06);
        $.users.push(0x89A2Ac2FD3ae466021dbC770F98AE42f97a8D706);
        $.users.push(0x9EB0cb7841e55D3d9cAf49df9C61d5d857D17C82);
        $.users.push(0xb1E5a8F26C43d019f2883378548a350ecdD1423B);
        $.users.push(0xceDC35457010Be27048C943d556c964f63867D64);

        VaultDeployment memory d = Constants.getStrETHDeployment();

        $.timestamp = block.timestamp;
        IShareManager shareManager = d.vault.shareManager();
        $.totalShares = shareManager.totalShares();
        $.totalAssets = FEOracle(Constants.FE_ORACLE).tvl(address(d.vault));

        for (uint256 i = 0; i < $.users.length; i++) {
            $.shares.push(shareManager.sharesOf($.users[i]));
            $.pendingDeposits.push(StrETHSolvencyLibrary.pendingDepositsOf(d, $.users[i]));
            $.pendingWithdrawals.push(StrETHSolvencyLibrary.pendingWithdrawalsOf(d, $.users[i]));
        }

        $.latestTransition.t = StrETHSolvencyLibrary.Transitions.NONE;
    }

    function testSolvencyStrETH() external {
        VaultDeployment memory d = Constants.getStrETHDeployment();

        rnd.seed = 123;

        address vaultAdmin = StrETHSolvencyLibrary.findRoleHolder(d, Permissions.DEFAULT_ADMIN_ROLE);

        {
            vm.startPrank(vaultAdmin);
            d.vault.grantRole(Permissions.SET_SECURITY_PARAMS_ROLE, vaultAdmin);
            d.vault.oracle().setSecurityParams(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.1 ether,
                    suspiciousAbsoluteDeviation: 0.1 ether,
                    maxRelativeDeviationD18: 0.1 ether,
                    suspiciousRelativeDeviationD18: 0.1 ether,
                    timeout: 20 hours,
                    depositInterval: 1 hours,
                    redeemInterval: 2 days
                })
            );
            vm.stopPrank();
        }

        for (uint256 iteration = 0; iteration < 1000; iteration++) {
            uint256 actionId = rnd.randInt(5);
            if (actionId == 0) {
                // console2.log("create deposit");
                StrETHSolvencyLibrary.createDepositRequest(rnd, $, d);
            } else if (actionId == 1) {
                // console2.log("cancel deposit");
                StrETHSolvencyLibrary.cancelDepositRequest(rnd, $, d);
            } else if (actionId == 2) {
                // console2.log("create redeem");
                StrETHSolvencyLibrary.createRedeemRequest(rnd, $, d);
            } else if (actionId == 3) {
                // console2.log("submit and handle batches");
                StrETHSolvencyLibrary.submitReports(rnd, $, d);
            } else if (actionId == 4) {
                // console2.log("increase");
                StrETHSolvencyLibrary.aaveIncreaseLeverage(rnd, $, d);
            } else if (actionId == 5) {
                // console2.log("decrease");
                StrETHSolvencyLibrary.aaveDecreaseLeverage(rnd, $, d);
            }
            require(StrETHSolvencyLibrary.tvl(d.vault) >= d.vault.shareManager().totalShares());
            // console2.log("tvl/shares:", StrETHSolvencyLibrary.tvl(d.vault), d.vault.shareManager().totalShares());
            StrETHSolvencyLibrary.checkState($, d);
        }

        StrETHSolvencyLibrary.finalize(rnd, $, d);
        StrETHSolvencyLibrary.checkState($, d);
    }
}
