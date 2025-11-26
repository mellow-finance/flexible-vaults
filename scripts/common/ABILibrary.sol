// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IAavePoolV3} from "./interfaces/IAavePoolV3.sol";
import {ICowswapSettlement} from "./interfaces/ICowswapSettlement.sol";
import {IWETH} from "./interfaces/IWETH.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICurveGauge} from "./interfaces/ICurveGauge.sol";
import {ICurvePool} from "./interfaces/ICurvePool.sol";

import {IL1GatewayRouter} from "./interfaces/IL1GatewayRouter.sol";
import {IL2GatewayRouter} from "./interfaces/IL2GatewayRouter.sol";

import {ICCIPRouterClient} from "./interfaces/ICCIPRouterClient.sol";

import {IBracketVaultV2} from "./interfaces/IBracketVaultV2.sol";

import {IMorpho} from "./interfaces/IMorpho.sol";

import {IGearingToken} from "./interfaces/IGearingToken.sol";
import {IMorphoStrategyWrapper} from "./interfaces/IMorphoStrategyWrapper.sol";
import {ISubRedManagement} from "./interfaces/ISubRedManagement.sol";
import {ITermMaxRouter} from "./interfaces/ITermMaxRouter.sol";

import {IDepositQueue} from "../../src/interfaces/queues/IDepositQueue.sol";
import {IRedeemQueue} from "../../src/interfaces/queues/IRedeemQueue.sol";

import {ISymbioticVault} from "../../src/interfaces/external/symbiotic/ISymbioticVault.sol";
import {ICapLender} from "./interfaces/ICapLender.sol";

import {IStUSR} from "./interfaces/IStUSR.sol";
import {IUsrExternalRequestsManager} from "./interfaces/IUsrExternalRequestsManager.sol";

import {IStakeWiseEthVault} from "./interfaces/IStakeWiseEthVault.sol";

import {ISwapModule} from "../../src/interfaces/utils/ISwapModule.sol";

