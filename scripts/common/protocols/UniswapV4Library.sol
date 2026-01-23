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
        bytes25[] poolIds;
        uint256[][] tokenIds; // allowed tokenIds per pool
    }

    function makeDuplicates(address addr, uint256 count) internal pure returns (address[] memory addrs) {
        addrs = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            addrs[i] = addr;
        }
    }

    function getUniqueAssets(Info memory $) internal view returns (address[] memory) {
        address[] memory tokens = new address[]($.poolIds.length * 2);
        uint256 count;

        for (uint256 i = 0; i < $.poolIds.length; i++) {
            IPositionManagerV4.PoolKey memory key = IPositionManagerV4($.positionManager).poolKeys($.poolIds[i]);
            tokens[i * 2] = key.currency0;
            tokens[i * 2 + 1] = key.currency1;
        }
        return ArraysLibrary.unique(tokens);
    }

    function makeIncreaseLiquidityCalldata(address positionManager, bytes25 poolId, uint256 tokenId)
        internal
        view
        returns (bytes memory)
    {
        IPositionManagerV4.PoolKey memory key = IPositionManagerV4(positionManager).poolKeys(poolId);
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(tokenId, 0, 0, 0, ""); // increaseLiquidity params
        params[1] = abi.encode(key.currency0, key.currency1); // settle params

        return makeModifyLiquiditiesCalldata(abi.encodePacked(ACTION_INCREASE_LIQUIDITY, ACTION_SETTLE_PAIR), params);
    }

    function makeDecreaseLiquidityCalldata(address positionManager, bytes25 poolId, uint256 tokenId)
        internal
        view
        returns (bytes memory)
    {
        IPositionManagerV4.PoolKey memory key = IPositionManagerV4(positionManager).poolKeys(poolId);
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(tokenId, 0, 0, 0, ""); // increaseLiquidity params
        params[1] = abi.encode(key.currency0, key.currency1); // settle params

        return makeModifyLiquiditiesCalldata(abi.encodePacked(ACTION_DECREASE_LIQUIDITY, ACTION_TAKE_PAIR), params);
    }

    function makeModifyLiquiditiesCalldata(bytes memory actions, bytes[] memory params)
        internal
        view
        returns (bytes memory)
    {
        return abi.encode(abi.encode(actions, params), block.timestamp + 1 hours);
    }

    function getUniswapV4Proofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
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
        for (uint256 i = 0; i < $.poolIds.length; i++) {
            bytes25 poolId = $.poolIds[i];
            for (uint256 j = 0; j < $.tokenIds[i].length; j++) {
                uint256 tokenId = $.tokenIds[i][j];
                leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                    bitmaskVerifier,
                    $.curator,
                    $.positionManager,
                    0,
                    makeIncreaseLiquidityCalldata($.positionManager, poolId, tokenId),
                    ProofLibrary.makeBitmask(
                        true,
                        true,
                        true,
                        true,
                        makeIncreaseLiquidityCalldata(address(type(uint160).max), poolId, type(uint256).max)
                    )
                );
            }
        }

        // enable decrease liquidity for given poolIds and tokenIds
        for (uint256 i = 0; i < $.poolIds.length; i++) {
            bytes25 poolId = $.poolIds[i];
            for (uint256 j = 0; j < $.tokenIds[i].length; j++) {
                uint256 tokenId = $.tokenIds[i][j];
                leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                    bitmaskVerifier,
                    $.curator,
                    $.positionManager,
                    0,
                    makeDecreaseLiquidityCalldata($.positionManager, poolId, tokenId),
                    ProofLibrary.makeBitmask(
                        true,
                        true,
                        true,
                        true,
                        makeDecreaseLiquidityCalldata(address(type(uint160).max), poolId, type(uint256).max)
                    )
                );
            }
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
                        "Permit2(",
                        Strings.toHexString(permit2),
                        ").approve(",
                        "token=",
                        Strings.toHexString(assets[i]),
                        ", spender=PositionManager, amount=any, expiration=any)"
                    )
                ),
                ABILibrary.getABI(IAllowanceTransfer.approve.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(permit2), "0"),
                innerParameters
            );
        }

        // enable increase liquidity for given poolIds and tokenIds
        for (uint256 i = 0; i < $.poolIds.length; i++) {
            bytes25 poolId = $.poolIds[i];
            for (uint256 j = 0; j < $.tokenIds[i].length; j++) {
                uint256 tokenId = $.tokenIds[i][j];
                // inner parameters for increaseLiquidity
                ParameterLibrary.Parameter[] memory innerParameters;
                innerParameters = innerParameters.add("tokenId", Strings.toString(tokenId));
                innerParameters = innerParameters.addAny("amount0Desired");
                innerParameters = innerParameters.addAny("amount1Desired");
                innerParameters = innerParameters.addAny("amount0Min");
                innerParameters = innerParameters.addAny("amount1Min");
                innerParameters = innerParameters.addAny("data");
                // inner parameters for settle
                innerParameters = innerParameters.add("currency0", "currency0Address");
                innerParameters = innerParameters.add("currency1", "currency1Address");

                descriptions[iterator++] = JsonLibrary.toJson(
                    string(
                        abi.encodePacked(
                            "IPositionManagerV4(",
                            Strings.toHexString($.positionManager),
                            ").modifyLiquidities(increaseLiquidity(tokenId=",
                            Strings.toString(tokenId),
                            ", amount0Desired=any, amount1Desired=any, amount0Min=any, amount1Min=any, data=any), settle(currency0=any, currency1=any))"
                        )
                    ),
                    ABILibrary.getABI(IPositionManagerV4.modifyLiquidities.selector),
                    ParameterLibrary.build(
                        Strings.toHexString($.curator), Strings.toHexString($.positionManager), "0"
                    ),
                    innerParameters
                );
            }
        }

        // enable to call IPositionManagerV4.modifyLiquidities with any parameters
        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = innerParameters.addAny("unlockData");
        innerParameters = innerParameters.addAny("deadline");
        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IPositionManagerV4(",
                    Strings.toHexString($.positionManager),
                    ").modifyLiquidities(unlockData=any, deadline=any)"
                )
            ),
            ABILibrary.getABI(IPositionManagerV4.modifyLiquidities.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.positionManager), "0"),
            innerParameters
        );

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
            uint48 ts = uint48(block.timestamp);
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

        // modifyLiquidities
        {
            Call[] memory tmp = new Call[](50);
            uint256 i = 0;

            bytes memory unlockData = new bytes(42); // arbitrary data
            uint48 ts = uint48(block.timestamp);

            tmp[i++] = Call(
                $.curator,
                $.positionManager,
                0,
                abi.encodeCall(IPositionManagerV4.modifyLiquidities, (unlockData, ts)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.positionManager,
                0,
                abi.encodeWithSelector(0x4afe393c, unlockData, ts), // modifyLiquiditiesWithoutUnlock
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.positionManager,
                0,
                abi.encodeCall(IPositionManagerV4.modifyLiquidities, (unlockData, ts)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IPositionManagerV4.modifyLiquidities, (unlockData, ts)),
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
