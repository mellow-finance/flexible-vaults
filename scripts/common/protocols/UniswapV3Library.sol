// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IPoolFactoryUniswapV3, IPoolUniswapV3, IPositionManagerV3} from "../interfaces/IPositionManagerV3.sol";
import "../interfaces/Imports.sol";

library UniswapV3Library {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address positionManager;
        address[] pools;
    }

    function makeDuplicates(address addr, uint256 count) internal pure returns (address[] memory addrs) {
        addrs = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            addrs[i] = addr;
        }
    }

    function getUniqueAssets(address[] memory pools) internal view returns (address[] memory) {
        address[] memory tokens = new address[](pools.length * 2);
        uint256 count;

        for (uint256 i = 0; i < pools.length; i++) {
            tokens[i * 2] = IPoolUniswapV3(pools[i]).token0();
            tokens[i * 2 + 1] = IPoolUniswapV3(pools[i]).token1();
        }
        return ArraysLibrary.unique(tokens);
    }

    function getTokenIdsV3(Info memory $) internal view returns (uint256[] memory tokenIds) {
        uint256 length = IPositionManagerV3($.positionManager).balanceOf($.subvault);
        address factory = IPositionManagerV3($.positionManager).factory();
        tokenIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = IPositionManagerV3($.positionManager).tokenOfOwnerByIndex($.subvault, i);
            if (IPositionManagerV3($.positionManager).getApproved(tokenId) != address(0)) {
                revert("TokenID must not have an approval");
            }
            (,, address token0, address token1, uint24 fee,,,,,,,) =
                IPositionManagerV3($.positionManager).positions(tokenId);
            for (uint256 j = 0; j < $.pools.length; j++) {
                if (IPoolFactoryUniswapV3(factory).getPool(token0, token1, fee) == $.pools[j]) {
                    tokenIds[i] = tokenId;
                    break;
                }
            }
        }
        return tokenIds;
    }

    function getUniswapV3Proofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        if ($.pools.length == 0) {
            return new IVerifier.VerificationPayload[](0);
        }

        leaves = new IVerifier.VerificationPayload[](100);
        uint256 iterator;
        address[] memory assets = getUniqueAssets($.pools);

        // approve permit2 to transfer tokens on behalf of position manager
        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({
                    curator: $.curator,
                    assets: assets,
                    to: makeDuplicates($.positionManager, assets.length)
                })
            ),
            iterator
        );

        // allow collect
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.positionManager,
            0,
            abi.encodeCall(
                IPositionManagerV3.collect,
                (IPositionManagerV3.CollectParams({tokenId: 0, recipient: $.subvault, amount0Max: 0, amount1Max: 0}))
            ),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    IPositionManagerV3.collect,
                    (
                        IPositionManagerV3.CollectParams({
                            tokenId: 0,
                            recipient: address(type(uint160).max),
                            amount0Max: 0,
                            amount1Max: 0
                        })
                    )
                )
            )
        );

        // allow to call IPositionManager.increaseLiquidity for allowed tokenIds
        uint256[] memory tokenIds = getTokenIdsV3($);
        for (uint256 j = 0; j < tokenIds.length; j++) {
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.positionManager,
                0,
                abi.encodeCall(
                    IPositionManagerV3.increaseLiquidity,
                    (
                        IPositionManagerV3.IncreaseLiquidityParams({
                            tokenId: tokenIds[j],
                            amount0Desired: 0,
                            amount1Desired: 0,
                            amount0Min: 0,
                            amount1Min: 0,
                            deadline: 0
                        })
                    )
                ),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(
                        IPositionManagerV3.increaseLiquidity,
                        (
                            IPositionManagerV3.IncreaseLiquidityParams({
                                tokenId: type(uint256).max,
                                amount0Desired: 0,
                                amount1Desired: 0,
                                amount0Min: 0,
                                amount1Min: 0,
                                deadline: 0
                            })
                        )
                    )
                )
            );
        }

        // allow to call IPositionManager.decreaseLiquidity with any parameters
        leaves[iterator++] = ProofLibrary.makeVerificationPayloadCompact(
            $.curator, $.positionManager, IPositionManagerV3.decreaseLiquidity.selector
        );

        // allow to call IPositionManager.burn with any parameters
        leaves[iterator++] =
            ProofLibrary.makeVerificationPayloadCompact($.curator, $.positionManager, IPositionManagerV3.burn.selector);

        assembly {
            mstore(leaves, iterator)
        }
    }

    function getUniswapV3Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        if ($.pools.length == 0) {
            return new string[](0);
        }
        address[] memory assets = getUniqueAssets($.pools);

        uint256 iterator;
        descriptions = new string[](100);

        // approve permit2 to transfer tokens on behalf of position manager
        iterator = descriptions.insert(
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: assets,
                    to: makeDuplicates($.positionManager, assets.length)
                })
            ),
            iterator
        );

        // allow collect
        {
            ParameterLibrary.Parameter[] memory innerParameters;
            innerParameters = innerParameters.addJson(
                "params",
                JsonLibrary.toJson(
                    IPositionManagerV3.CollectParams({tokenId: 0, recipient: $.subvault, amount0Max: 0, amount1Max: 0})
                )
            );
            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "NonfungiblePositionManager.collect(CollectParams(",
                        "tokenId=anyInt,",
                        "recipient=",
                        $.subvaultName,
                        ", amount0Max=anyInt, amount1Max=anyInt))"
                    )
                ),
                ABILibrary.getABI(IPositionManagerV3.collect.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.positionManager), "0"),
                innerParameters
            );
        }

        // allow to call IPositionManager.increaseLiquidity for allowed tokenIds
        uint256[] memory tokenIds = getTokenIdsV3($);
        // allow to call IPositionManager.increaseLiquidity with specific tokenIds
        for (uint256 j = 0; j < tokenIds.length; j++) {
            ParameterLibrary.Parameter[] memory innerParameters;
            innerParameters = innerParameters.addJson(
                "params",
                JsonLibrary.toJson(
                    IPositionManagerV3.IncreaseLiquidityParams({
                        tokenId: tokenIds[j],
                        amount0Desired: 0,
                        amount1Desired: 0,
                        amount0Min: 0,
                        amount1Min: 0,
                        deadline: 0
                    })
                )
            );
            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "NonfungiblePositionManager.increaseLiquidity(IncreaseLiquidityParams(",
                        "tokenId=",
                        Strings.toString(tokenIds[j]),
                        ", amount0Desired=anyInt, amount1Desired=anyInt, amount0Min=anyInt, amount1Min=anyInt, deadline=anyInt))"
                    )
                ),
                ABILibrary.getABI(IPositionManagerV3.increaseLiquidity.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.positionManager), "0"),
                innerParameters
            );
        }

        // allow to call IPositionManager.decreaseLiquidity
        {
            ParameterLibrary.Parameter[] memory innerParameters;
            innerParameters = innerParameters.addJson(
                "params",
                JsonLibrary.toJson(
                    IPositionManagerV3.DecreaseLiquidityParams({
                        tokenId: 0,
                        liquidity: 0,
                        amount0Min: 0,
                        amount1Min: 0,
                        deadline: 0
                    })
                )
            );
            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "NonfungiblePositionManager.decreaseLiquidity(DecreaseLiquidityParams(",
                        "tokenId=anyInt, liquidity=anyInt, amount0Min=anyInt, amount1Min=anyInt, deadline=anyInt))"
                    )
                ),
                ABILibrary.getABI(IPositionManagerV3.decreaseLiquidity.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.positionManager), "0"),
                innerParameters
            );
        }

        // allow to call IPositionManager.burn
        {
            ParameterLibrary.Parameter[] memory innerParameters;
            innerParameters = innerParameters.addAny("tokenId");
            descriptions[iterator++] = JsonLibrary.toJson(
                string(abi.encodePacked("NonfungiblePositionManager.burn(", "tokenId=anyInt)")),
                ABILibrary.getABI(IPositionManagerV3.burn.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.positionManager), "0"),
                innerParameters
            );
        }
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getUniswapV3Calls(Info memory $) internal view returns (Call[][] memory calls) {
        if ($.pools.length == 0) {
            return new Call[][](0);
        }
        address[] memory assets = getUniqueAssets($.pools);
        uint256[] memory tokenIds = getTokenIdsV3($);

        uint256 index;
        calls = new Call[][](100);

        index = calls.insert(
            ERC20Library.getERC20Calls(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: assets,
                    to: makeDuplicates($.positionManager, assets.length)
                })
            ),
            index
        );

        // collect
        {
            Call[] memory tmp = new Call[](50);
            uint256 i = 0;

            IPositionManagerV3.CollectParams memory params =
                IPositionManagerV3.CollectParams({tokenId: 0, recipient: $.subvault, amount0Max: 0, amount1Max: 0});

            tmp[i++] = Call($.curator, $.positionManager, 0, abi.encodeCall(IPositionManagerV3.collect, (params)), true);
            tmp[i++] =
                Call($.curator, $.positionManager, 1 wei, abi.encodeCall(IPositionManagerV3.collect, (params)), false);
            tmp[i++] =
                Call(address(0xdead), $.positionManager, 0, abi.encodeCall(IPositionManagerV3.collect, (params)), false);
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IPositionManagerV3.collect, (params)), false);
            tmp[i++] =
                Call($.curator, $.positionManager, 0, abi.encode(IPositionManagerV3.collect.selector, params), false);

            params.recipient = address(0xdead);
            tmp[i++] =
                Call($.curator, $.positionManager, 0, abi.encodeCall(IPositionManagerV3.collect, (params)), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        // increaseLiquidity
        uint256 forbiddenTokenId = type(uint256).max - 1;

        for (uint256 j = 0; j < tokenIds.length; j++) {
            Call[] memory tmp = new Call[](50);
            uint256 i = 0;
            IPositionManagerV3.IncreaseLiquidityParams memory params = IPositionManagerV3.IncreaseLiquidityParams({
                tokenId: tokenIds[j],
                amount0Desired: 0,
                amount1Desired: 0,
                amount0Min: 0,
                amount1Min: 0,
                deadline: 0
            });

            tmp[i++] = Call(
                $.curator, $.positionManager, 0, abi.encodeCall(IPositionManagerV3.increaseLiquidity, (params)), true
            );
            tmp[i++] = Call(
                $.curator, $.positionManager, 0, abi.encodeWithSelector(IPositionManagerV3.mint.selector, params), false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.positionManager,
                0,
                abi.encodeCall(IPositionManagerV3.increaseLiquidity, (params)),
                false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IPositionManagerV3.increaseLiquidity, (params)), false
            );
            params.tokenId = forbiddenTokenId;
            tmp[i++] = Call(
                $.curator, $.positionManager, 0, abi.encodeCall(IPositionManagerV3.increaseLiquidity, (params)), false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        // decreaseLiquidity
        {
            Call[] memory tmp = new Call[](50);
            uint256 i = 0;
            IPositionManagerV3.DecreaseLiquidityParams memory params = IPositionManagerV3.DecreaseLiquidityParams({
                tokenId: 0,
                liquidity: 0,
                amount0Min: 0,
                amount1Min: 0,
                deadline: 0
            });

            tmp[i++] = Call(
                $.curator, $.positionManager, 0, abi.encodeCall(IPositionManagerV3.decreaseLiquidity, (params)), true
            );
            tmp[i++] = Call(
                $.curator,
                $.positionManager,
                0,
                abi.encodeWithSelector(IPositionManagerV3.increaseLiquidity.selector, params),
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.positionManager,
                0,
                abi.encodeCall(IPositionManagerV3.decreaseLiquidity, (params)),
                false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IPositionManagerV3.decreaseLiquidity, (params)), false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        // burn
        {
            Call[] memory tmp = new Call[](50);
            uint256 i = 0;
            uint256 tokenId = 0;

            tmp[i++] = Call($.curator, $.positionManager, 0, abi.encodeCall(IPositionManagerV3.burn, (tokenId)), true);
            tmp[i++] = Call(
                $.curator,
                $.positionManager,
                0,
                abi.encodeWithSelector(IPositionManagerV3.mint.selector, tokenId),
                false
            );
            tmp[i++] =
                Call(address(0xdead), $.positionManager, 0, abi.encodeCall(IPositionManagerV3.burn, (tokenId)), false);
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IPositionManagerV3.burn, (tokenId)), false);
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
