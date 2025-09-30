// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IAavePoolV3} from "./interfaces/IAavePoolV3.sol";
import {ICowswapSettlement} from "./interfaces/ICowswapSettlement.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library ABILibrary {
    function getABI(bytes4 selector) internal pure returns (string memory) {
        function () pure returns (bytes4[] memory,string[] memory)[4] memory functions =
            [getERC20Interfaces, getAaveInterfaces, getWETHInterfaces, getCowSwapInterfaces];
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
}
