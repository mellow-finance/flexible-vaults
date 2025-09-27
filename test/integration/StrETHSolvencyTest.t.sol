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
    }

    function testSolvencyStrETH() external {
        VaultDeployment memory d = Constants.getStrETHDeployment();

        // Phase 1
        for (uint256 iteration = 0; iteration < 100; iteration++) {
            uint256 actionId = rnd.randInt(4);
            if (actionId == 0) {
                StrETHSolvencyLibrary.createDepositRequest(rnd, $, d);
            } else if (actionId == 1) {
                StrETHSolvencyLibrary.createRedeemRequest(rnd, $, d);
            } else if (actionId == 2) {
                StrETHSolvencyLibrary.swapWETH(rnd, $, d, 0, rnd.randAmountD18());
            } else if (actionId == 3) {
                StrETHSolvencyLibrary.handleWithdrawals(rnd, $, d);
            } else {
                StrETHSolvencyLibrary.submitReports(rnd, $, d);
            }

            StrETHSolvencyLibrary.checkState(rnd, $, d);
        }

        // Phase 2
        for (uint256 iteration = 0; iteration < 1000; iteration++) {
            uint256 actionId = rnd.randInt(6);
            if (actionId == 0) {
                StrETHSolvencyLibrary.createDepositRequest(rnd, $, d);
            } else if (actionId == 1) {
                StrETHSolvencyLibrary.createRedeemRequest(rnd, $, d);
            } else if (actionId == 2) {
                StrETHSolvencyLibrary.swapWETH(rnd, $, d, 0, rnd.randAmountD18());
            } else if (actionId == 3) {
                StrETHSolvencyLibrary.handleWithdrawals(rnd, $, d);
            } else if (actionId == 4) {
                StrETHSolvencyLibrary.submitReports(rnd, $, d);
            } else if (actionId == 5) {
                StrETHSolvencyLibrary.aaveIncreaseLeverage(rnd, $, d);
            } else if (actionId == 6) {
                StrETHSolvencyLibrary.aaveDecreaseLeverage(rnd, $, d);
            }
            StrETHSolvencyLibrary.checkState(rnd, $, d);
        }

        // Phase 3
        for (uint256 iteration = 0; iteration < 100; iteration++) {
            uint256 actionId = rnd.randInt(4);
            if (actionId == 0) {
                StrETHSolvencyLibrary.createRedeemRequest(rnd, $, d);
            } else if (actionId == 1) {
                StrETHSolvencyLibrary.swapWETH(rnd, $, d, 0, rnd.randAmountD18());
            } else if (actionId == 2) {
                StrETHSolvencyLibrary.handleWithdrawals(rnd, $, d);
            } else if (actionId == 3) {
                StrETHSolvencyLibrary.submitReports(rnd, $, d);
            } else if (actionId == 4) {
                StrETHSolvencyLibrary.aaveDecreaseLeverage(rnd, $, d);
            }

            StrETHSolvencyLibrary.checkState(rnd, $, d);
        }

        StrETHSolvencyLibrary.finalize(rnd, $, d);
        StrETHSolvencyLibrary.checkState(rnd, $, d);
        StrETHSolvencyLibrary.checkFinalState(rnd, $, d);
    }
}
