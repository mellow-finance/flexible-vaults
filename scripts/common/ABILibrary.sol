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

import {IOFT} from "./interfaces/IOFT.sol";
import {IWEETH, IEtherFiLiquidityPool, IWithdrawRequestNFT} from "./interfaces/IEtherfi.sol";

library ABILibrary {
    function getABI(bytes4 selector) internal pure returns (string memory) {
        function() pure returns (bytes4[] memory, string[] memory)[11] memory functions = [
            getERC20Interfaces,
            getERC4626Interfaces,
            getAaveInterfaces,
            getWETHInterfaces,
            getCowSwapInterfaces,
            getCurveInterfaces,
            getL1GatewayRouter,
            getL2GatewayRouter,
            getCCIPRouter,
            getOFT,
            getEtherFiInterfaces
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
        selectors = new bytes4[](4);
        abis = new string[](4);

        selectors[0] = ICurvePool.add_liquidity.selector;
        selectors[1] = ICurvePool.remove_liquidity.selector;
        selectors[2] = ICurveGauge.deposit.selector;
        selectors[3] = ICurveGauge.claim_rewards.selector;

        abis[0] =
            '{"inputs":[{"name":"_amounts","type":"uint256[]"},{"name":"_min_mint_amount","type":"uint256"}],"name":"add_liquidity","outputs":[{"name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"name":"_burn_amount","type":"uint256"},{"name":"_min_amounts","type":"uint256[]"}],"name":"remove_liquidity","outputs":[{"name":"","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"}';

        abis[2] =
            '{"inputs":[{"name":"_value","type":"uint256"}],"name":"deposit","outputs":[],"stateMutability":"nonpayable","type":"function"}';
        abis[3] = '{"inputs":[],"name":"claim_rewards","outputs":[],"stateMutability":"nonpayable","type":"function"}';
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

    function getOFT() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](1);
        abis = new string[](1);

        selectors[0] = IOFT.send.selector;
        abis[0] =
            '{"inputs":[{"components":[{"internalType":"uint32","name":"dstEid","type":"uint32"},{"internalType":"bytes32","name":"to","type":"bytes32"},{"internalType":"uint256","name":"amountLD","type":"uint256"},{"internalType":"uint256","name":"minAmountLD","type":"uint256"},{"internalType":"bytes","name":"extraOptions","type":"bytes"},{"internalType":"bytes","name":"composeMsg","type":"bytes"},{"internalType":"bytes","name":"oftCmd","type":"bytes"}],"internalType":"struct SendParam","name":"_sendParam","type":"tuple"},{"components":[{"internalType":"uint256","name":"nativeFee","type":"uint256"},{"internalType":"uint256","name":"lzTokenFee","type":"uint256"}],"internalType":"struct MessagingFee","name":"_fee","type":"tuple"},{"internalType":"address","name":"_refundAddress","type":"address"}],"name":"send","outputs":[{"components":[{"internalType":"bytes32","name":"guid","type":"bytes32"},{"internalType":"uint64","name":"nonce","type":"uint64"},{"components":[{"internalType":"uint256","name":"nativeFee","type":"uint256"},{"internalType":"uint256","name":"lzTokenFee","type":"uint256"}],"internalType":"struct MessagingFee","name":"fee","type":"tuple"}],"internalType":"struct MessagingReceipt","name":"msgReceipt","type":"tuple"},{"components":[{"internalType":"uint256","name":"amountSentLD","type":"uint256"},{"internalType":"uint256","name":"amountReceivedLD","type":"uint256"}],"internalType":"struct OFTReceipt","name":"oftReceipt","type":"tuple"}],"stateMutability":"payable","type":"function"}';
    }

    function getEtherFiInterfaces() internal pure returns (bytes4[] memory selectors, string[] memory abis) {
        selectors = new bytes4[](3);
        abis = new string[](3);

        selectors[0] = IWEETH.unwrap.selector;
        selectors[1] = IEtherFiLiquidityPool.requestWithdraw.selector;
        selectors[2] = IWithdrawRequestNFT.claimWithdraw.selector;

        abis[0] =
            '{"inputs":[{"internalType":"uint256","name":"_weETHAmount","type":"uint256"}],"name":"unwrap","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[1] =
            '{"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"requestWithdraw","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}';
        abis[2] =
            '{"inputs":[{"internalType":"uint256","name":"tokenId","type":"uint256"}],"name":"claimWithdraw","outputs":[],"stateMutability":"nonpayable","type":"function"}';
    }
}