library ABILibrary {
    function getABI(bytes4 selector) internal pure returns (string memory) {
        function() pure returns (bytes4[] memory, string[] memory)[20] memory functions = [
            getERC20Interfaces,
            getERC4626Interfaces,
            getAaveInterfaces,
            getWETHInterfaces,
            getCowSwapInterfaces,
            getCurveInterfaces,
            getBracketFinanceInterfaces,
            getL1GatewayRouter,
            getL2GatewayRouter,
            getCCIPRouter,
            getCoreVaultInterfaces,
            getTermMaxInterfaces,
            getDigiFTInterfaces,
            getMorphoInterfaces,
            getMorphoStrategyWrapperInterfaces,
            getCapLenderInterfaces,
            getSymbioticInterfaces,
            getResolvInterfaces,
            getStakeWiseInterfaces,
            getSwapModuleInterfaces
        ];
        for (uint256 i = 0; i < functions.length; i++) {
            (bytes4[] memory selectors, string[] memory abis) = functions[i]();
            for (uint256 j = 0; j < selectors.length; j++) {
                if (selectors[j] == selector) {
                    return abis[j];
                }
            }
        }
        revert("ABILibrary: selector not found");
    }

    function getERC20Interfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](2);
        abis = new string[](2);

        selectors[0] = IERC20.approve.selector;
        selectors[1] = IERC20.transfer.selector;

        abis[0] =
            '{"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}'; //
        abis[1] =
            '{"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}';
    }

    function getCurveInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](5);
        abis = new string[](5);

        selectors[0] = ICurvePool.add_liquidity.selector;
        selectors[1] = ICurvePool.remove_liquidity.selector;
        selectors[2] = ICurveGauge.deposit.selector;
        selectors[3] = ICurveGauge.claim_rewards.selector;
        selectors[4] = ICurvePool.exchange.selector;

        abis[0] =
            '{"inputs":[{"name":"_amounts","type":"uint256[]"},{"name":"_min_mint_amount","type":"uint256"}],"name":"add_liquidity","outputs":[{"name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"name":"_burn_amount","type":"uint256"},{"name":"_min_amounts","type":"uint256[]"}],"name":"remove_liquidity","outputs":[{"name":"","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"}';

        abis[2] =
            '{"inputs":[{"name":"_value","type":"uint256"}],"name":"deposit","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[3] = '{"inputs":[],"name":"claim_rewards","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[4] =
            '{"stateMutability":"nonpayable","type":"function","name":"exchange","inputs":[{"name":"i","type":"int128"},{"name":"j","type":"int128"},{"name":"_dx","type":"uint256"},{"name":"_min_dy","type":"uint256"}],"outputs":[{"name":"","type":"uint256"}]}';
    }

    function getERC4626Interfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](4);
        abis = new string[](4);

        selectors[0] = IERC4626.deposit.selector;
        selectors[1] = IERC4626.mint.selector;
        selectors[2] = IERC4626.withdraw.selector;
        selectors[3] = IERC4626.redeem.selector;
        abis[0] =
            '{"inputs":[{"internalType":"uint256","name":"assets","type":"uint256"},{"internalType":"address","name":"receiver","type":"address"}],"name":"deposit","outputs":[{"internalType":"uint256","name":"shares","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"internalType":"uint256","name":"shares","type":"uint256"},{"internalType":"address","name":"receiver","type":"address"}],"name":"mint","outputs":[{"internalType":"uint256","name":"assets","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[2] =
            '{"inputs":[{"internalType":"uint256","name":"assets","type":"uint256"},{"internalType":"address","name":"receiver","type":"address"},{"internalType":"address","name":"owner","type":"address"}],"name":"withdraw","outputs":[{"internalType":"uint256","name":"shares","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[3] =
            '{"inputs":[{"internalType":"uint256","name":"shares","type":"uint256"},{"internalType":"address","name":"receiver","type":"address"},{"internalType":"address","name":"owner","type":"address"}],"name":"redeem","outputs":[{"internalType":"uint256","name":"assets","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
    }

    function getAaveInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](5);
        abis = new string[](5);

        selectors[0] = IAavePoolV3.supply.selector;
        selectors[1] = IAavePoolV3.withdraw.selector;
        selectors[2] = IAavePoolV3.borrow.selector;
        selectors[3] = IAavePoolV3.repay.selector;
        selectors[4] = IAavePoolV3.setUserEMode.selector;

        abis[0] =
            '{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"address","name":"onBehalfOf","type":"address"},{"internalType":"uint16","name":"referralCode","type":"uint16"}],"name":"supply","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"address","name":"to","type":"address"}],"name":"withdraw","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[2] =
            '{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint256","name":"interestRateMode","type":"uint256"},{"internalType":"uint16","name":"referralCode","type":"uint16"},{"internalType":"address","name":"onBehalfOf","type":"address"}],"name":"borrow","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[3] =
            '{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint256","name":"interestRateMode","type":"uint256"},{"internalType":"address","name":"onBehalfOf","type":"address"}],"name":"repay","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[4] =
            '{"inputs":[{"internalType":"uint8","name":"categoryId","type":"uint8"}],"name":"setUserEMode","outputs":[],"stateMutability":"nonpayable","type":"function"}';
    }

    function getWETHInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](2);
        abis = new string[](2);

        selectors[0] = IWETH.deposit.selector;
        selectors[1] = IWETH.withdraw.selector;

        abis[0] =
            '{"constant":false,"inputs":[],"name":"deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"}';
        abis[1] =
            '{"constant":false,"inputs":[{"name":"wad","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}';
    }

    function getCowSwapInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](2);
        abis = new string[](2);

        selectors[0] = ICowswapSettlement.setPreSignature.selector;
        selectors[1] = ICowswapSettlement.invalidateOrder.selector;

        abis[0] =
            '{"inputs":[{"internalType":"bytes","name":"orderUid","type":"bytes"},{"internalType":"bool","name":"signed","type":"bool"}],"name":"setPreSignature","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"internalType":"bytes","name":"orderUid","type":"bytes"}],"name":"invalidateOrder","outputs":[],"stateMutability":"nonpayable","type":"function"}';
    }

    function getL2GatewayRouter() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](1);
        abis = new string[](1);

        selectors[0] = IL2GatewayRouter.outboundTransfer.selector;
        abis[0] =
            '{"inputs":[{"internalType":"address","name":"l1Token","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"bytes","name":"data","type":"bytes"}],"name":"outboundTransfer","outputs":[{"internalType":"bytes","name":"","type":"bytes"}],"stateMutability":"payable","type":"function"}';
    }

    function getL1GatewayRouter() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](1);
        abis = new string[](1);

        selectors[0] = IL1GatewayRouter.outboundTransfer.selector;
        abis[0] =
            '{"inputs":[{"internalType":"address","name":"_token","type":"address"},{"internalType":"address","name":"_to","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"},{"internalType":"uint256","name":"_maxGas","type":"uint256"},{"internalType":"uint256","name":"_gasPriceBid","type":"uint256"},{"internalType":"bytes","name":"_data","type":"bytes"}],"name":"outboundTransfer","outputs":[{"internalType":"bytes","name":"","type":"bytes"}],"stateMutability":"payable","type":"function"}';
    }

    function getCCIPRouter() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](1);
        abis = new string[](1);

        selectors[0] = ICCIPRouterClient.ccipSend.selector;
        abis[0] =
            '{"inputs":[{"internalType":"uint64","name":"destinationChainSelector","type":"uint64"},{"components":[{"internalType":"bytes","name":"receiver","type":"bytes"},{"internalType":"bytes","name":"data","type":"bytes"},{"components":[{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"internalType":"structClient.EVMTokenAmount[]","name":"tokenAmounts","type":"tuple[]"},{"internalType":"address","name":"feeToken","type":"address"},{"internalType":"bytes","name":"extraArgs","type":"bytes"}],"internalType":"structClient.EVM2AnyMessage","name":"message","type":"tuple"}],"name":"ccipSend","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"payable","type":"function"}';
    }

    function getBracketFinanceInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](3);
        abis = new string[](3);

        selectors[0] = IBracketVaultV2.deposit.selector;
        selectors[1] = IBracketVaultV2.withdraw.selector;
        selectors[2] = IBracketVaultV2.claimWithdrawal.selector;

        abis[0] =
            '{"inputs":[{"internalType":"uint256","name":"assets","type":"uint256"},{"internalType":"address","name":"destination","type":"address"}],"name":"deposit","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"internalType":"uint256","name":"assets","type":"uint256"},{"internalType":"bytes32","name":"salt","type":"bytes32"}],"name":"withdraw","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[2] =
            '{"inputs":[{"internalType":"uint256","name":"shares","type":"uint256"},{"internalType":"uint16","name":"claimEpoch","type":"uint16"},{"internalType":"uint256","name":"timestamp","type":"uint256"},{"internalType":"bytes32","name":"salt","type":"bytes32"}],"name":"claimWithdrawal","outputs":[],"stateMutability":"nonpayable","type":"function"}';
    }

    function getCoreVaultInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](3);
        abis = new string[](3);

        selectors[0] = IDepositQueue.deposit.selector;
        selectors[1] = IRedeemQueue.redeem.selector;
        selectors[2] = IRedeemQueue.claim.selector;

        abis[0] =
            '{"inputs":[{"internalType":"uint224","name":"assets","type":"uint224"},{"internalType":"address","name":"referral","type":"address"},{"internalType":"bytes32[]","name":"merkleProof","type":"bytes32[]"}],"name":"deposit","outputs":[],"stateMutability":"payable","type":"function"}';
        abis[1] =
            '{"inputs":[{"internalType":"uint256","name":"shares","type":"uint256"}],"name":"redeem","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[2] =
            '{"inputs":[{"internalType":"address","name":"receiver","type":"address"},{"internalType":"uint32[]","name":"timestamps","type":"uint32[]"}],"name":"claim","outputs":[{"internalType":"uint256","name":"assets","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
    }

    function getTermMaxInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](3);
        abis = new string[](3);

        selectors[0] = ITermMaxRouter.borrowTokenFromCollateral.selector;
        selectors[1] = ITermMaxRouter.repayGt.selector;
        selectors[2] = IGearingToken.merge.selector;

        abis[0] =
            '{"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"address","name":"market","type":"address"},{"internalType":"uint256","name":"collInAmt","type":"uint256"},{"internalType":"address[]","name":"orders","type":"address[]"},{"internalType":"uint128[]","name":"tokenAmtsWantBuy","type":"uint128[]"},{"internalType":"uint128","name":"maxDebtAmt","type":"uint128"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"borrowTokenFromCollateral","outputs":[{"internalType":"uint256","name":"gtId","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"internalType":"address","name":"market","type":"address"},{"internalType":"uint256","name":"gtId","type":"uint256"},{"internalType":"uint128","name":"maxRepayAmt","type":"uint128"},{"internalType":"bool","name":"byDebtToken","type":"bool"}],"name":"repayGt","outputs":[{"internalType":"uint128","name":"repayAmt","type":"uint128"}],"stateMutability":"nonpayable","type":"function"}';
        abis[2] =
            '{"inputs":[{"internalType":"uint256[]","name":"ids","type":"uint256[]"}],"name":"merge","outputs":[{"internalType":"uint256","name":"newId","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
    }

    function getDigiFTInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](2);
        abis = new string[](2);
        selectors[0] = ISubRedManagement.subscribe.selector;
        selectors[1] = ISubRedManagement.redeem.selector;
        abis[0] =
            '{"inputs":[{"internalType":"address","name":"stToken","type":"address"},{"internalType":"address","name":"currencyToken","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint256","name":"_deadline","type":"uint256"}],"name":"subscribe","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"internalType":"uint256","name":"subId","type":"uint256"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"redeem","outputs":[],"stateMutability":"nonpayable","type":"function"}';
    }

    function getMorphoInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](6);
        abis = new string[](6);

        selectors[0] = IMorpho.supply.selector;
        selectors[1] = IMorpho.supplyCollateral.selector;
        selectors[2] = IMorpho.repay.selector;
        selectors[3] = IMorpho.borrow.selector;
        selectors[4] = IMorpho.withdraw.selector;
        selectors[5] = IMorpho.withdrawCollateral.selector;

        abis[0] =
            '{"constant":false,"inputs":[{"components":[{"internalType":"address","name":"loanToken","type":"address"},{"internalType":"address","name":"collateralToken","type":"address"},{"internalType":"address","name":"oracle","type":"address"},{"internalType":"address","name":"irm","type":"address"},{"internalType":"uint256","name":"lltv","type":"uint256"}],"internalType":"struct MarketParams","name":"marketParams","type":"tuple"},{"internalType":"uint256","name":"assets","type":"uint256"},{"internalType":"uint256","name":"shares","type":"uint256"},{"internalType":"address","name":"onBehalf","type":"address"},{"internalType":"bytes","name":"data","type":"bytes"}],"name":"supply","outputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"constant":false,"inputs":[{"components":[{"internalType":"address","name":"loanToken","type":"address"},{"internalType":"address","name":"collateralToken","type":"address"},{"internalType":"address","name":"oracle","type":"address"},{"internalType":"address","name":"irm","type":"address"},{"internalType":"uint256","name":"lltv","type":"uint256"}],"internalType":"struct MarketParams","name":"marketParams","type":"tuple"},{"internalType":"uint256","name":"assets","type":"uint256"},{"internalType":"address","name":"onBehalf","type":"address"},{"internalType":"bytes","name":"data","type":"bytes"}],"name":"supplyCollateral","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}';
        abis[2] =
            '{"constant":false,"inputs":[{"components":[{"internalType":"address","name":"loanToken","type":"address"},{"internalType":"address","name":"collateralToken","type":"address"},{"internalType":"address","name":"oracle","type":"address"},{"internalType":"address","name":"irm","type":"address"},{"internalType":"uint256","name":"lltv","type":"uint256"}],"internalType":"struct MarketParams","name":"marketParams","type":"tuple"},{"internalType":"uint256","name":"assets","type":"uint256"},{"internalType":"uint256","name":"shares","type":"uint256"},{"internalType":"address","name":"onBehalf","type":"address"},{"internalType":"bytes","name":"data","type":"bytes"}],"name":"repay","outputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"nonpayable","type":"function"}';
        abis[3] =
            '{"constant":false,"inputs":[{"components":[{"internalType":"address","name":"loanToken","type":"address"},{"internalType":"address","name":"collateralToken","type":"address"},{"internalType":"address","name":"oracle","type":"address"},{"internalType":"address","name":"irm","type":"address"},{"internalType":"uint256","name":"lltv","type":"uint256"}],"internalType":"struct MarketParams","name":"marketParams","type":"tuple"},{"internalType":"uint256","name":"assets","type":"uint256"},{"internalType":"uint256","name":"shares","type":"uint256"},{"internalType":"address","name":"onBehalf","type":"address"},{"internalType":"address","name":"receiver","type":"address"}],"name":"borrow","outputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"nonpayable","type":"function"}';
        abis[4] =
            '{"constant":false,"inputs":[{"components":[{"internalType":"address","name":"loanToken","type":"address"},{"internalType":"address","name":"collateralToken","type":"address"},{"internalType":"address","name":"oracle","type":"address"},{"internalType":"address","name":"irm","type":"address"},{"internalType":"uint256","name":"lltv","type":"uint256"}],"internalType":"struct MarketParams","name":"marketParams","type":"tuple"},{"internalType":"uint256","name":"assets","type":"uint256"},{"internalType":"uint256","name":"shares","type":"uint256"},{"internalType":"address","name":"onBehalf","type":"address"},{"internalType":"address","name":"receiver","type":"address"}],"name":"withdraw","outputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"nonpayable","type":"function"}';
        abis[5] =
            '{"constant":false,"inputs":[{"components":[{"internalType":"address","name":"loanToken","type":"address"},{"internalType":"address","name":"collateralToken","type":"address"},{"internalType":"address","name":"oracle","type":"address"},{"internalType":"address","name":"irm","type":"address"},{"internalType":"uint256","name":"lltv","type":"uint256"}],"internalType":"struct MarketParams","name":"marketParams","type":"tuple"},{"internalType":"uint256","name":"assets","type":"uint256"},{"internalType":"address","name":"onBehalf","type":"address"},{"internalType":"address","name":"receiver","type":"address"}],"name":"withdrawCollateral","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}';
    }

    function getMorphoStrategyWrapperInterfaces()
        internal
        pure
        returns (bytes4[] memory selectors, string[] memory abis)
    {
        selectors = new bytes4[](4);
        abis = new string[](4);

        selectors[0] = IMorphoStrategyWrapper.depositAssets.selector;
        selectors[1] = IMorphoStrategyWrapper.withdraw.selector;
        selectors[2] = IMorphoStrategyWrapper.claim.selector;
        selectors[3] = IMorphoStrategyWrapper.claimExtraRewards.selector;

        abis[0] =
            '{"constant":false,"inputs":[{"name":"amount","type":"uint256"}],"name":"depositAssets","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"constant":false,"inputs":[{"name":"amount","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}';
        abis[2] =
            '{"constant":false,"inputs":[],"name":"claim","outputs":[{"name":"amount","type":"uint256"}],"payable":false,"stateMutability":"nonpayable","type":"function"}';
        abis[3] =
            '{"constant":false,"inputs":[],"name":"claimExtraRewards","outputs":[{"name":"amounts","type":"uint256[]"}],"payable":false,"stateMutability":"nonpayable","type":"function"}';
    }

    function getCapLenderInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](2);
        abis = new string[](2);

        selectors[0] = ICapLender.repay.selector;
        selectors[1] = ICapLender.borrow.selector;

        abis[0] =
            '{"inputs":[{"internalType":"address","name":"_asset","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"},{"internalType":"address","name":"_agent","type":"address"}],"name":"repay","outputs":[{"internalType":"uint256","name":"repaid","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"internalType":"address","name":"_asset","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"},{"internalType":"address","name":"_receiver","type":"address"}],"name":"borrow","outputs":[{"internalType":"uint256","name":"borrowed","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
    }

    function getSymbioticInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](3);
        abis = new string[](3);

        selectors[0] = ISymbioticVault.deposit.selector;
        selectors[1] = ISymbioticVault.withdraw.selector;
        selectors[2] = ISymbioticVault.claim.selector;

        abis[0] =
            '{"inputs":[{"internalType":"address","name":"onBehalfOf","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"deposit","outputs":[{"internalType":"uint256","name":"depositedAmount","type":"uint256"},{"internalType":"uint256","name":"mintedShares","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"internalType":"address","name":"claimer","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"withdraw","outputs":[{"internalType":"uint256","name":"burnedShares","type":"uint256"},{"internalType":"uint256","name":"mintedShares","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[2] =
            '{"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"epoch","type":"uint256"}],"name":"claim","outputs":[{"internalType":"uint256","name":"amount","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
    }

    function getResolvInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](8);
        abis = new string[](8);

        selectors[0] = IUsrExternalRequestsManager.requestMint.selector;
        selectors[1] = IUsrExternalRequestsManager.requestBurn.selector;
        selectors[2] = IUsrExternalRequestsManager.cancelMint.selector;
        selectors[3] = IUsrExternalRequestsManager.cancelBurn.selector;
        selectors[4] = IUsrExternalRequestsManager.redeem.selector;

        selectors[5] = IStUSR.deposit.selector;
        selectors[6] = IStUSR.withdraw.selector;
        selectors[7] = IStUSR.withdrawAll.selector;

        abis[0] =
            '{"inputs":[{"internalType":"address","name":"_depositTokenAddress","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"},{"internalType":"uint256","name":"_minMintAmount","type":"uint256"}],"name":"requestMint","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"internalType":"uint256","name":"_issueTokenAmount","type":"uint256"},{"internalType":"address","name":"_withdrawalTokenAddress","type":"address"},{"internalType":"uint256","name":"_minWithdrawalAmount","type":"uint256"}],"name":"requestBurn","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[2] =
            '{"inputs":[{"internalType":"uint256","name":"_id","type":"uint256"}],"name":"cancelMint","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[3] =
            '{"inputs":[{"internalType":"uint256","name":"_id","type":"uint256"}],"name":"cancelBurn","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[4] =
            '{"inputs":[{"internalType":"uint256","name":"_amount","type":"uint256"},{"internalType":"address","name":"_withdrawalTokenAddress","type":"address"},{"internalType":"uint256","name":"_minExpectedAmount","type":"uint256"}],"name":"redeem","outputs":[],"stateMutability":"nonpayable","type":"function"}';

        abis[5] =
            '{"inputs":[{"internalType":"uint256","name":"_usrAmount","type":"uint256"}],"name":"deposit","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[6] =
            '{"inputs":[{"internalType":"uint256","name":"_usrAmount","type":"uint256"}],"name":"withdraw","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[7] = '{"inputs":[],"name":"withdrawAll","outputs":[],"stateMutability":"nonpayable","type":"function"}';
    }

    function getStakeWiseInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](6);
        abis = new string[](6);

        selectors[0] = IStakeWiseEthVault.deposit.selector;
        selectors[1] = IStakeWiseEthVault.depositAndMintOsToken.selector;
        selectors[2] = IStakeWiseEthVault.mintOsToken.selector;
        selectors[3] = IStakeWiseEthVault.burnOsToken.selector;
        selectors[4] = IStakeWiseEthVault.enterExitQueue.selector;
        selectors[5] = IStakeWiseEthVault.claimExitedAssets.selector;

        abis[0] =
            '{"type":"function","name":"deposit","inputs":[{"name":"receiver","type":"address","internalType":"address"},{"name":"referrer","type":"address","internalType":"address"}],"outputs":[{"name":"shares","type":"uint256","internalType":"uint256"}],"stateMutability":"payable"}';
        abis[1] =
            '{"type":"function","name":"depositAndMintOsToken","inputs":[{"name":"receiver","type":"address","internalType":"address"},{"name":"osTokenShares","type":"uint256","internalType":"uint256"},{"name":"referrer","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"payable"}';
        abis[2] =
            '{"type":"function","name":"mintOsToken","inputs":[{"name":"receiver","type":"address","internalType":"address"},{"name":"osTokenShares","type":"uint256","internalType":"uint256"},{"name":"referrer","type":"address","internalType":"address"}],"outputs":[{"name":"assets","type":"uint256","internalType":"uint256"}],"stateMutability":"nonpayable"}';
        abis[3] =
            '{"type":"function","name":"burnOsToken","inputs":[{"name":"osTokenShares","type":"uint128","internalType":"uint128"}],"outputs":[{"name":"assets","type":"uint256","internalType":"uint256"}],"stateMutability":"nonpayable"}';
        abis[4] =
            '{"inputs":[{"internalType":"uint256","name":"shares","type":"uint256"},{"internalType":"address","name":"receiver","type":"address"}],"stateMutability":"nonpayable","type":"function","name":"enterExitQueue","outputs":[{"internalType":"uint256","name":"positionTicket","type":"uint256"}]}';
        abis[5] =
            '{"type":"function","name":"claimExitedAssets","inputs":[{"name":"positionTicket","type":"uint256","internalType":"uint256"},{"name":"timestamp","type":"uint256","internalType":"uint256"},{"name":"exitQueueIndex","type":"uint256","internalType":"uint256"}],"outputs":[],"stateMutability":"nonpayable"}';
    }

    function getSwapModuleInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](2);
        abis = new string[](2);

        selectors[0] = ISwapModule.pushAssets.selector;
        selectors[1] = ISwapModule.pullAssets.selector;

        abis[0] =
            '{"type":"function","name":"pushAssets","inputs":[{"name":"asset","type":"address","internalType":"address"},{"name":"value","type":"uint256","internalType":"uint256"}],"outputs":[],"stateMutability":"payable"}';
        abis[1] =
            '{"type":"function","name":"pullAssets","inputs":[{"name":"asset","type":"address","internalType":"address"},{"name":"value","type":"uint256","internalType":"uint256"}],"outputs":[],"stateMutability":"nonpayable"}';
    }
}
