// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import "../ParameterLibrary.sol";
import "../ProofLibrary.sol";
import "../interfaces/Imports.sol";

import {ERC20Library} from "./ERC20Library.sol";

import "../interfaces/IBoringOnChainQueue.sol";
import "../interfaces/ITeller.sol";

library GGVLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address subvault;
        string subvaultName;
        address curator;
    }

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address public constant TELLER = 0x4C74ccA483A278Bcb90Aea3f8F565e56202D82B2;
    address public constant GGV = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
    address public constant WITHDRAWAL_QUEUE = 0xe39682c3C44b73285A2556D4869041e674d1a6B7;

    function _getERC20Params(address curator) internal pure returns (ERC20Library.Info memory) {
        return ERC20Library.Info({
            curator: curator,
            assets: ArraysLibrary.makeAddressArray(abi.encode(WETH, WSTETH, GGV)),
            to: ArraysLibrary.makeAddressArray(abi.encode(GGV, GGV, WITHDRAWAL_QUEUE))
        });
    }

    /*
        1. WETH.approve(GGV, any)
        2. WSTETH.approve(GGV, any)
        3. GGV.approve(WITHDRAWAL_QUEUE, any)
        4. TELLER.deposit{value: any}(ETH, any, any, any)
        5. TELLER.deposit(WETH, any, any, any)
        6. TELLER.deposit(WSTETH, any, any, any)
        7. WITHDRAWAL_QUEUE.requestOnChainWithdraw(WSTETH, any, any, any)
        8. WITHDRAWAL_QUEUE.cancelOnChainWithdraw((any, subvault, WSTETH, any, any, any, any, any))
        9. WITHDRAWAL_QUEUE.replaceOnChainWithdraw((any, subvault, WSTETH, any, any, any, any, any), any, any)
    */
    function getGGVProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 length = 15;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        index = ArraysLibrary.insert(
            leaves, ERC20Library.getERC20Proofs(bitmaskVerifier, _getERC20Params($.curator)), index
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            TELLER,
            0,
            abi.encodeCall(ITeller.deposit, (ETH, 0, 0, address(0))),
            ProofLibrary.makeBitmask(
                true, true, false, true, abi.encodeCall(ITeller.deposit, (address(type(uint160).max), 0, 0, address(0)))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            TELLER,
            0,
            abi.encodeCall(ITeller.deposit, (WETH, 0, 0, address(0))),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ITeller.deposit, (address(type(uint160).max), 0, 0, address(0)))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            TELLER,
            0,
            abi.encodeCall(ITeller.deposit, (WSTETH, 0, 0, address(0))),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ITeller.deposit, (address(type(uint160).max), 0, 0, address(0)))
            )
        );

        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            WITHDRAWAL_QUEUE,
            0,
            abi.encodeCall(IBoringOnChainQueue.requestOnChainWithdraw, (WSTETH, 0, 0, 0)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IBoringOnChainQueue.requestOnChainWithdraw, (address(type(uint160).max), 0, 0, 0))
            )
        );

        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            WITHDRAWAL_QUEUE,
            0,
            abi.encodeCall(
                IBoringOnChainQueue.cancelOnChainWithdraw,
                (IBoringOnChainQueue.OnChainWithdraw(0, $.subvault, WSTETH, 0, 0, 0, 0, 0))
            ),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    IBoringOnChainQueue.cancelOnChainWithdraw,
                    (
                        IBoringOnChainQueue.OnChainWithdraw(
                            0, address(type(uint160).max), address(type(uint160).max), 0, 0, 0, 0, 0
                        )
                    )
                )
            )
        );

        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            WITHDRAWAL_QUEUE,
            0,
            abi.encodeCall(
                IBoringOnChainQueue.replaceOnChainWithdraw,
                (IBoringOnChainQueue.OnChainWithdraw(0, $.subvault, WSTETH, 0, 0, 0, 0, 0), 0, 0)
            ),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    IBoringOnChainQueue.replaceOnChainWithdraw,
                    (
                        IBoringOnChainQueue.OnChainWithdraw(
                            0, address(type(uint160).max), address(type(uint160).max), 0, 0, 0, 0, 0
                        ),
                        0,
                        0
                    )
                )
            )
        );

        assembly {
            mstore(leaves, index)
        }
    }

    function getGGVDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = 15;
        descriptions = new string[](length);
        uint256 index = 0;

        ParameterLibrary.Parameter[] memory innerParameters;

        index = ArraysLibrary.insert(descriptions, ERC20Library.getERC20Descriptions(_getERC20Params($.curator)), index);

        innerParameters = ParameterLibrary.build("depositAsset", Strings.toHexString(ETH)).addAny("depositAmount")
            .addAny("minimumMint").addAny("referralAddress");
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("TELLER.deposit{value: any}(ETH, any, any, any)")),
            ABILibrary.getABI(ITeller.deposit.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(TELLER), "any"),
            innerParameters
        );
        innerParameters = ParameterLibrary.build("depositAsset", Strings.toHexString(WETH)).addAny("depositAmount")
            .addAny("minimumMint").addAny("referralAddress");
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("TELLER.deposit(WETH, any, any, any)")),
            ABILibrary.getABI(ITeller.deposit.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(TELLER), "0"),
            innerParameters
        );
        innerParameters = ParameterLibrary.build("depositAsset", Strings.toHexString(WSTETH)).addAny("depositAmount")
            .addAny("minimumMint").addAny("referralAddress");
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("TELLER.deposit(WSTETH, any, any, any)")),
            ABILibrary.getABI(ITeller.deposit.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(TELLER), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("assetOut", Strings.toHexString(WSTETH)).addAny("amountOfShares")
            .addAny("discount").addAny("secondsToDeadline");
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("WITHDRAWAL_QUEUE.requestOnChainWithdraw(WSTETH, any, any, any)")),
            ABILibrary.getABI(IBoringOnChainQueue.requestOnChainWithdraw.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(WITHDRAWAL_QUEUE), "0"),
            innerParameters
        );

        string memory requestJson =
            JsonLibrary.toJson(IBoringOnChainQueue.OnChainWithdraw(0, $.subvault, WSTETH, 0, 0, 0, 0, 0));
        innerParameters = new ParameterLibrary.Parameter[](0);
        innerParameters.addJson("request", requestJson);
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "WITHDRAWAL_QUEUE.cancelOnChainWithdraw((any, subvault, WSTETH, any, any, any, any, any))"
                )
            ),
            ABILibrary.getABI(IBoringOnChainQueue.cancelOnChainWithdraw.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(WITHDRAWAL_QUEUE), "0"),
            innerParameters
        );

        innerParameters = new ParameterLibrary.Parameter[](0);
        innerParameters.addJson("oldRequest", requestJson).addAny("discount").addAny("secondsToDeadline");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "WITHDRAWAL_QUEUE.replaceOnChainWithdraw((any, subvault, WSTETH, any, any, any, any, any), any, any)"
                )
            ),
            ABILibrary.getABI(IBoringOnChainQueue.replaceOnChainWithdraw.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(WITHDRAWAL_QUEUE), "0"),
            innerParameters
        );
    }

    /*
        1. WETH.approve(GGV, any)
        2. WSTETH.approve(GGV, any)
        3. GGV.approve(WITHDRAWAL_QUEUE, any)
        4. TELLER.deposit{value: any}(ETH, any, any, any)
        5. TELLER.deposit(WETH, any, any, any)
        6. TELLER.deposit(WSTETH, any, any, any)
        7. WITHDRAWAL_QUEUE.requestOnChainWithdraw(WSTETH, any, any, any)
        8. WITHDRAWAL_QUEUE.cancelOnChainWithdraw((any, subvault, WSTETH, any, any, any, any, any))
        9. WITHDRAWAL_QUEUE.replaceOnChainWithdraw((any, subvault, WSTETH, any, any, any, any, any), any, any)
    */
    function getGGVCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][](15);

        index = ArraysLibrary.insert(calls, ERC20Library.getERC20Calls(_getERC20Params($.curator)), index);

        {
            address asset = ETH;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, TELLER, 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), true);
            tmp[i++] = Call($.curator, TELLER, 1 wei, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), true);
            tmp[i++] = Call($.curator, TELLER, 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(1))), true);

            tmp[i++] =
                Call(address(0xdead), TELLER, 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), false);
            tmp[i++] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), false);
            tmp[i++] =
                Call($.curator, TELLER, 0, abi.encodeCall(ITeller.deposit, (address(0xdead), 0, 0, address(0))), false);
            tmp[i++] = Call($.curator, TELLER, 0, abi.encode(ITeller.deposit.selector, asset, 0, 0, address(0)), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            address asset = WETH;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, TELLER, 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), true);
            tmp[i++] = Call($.curator, TELLER, 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(1))), true);

            tmp[i++] =
                Call(address(0xdead), TELLER, 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), false);
            tmp[i++] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), false);
            tmp[i++] = Call($.curator, TELLER, 1 wei, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), false);
            tmp[i++] =
                Call($.curator, TELLER, 0, abi.encodeCall(ITeller.deposit, (address(0xdead), 0, 0, address(0))), false);
            tmp[i++] = Call($.curator, TELLER, 0, abi.encode(ITeller.deposit.selector, asset, 0, 0, address(0)), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            address asset = WSTETH;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, TELLER, 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), true);
            tmp[i++] = Call($.curator, TELLER, 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(1))), true);

            tmp[i++] =
                Call(address(0xdead), TELLER, 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), false);
            tmp[i++] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), false);
            tmp[i++] = Call($.curator, TELLER, 1 wei, abi.encodeCall(ITeller.deposit, (asset, 0, 0, address(0))), false);
            tmp[i++] =
                Call($.curator, TELLER, 0, abi.encodeCall(ITeller.deposit, (address(0xdead), 0, 0, address(0))), false);
            tmp[i++] = Call($.curator, TELLER, 0, abi.encode(ITeller.deposit.selector, asset, 0, 0, address(0)), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.requestOnChainWithdraw, (WSTETH, 0, 0, 0)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.requestOnChainWithdraw, (WSTETH, 1, 0, 0)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.requestOnChainWithdraw, (WSTETH, 0, 1, 0)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.requestOnChainWithdraw, (WSTETH, 0, 0, 1)),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.requestOnChainWithdraw, (WSTETH, 0, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IBoringOnChainQueue.requestOnChainWithdraw, (WSTETH, 0, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                1 wei,
                abi.encodeCall(IBoringOnChainQueue.requestOnChainWithdraw, (WSTETH, 0, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.requestOnChainWithdraw, (address(0xdead), 0, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encode(IBoringOnChainQueue.requestOnChainWithdraw.selector, WSTETH, 0, 0, 0),
                false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            IBoringOnChainQueue.OnChainWithdraw memory request;
            request.assetOut = WSTETH;
            request.user = $.subvault;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                true
            );
            request.nonce = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                true
            );
            request.nonce = 0;
            request.amountOfShares = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                true
            );
            request.amountOfShares = 0;
            request.amountOfAssets = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                true
            );
            request.amountOfAssets = 0;
            request.creationTime = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                true
            );
            request.creationTime = 0;
            request.secondsToMaturity = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                true
            );
            request.secondsToMaturity = 0;
            request.secondsToDeadline = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                true
            );
            request.secondsToDeadline = 0;

            tmp[i++] = Call(
                address(0xdead),
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                1 wei,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encode(IBoringOnChainQueue.cancelOnChainWithdraw.selector, request),
                false
            );

            request.assetOut = address(0xdead);
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                false
            );

            request.assetOut = WSTETH;
            request.user = address(0xdead);
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.cancelOnChainWithdraw, (request)),
                false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            IBoringOnChainQueue.OnChainWithdraw memory request;
            request.assetOut = WSTETH;
            request.user = $.subvault;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                true
            );
            request.nonce = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                true
            );
            request.nonce = 0;
            request.amountOfShares = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                true
            );
            request.amountOfShares = 0;
            request.amountOfAssets = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                true
            );
            request.amountOfAssets = 0;
            request.creationTime = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                true
            );
            request.creationTime = 0;
            request.secondsToMaturity = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                true
            );
            request.secondsToMaturity = 0;
            request.secondsToDeadline = 1;
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                true
            );
            request.secondsToDeadline = 0;

            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 1, 0)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 1)),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                1 wei,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encode(IBoringOnChainQueue.replaceOnChainWithdraw.selector, request, 0, 0),
                false
            );

            request.assetOut = address(0xdead);
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                false
            );

            request.assetOut = WSTETH;
            request.user = address(0xdead);
            tmp[i++] = Call(
                $.curator,
                WITHDRAWAL_QUEUE,
                0,
                abi.encodeCall(IBoringOnChainQueue.replaceOnChainWithdraw, (request, 0, 0)),
                false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        assembly {
            mstore(calls, index)
        }
    }
}
