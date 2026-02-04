// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IAllowanceTransfer, IPositionManagerV4} from "../interfaces/IPositionManagerV4.sol";
import "../interfaces/Imports.sol";

library UniswapV4Library {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    // https://github.com/Uniswap/v4-periphery/blob/main/src/libraries/Actions.sol
    uint8 constant ACTION_INCREASE_LIQUIDITY = uint8(0x00);
    uint8 constant ACTION_DECREASE_LIQUIDITY = uint8(0x01);
    uint8 constant ACTION_SETTLE_PAIR = uint8(0x0d);
    uint8 constant ACTION_TAKE_PAIR = uint8(0x11);

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address positionManager;
        uint256[] tokenIds; // allowed tokenIds
    }

    function makeDuplicates(address addr, uint256 count) internal pure returns (address[] memory addrs) {
        addrs = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            addrs[i] = addr;
        }
    }

    function getUniqueAssets(Info memory $) internal view returns (address[] memory) {
        address[] memory tokens = new address[]($.tokenIds.length * 2);
        uint256 count;

        for (uint256 i = 0; i < $.tokenIds.length; i++) {
            (IPositionManagerV4.PoolKey memory key,) =
                IPositionManagerV4($.positionManager).getPoolAndPositionInfo($.tokenIds[i]);
            tokens[i * 2] = key.currency0;
            tokens[i * 2 + 1] = key.currency1;
        }
        return ArraysLibrary.unique(tokens);
    }

    function checkTokenIds(Info memory $) internal view {
        for (uint256 i = 0; i < $.tokenIds.length; i++) {
            if (IPositionManagerV4($.positionManager).ownerOf($.tokenIds[i]) != $.subvault) {
                revert("Subvault is not owner of tokenId");
            }
            if (IPositionManagerV4($.positionManager).getApproved($.tokenIds[i]) != address(0)) {
                revert("TokenID must not have an approval");
            }
        }
    }

    function makeIncreaseLiquidityUnlockData(Info memory $, uint256 tokenId) internal view returns (bytes memory) {
        (IPositionManagerV4.PoolKey memory poolKey,) =
            IPositionManagerV4($.positionManager).getPoolAndPositionInfo(tokenId);

        return _makeIncreaseLiquidityUnlockData(tokenId, poolKey.currency0, poolKey.currency1);
    }

    function makeDecreaseLiquidityUnlockData(Info memory $, uint256 tokenId) internal view returns (bytes memory) {
        (IPositionManagerV4.PoolKey memory poolKey,) =
            IPositionManagerV4($.positionManager).getPoolAndPositionInfo(tokenId);

        return _makeDecreaseLiquidityUnlockData(tokenId, poolKey.currency0, poolKey.currency1, $.subvault);
    }

    function makeIncreaseLiquidityUnlockDataMask() internal view returns (bytes memory) {
        return
            _makeIncreaseLiquidityUnlockData(type(uint256).max, address(type(uint160).max), address(type(uint160).max));
    }

    function makeDecreaseLiquidityUnlockDataMask() internal view returns (bytes memory) {
        return _makeDecreaseLiquidityUnlockData(
            type(uint256).max, address(type(uint160).max), address(type(uint160).max), address(type(uint160).max)
        );
    }

    function _makeIncreaseLiquidityUnlockData(uint256 tokenId, address token0, address token1)
        internal
        view
        returns (bytes memory)
    {
        bytes[] memory params = new bytes[](2);
        // tokenId, liquidity, amount0Max, amount1Max, hookData
        params[0] = abi.encode(tokenId, 0, 0, 0, ""); // increaseLiquidity params
        // token0, token1
        params[1] = abi.encode(token0, token1); // settle params

        return abi.encode(abi.encodePacked(ACTION_INCREASE_LIQUIDITY, ACTION_SETTLE_PAIR), params);
    }

    function _makeDecreaseLiquidityUnlockData(uint256 tokenId, address token0, address token1, address recipient)
        internal
        view
        returns (bytes memory)
    {
        bytes[] memory params = new bytes[](2);
        // tokenId, liquidity, amount0Min, amount1Min, hookData
        params[0] = abi.encode(tokenId, 0, 0, 0, ""); // decreaseLiquidity params
        // token0, token1, recipient
        params[1] = abi.encode(token0, token1, recipient); // take params

        return abi.encode(abi.encodePacked(ACTION_DECREASE_LIQUIDITY, ACTION_TAKE_PAIR), params);
    }

    function getUniswapV4Proofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        checkTokenIds($);
        address permit2 = IPositionManagerV4($.positionManager).permit2();
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator;
        address[] memory assets = getUniqueAssets($);

        // approve permit2 to transfer tokens on behalf of position manager
        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({curator: $.curator, assets: assets, to: makeDuplicates(permit2, assets.length)})
            ),
            iterator
        );

        // approve position manager to transfer tokens on behalf of permit2
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                permit2,
                0,
                abi.encodeCall(IAllowanceTransfer.approve, (asset, $.positionManager, 0, 0)),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(
                        IAllowanceTransfer.approve, (address(type(uint160).max), address(type(uint160).max), 0, 0)
                    )
                )
            );
        }

        // enable increase liquidity for given poolIds and tokenIds
        for (uint256 i = 0; i < $.tokenIds.length; i++) {
            uint256 tokenId = $.tokenIds[i];
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.positionManager,
                0,
                abi.encodeCall(IPositionManagerV4.modifyLiquidities, (makeIncreaseLiquidityUnlockData($, tokenId), 0)),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(IPositionManagerV4.modifyLiquidities, (makeIncreaseLiquidityUnlockDataMask(), 0))
                )
            );
        }

        // enable decrease liquidity for given poolIds and tokenIds
        for (uint256 i = 0; i < $.tokenIds.length; i++) {
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.positionManager,
                0,
                abi.encodeCall(
                    IPositionManagerV4.modifyLiquidities, (makeDecreaseLiquidityUnlockData($, $.tokenIds[i]), 0)
                ),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(IPositionManagerV4.modifyLiquidities, (makeDecreaseLiquidityUnlockDataMask(), 0))
                )
            );
        }

        assembly {
            mstore(leaves, iterator)
        }
    }

    function getUniswapV4Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        address permit2 = IPositionManagerV4($.positionManager).permit2();
        uint256 iterator;
        address[] memory assets = getUniqueAssets($);

        descriptions = new string[](50);

        // approve permit2 to transfer tokens on behalf of position manager
        iterator = descriptions.insert(
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({curator: $.curator, assets: assets, to: makeDuplicates(permit2, assets.length)})
            ),
            iterator
        );

        // approve position manager to transfer tokens on behalf of permit2
        for (uint256 i = 0; i < assets.length; i++) {
            ParameterLibrary.Parameter[] memory innerParameters;
            innerParameters = innerParameters.add("token", Strings.toHexString(assets[i]));
            innerParameters = innerParameters.add("spender", Strings.toHexString($.positionManager));
            innerParameters = innerParameters.addAny("amount");
            innerParameters = innerParameters.addAny("expiration");
            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "Permit2.approve(",
                        "token=",
                        IERC20Metadata(assets[i]).symbol(),
                        ", spender=PositionManager, amount=any, expiration=any)"
                    )
                ),
                ABILibrary.getABI(IAllowanceTransfer.approve.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(permit2), "0"),
                innerParameters
            );
        }

        // enable increase liquidity for given poolIds and tokenIds
        for (uint256 i = 0; i < $.tokenIds.length; i++) {
            (IPositionManagerV4.PoolKey memory key,) =
                IPositionManagerV4($.positionManager).getPoolAndPositionInfo($.tokenIds[i]);

            // inner parameters for increaseLiquidity
            ParameterLibrary.Parameter[] memory innerParameters;
            innerParameters = innerParameters.add("unlockData", "anyBytes");
            innerParameters = innerParameters.add("deadline", "anyInt");

            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "PositionManagerV4.modifyLiquidities(increaseLiquidity(tokenId=",
                        Strings.toString($.tokenIds[i]),
                        ", amount0Desired=any, amount1Desired=any, amount0Min=any, amount1Min=any, data=any), settle(currency0=",
                        IERC20Metadata(key.currency0).symbol(),
                        ", currency1=",
                        IERC20Metadata(key.currency1).symbol(),
                        "))"
                    )
                ),
                ABILibrary.getABI(IPositionManagerV4.modifyLiquidities.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.positionManager), "0"),
                innerParameters
            );
        }
        // enable decrease liquidity for given poolIds and tokenIds
        for (uint256 i = 0; i < $.tokenIds.length; i++) {
            (IPositionManagerV4.PoolKey memory key,) =
                IPositionManagerV4($.positionManager).getPoolAndPositionInfo($.tokenIds[i]);

            // inner parameters for decreaseLiquidity
            ParameterLibrary.Parameter[] memory innerParameters;
            innerParameters = innerParameters.add("unlockData", "anyBytes");
            innerParameters = innerParameters.add("deadline", "anyInt");

            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "PositionManagerV4.modifyLiquidities(decreaseLiquidity(tokenId=",
                        Strings.toString($.tokenIds[i]),
                        ", liquidity=any, amount0Min=any, amount1Min=any, data=any), take(currency0=",
                        IERC20Metadata(key.currency0).symbol(),
                        ", currency1=",
                        IERC20Metadata(key.currency1).symbol(),
                        "))"
                    )
                ),
                ABILibrary.getABI(IPositionManagerV4.modifyLiquidities.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.positionManager), "0"),
                innerParameters
            );
        }

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getUniswapV4Calls(Info memory $) internal view returns (Call[][] memory calls) {
        uint256 index;
        calls = new Call[][](50);
        address[] memory assets = getUniqueAssets($);

        address permit2 = IPositionManagerV4($.positionManager).permit2();

        index = calls.insert(
            ERC20Library.getERC20Calls(
                ERC20Library.Info({curator: $.curator, assets: assets, to: makeDuplicates(permit2, assets.length)})
            ),
            index
        );
        // approve position manager to transfer tokens on behalf of permit2
        {
            uint48 ts = uint48(block.timestamp) + 1 hours;
            for (uint256 j = 0; j < assets.length; j++) {
                address asset = assets[j];
                {
                    Call[] memory tmp = new Call[](16);
                    uint256 i = 0;
                    tmp[i++] = Call(
                        $.curator,
                        permit2,
                        0,
                        abi.encodeCall(IAllowanceTransfer.approve, (asset, $.positionManager, 1 ether, ts)),
                        true
                    );
                    tmp[i++] = Call(
                        $.curator,
                        permit2,
                        0,
                        abi.encodeCall(IAllowanceTransfer.approve, (address(0xdead), $.positionManager, 1 ether, ts)),
                        false
                    );
                    tmp[i++] = Call(
                        $.curator,
                        permit2,
                        0,
                        abi.encodeCall(IAllowanceTransfer.approve, (asset, address(0xdead), 1 ether, ts)),
                        false
                    );
                    tmp[i++] = Call(
                        address(0xdead),
                        permit2,
                        0,
                        abi.encodeCall(IAllowanceTransfer.approve, (asset, $.positionManager, 1 ether, ts)),
                        false
                    );
                    tmp[i++] = Call(
                        $.curator,
                        address(0xdead),
                        0,
                        abi.encodeCall(IAllowanceTransfer.approve, (asset, $.positionManager, 1 ether, ts)),
                        false
                    );
                    tmp[i++] = Call(
                        $.curator,
                        permit2,
                        1 wei,
                        abi.encodeCall(IAllowanceTransfer.approve, (asset, $.positionManager, 1 ether, ts)),
                        false
                    );
                    assembly {
                        mstore(tmp, i)
                    }
                    calls[index++] = tmp;
                }
            }
        }
        // enable increase liquidity for given poolIds and tokenIds
        {
            uint48 ts = uint48(block.timestamp) + 1 hours;
            for (uint256 i = 0; i < $.tokenIds.length; i++) {
                uint256 tokenId = $.tokenIds[i];
                Call[] memory tmp = new Call[](16);
                uint256 k = 0;
                tmp[k++] = Call(
                    $.curator,
                    $.positionManager,
                    0,
                    abi.encodeCall(
                        IPositionManagerV4.modifyLiquidities, (makeIncreaseLiquidityUnlockData($, tokenId), 0)
                    ),
                    true
                );
                tmp[k++] = Call(
                    $.curator,
                    $.positionManager,
                    0,
                    abi.encodeCall(
                        IPositionManagerV4.modifyLiquidities, (makeIncreaseLiquidityUnlockData($, tokenId), ts)
                    ),
                    true
                );
                tmp[k++] = Call(
                    address(0xdead),
                    $.positionManager,
                    0,
                    abi.encodeCall(
                        IPositionManagerV4.modifyLiquidities, (makeIncreaseLiquidityUnlockData($, tokenId), ts)
                    ),
                    false
                );
                tmp[k++] = Call(
                    $.curator,
                    address(0xdead),
                    0,
                    abi.encodeCall(
                        IPositionManagerV4.modifyLiquidities, (makeIncreaseLiquidityUnlockData($, tokenId), ts)
                    ),
                    false
                );
                tmp[k++] = Call(
                    $.curator,
                    $.positionManager,
                    1 wei,
                    abi.encodeCall(
                        IPositionManagerV4.modifyLiquidities, (makeIncreaseLiquidityUnlockData($, tokenId), ts)
                    ),
                    false
                );
                tmp[k++] = Call(
                    $.curator,
                    $.positionManager,
                    0,
                    abi.encodeCall(IPositionManagerV4.modifyLiquidities, (makeIncreaseLiquidityUnlockData($, 1), ts)),
                    false
                );
                tmp[k++] = Call(
                    $.curator,
                    $.positionManager,
                    0,
                    abi.encode(
                        IPositionManagerV4.modifyLiquidities.selector, makeIncreaseLiquidityUnlockData($, tokenId), ts
                    ),
                    false
                );
                assembly {
                    mstore(tmp, k)
                }
                calls[index++] = tmp;
            }
        }
        // enable decrease liquidity for given poolIds and tokenIds
        {
            uint48 ts = uint48(block.timestamp) + 1 hours;
            for (uint256 i = 0; i < $.tokenIds.length; i++) {
                uint256 tokenId = $.tokenIds[i];
                Call[] memory tmp = new Call[](16);
                uint256 k = 0;
                tmp[k++] = Call(
                    $.curator,
                    $.positionManager,
                    0,
                    abi.encodeCall(
                        IPositionManagerV4.modifyLiquidities, (makeDecreaseLiquidityUnlockData($, tokenId), 0)
                    ),
                    true
                );
                tmp[k++] = Call(
                    $.curator,
                    $.positionManager,
                    0,
                    abi.encodeCall(
                        IPositionManagerV4.modifyLiquidities, (makeDecreaseLiquidityUnlockData($, tokenId), ts)
                    ),
                    true
                );
                tmp[k++] = Call(
                    address(0xdead),
                    $.positionManager,
                    0,
                    abi.encodeCall(
                        IPositionManagerV4.modifyLiquidities, (makeDecreaseLiquidityUnlockData($, tokenId), ts)
                    ),
                    false
                );
                tmp[k++] = Call(
                    $.curator,
                    address(0xdead),
                    0,
                    abi.encodeCall(
                        IPositionManagerV4.modifyLiquidities, (makeDecreaseLiquidityUnlockData($, tokenId), ts)
                    ),
                    false
                );
                tmp[k++] = Call(
                    $.curator,
                    $.positionManager,
                    1 wei,
                    abi.encodeCall(
                        IPositionManagerV4.modifyLiquidities, (makeDecreaseLiquidityUnlockData($, tokenId), ts)
                    ),
                    false
                );
                tmp[k++] = Call(
                    $.curator,
                    $.positionManager,
                    0,
                    abi.encodeCall(IPositionManagerV4.modifyLiquidities, (makeDecreaseLiquidityUnlockData($, 1), ts)),
                    false
                );
                address subvault = $.subvault;
                $.subvault = address(0xdead); // to make sure wrong subvault is not accepted
                tmp[k++] = Call(
                    $.curator,
                    $.positionManager,
                    0,
                    abi.encodeCall(
                        IPositionManagerV4.modifyLiquidities, (makeDecreaseLiquidityUnlockData($, tokenId), ts)
                    ),
                    false
                );
                $.subvault = subvault;
                tmp[k++] = Call(
                    $.curator,
                    $.positionManager,
                    0,
                    abi.encode(
                        IPositionManagerV4.modifyLiquidities.selector, makeDecreaseLiquidityUnlockData($, tokenId), ts
                    ),
                    false
                );
                assembly {
                    mstore(tmp, k)
                }
                calls[index++] = tmp;
            }
        }

        assembly {
            mstore(calls, index)
        }
    }
}
