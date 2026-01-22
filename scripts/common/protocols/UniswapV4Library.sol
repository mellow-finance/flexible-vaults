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

    struct Info {
        address curator;
        address positionManager;
        address[] assets;
    }

    function makeDuplicates(address addr, uint256 count) internal pure returns (address[] memory addrs) {
        addrs = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            addrs[i] = addr;
        }
    }

    function getUniswapV4Proofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        address permit2 = IPositionManagerV4($.positionManager).permit2();
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator;

        // approve permit2 to transfer tokens on behalf of position manager
        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({curator: $.curator, assets: $.assets, to: makeDuplicates(permit2, $.assets.length)})
            ),
            iterator
        );

        // approve position manager to transfer tokens on behalf of permit2
        for (uint256 i = 0; i < $.assets.length; i++) {
            address asset = $.assets[i];
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

        // enable to call IPositionManagerV4.modifyLiquidities with any parameters
        leaves[iterator++] = ProofLibrary.makeVerificationPayloadCompact(
            $.curator, $.positionManager, IPositionManagerV4.modifyLiquidities.selector
        );

        assembly {
            mstore(leaves, iterator)
        }
    }

    function getUniswapV4Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        address permit2 = IPositionManagerV4($.positionManager).permit2();
        uint256 iterator;

        descriptions = new string[](50);

        // approve permit2 to transfer tokens on behalf of position manager
        iterator = descriptions.insert(
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({curator: $.curator, assets: $.assets, to: makeDuplicates(permit2, $.assets.length)})
            ),
            iterator
        );

        // approve position manager to transfer tokens on behalf of permit2
        for (uint256 i = 0; i < $.assets.length; i++) {
            ParameterLibrary.Parameter[] memory innerParameters;
            innerParameters = innerParameters.add("token", Strings.toHexString($.assets[i]));
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
                        Strings.toHexString($.assets[i]),
                        ", spender=PositionManager, amount=any, expiration=any)"
                    )
                ),
                ABILibrary.getABI(IAllowanceTransfer.approve.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(permit2), "0"),
                innerParameters
            );
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

        address permit2 = IPositionManagerV4($.positionManager).permit2();

        index = calls.insert(
            ERC20Library.getERC20Calls(
                ERC20Library.Info({curator: $.curator, assets: $.assets, to: makeDuplicates(permit2, $.assets.length)})
            ),
            index
        );
        // approve position manager to transfer tokens on behalf of permit2
        {
            uint48 ts = uint48(block.timestamp);
            for (uint256 j = 0; j < $.assets.length; j++) {
                address asset = $.assets[j];
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
