// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";

import "../ArraysLibrary.sol";
import "../ProofLibrary.sol";
import "../protocols/ERC20Library.sol";

import "../interfaces/IGearingToken.sol";
import "../interfaces/ITermMaxMarket.sol";
import "../interfaces/ITermMaxRouter.sol";
import "../interfaces/Imports.sol";

library TermMaxLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address subvault;
        address router;
        address market;
    }

    function getTermMaxProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        (,, address gt, address collateral, address borrow) = ITermMaxMarket($.market).tokens();

        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator;

        /// @dev approve collateral/borrow tokens to router
        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(collateral, borrow)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.router, $.router))
                })
            ),
            iterator
        );

        /// @dev borrow from router
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.router,
            0,
            abi.encodeCall(
                ITermMaxRouter.borrowTokenFromCollateral,
                ($.subvault, $.market, 0, new address[](1), new uint128[](1), 0, 0)
            ),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    ITermMaxRouter.borrowTokenFromCollateral,
                    (
                        address(type(uint160).max),
                        address(type(uint160).max),
                        0,
                        new address[](1),
                        new uint128[](1),
                        0,
                        0
                    )
                )
            )
        );
        /// @dev repay to router
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.router,
            0,
            abi.encodeCall(ITermMaxRouter.repayGt, ($.market, 0, 0, true)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ITermMaxRouter.repayGt, (address(type(uint160).max), 0, 0, true))
            )
        );
        /// @dev merge GTs
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            gt,
            0,
            abi.encodeCall(IGearingToken.merge, (new uint256[](2))),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IGearingToken.merge, (new uint256[](2))))
        );
        /// @dev remove collateral
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            gt,
            0,
            abi.encodeCall(IGearingToken.removeCollateral, (0, new bytes(32))),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IGearingToken.removeCollateral, (0, new bytes(32)))
            )
        );

        assembly {
            mstore(leaves, iterator)
        }
    }

    function getTermMaxDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 iterator;
        descriptions = new string[](50);
        ParameterLibrary.Parameter[] memory innerParameters;

        (,, address gt, address collateral, address borrow) = ITermMaxMarket($.market).tokens();

        /// @dev approve collateral/borrow to router
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(collateral, borrow)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.router, $.router))
                })
            ),
            iterator
        );
        /// @dev borrow from router
        {
            innerParameters = ParameterLibrary.build("subvault", Strings.toHexString($.subvault));
            innerParameters = innerParameters.add("market", Strings.toHexString($.market));
            innerParameters = innerParameters.addAnyArray("orders", 1);
            innerParameters = innerParameters.addAnyArray("tokenAmtsWantBuy", 1);
            innerParameters = innerParameters.addAny("maxDebtAmt");
            innerParameters = innerParameters.addAny("deadline");
            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "ITermMaxRouter(TermMaxRouter).borrowTokenFromCollateral(",
                        Strings.toHexString($.subvault),
                        ", ",
                        Strings.toHexString($.market),
                        ", anyInt, anyArr, anyArr, anyInt, anyInt)"
                    )
                ),
                ABILibrary.getABI(ITermMaxRouter.borrowTokenFromCollateral.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.router), "0"),
                innerParameters
            );
        }
        /// @dev repay to router
        {
            innerParameters = ParameterLibrary.build("market", Strings.toHexString($.market));
            innerParameters = innerParameters.addAny("gtId").addAny("maxRepayAmt");
            innerParameters = innerParameters.add("byDebtToken", "true");
            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "ITermMaxRouter(TermMaxRouter).repayGt(",
                        Strings.toHexString($.market),
                        ", anyInt, maxRepayAmt, true)"
                    )
                ),
                ABILibrary.getABI(ITermMaxRouter.repayGt.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.router), "0"),
                innerParameters
            );
        }
        /// @dev merge GTs
        {
            innerParameters = ParameterLibrary.build("ids", "arr[2]");
            descriptions[iterator++] = JsonLibrary.toJson(
                "IGearingToken(GearingToken).merge(arr[2])",
                ABILibrary.getABI(IGearingToken.merge.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(gt), "0"),
                innerParameters
            );
        }
        /// @dev remove collateral
        {
            innerParameters = ParameterLibrary.build("id", "anyInt").add("collateralData", "anyBytes");
            descriptions[iterator++] = JsonLibrary.toJson(
                "IGearingToken(GearingToken).removeCollateral(id,bytes)",
                ABILibrary.getABI(IGearingToken.removeCollateral.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(gt), "0"),
                innerParameters
            );
        }
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getTermMaxCalls(Info memory $) internal view returns (Call[][] memory calls) {
        uint256 index;
        calls = new Call[][](100);
        (,, address gt, address collateral, address borrow) = ITermMaxMarket($.market).tokens();
        /// @dev approve collateral/borrow to router
        index = ArraysLibrary.insert(
            calls,
            ERC20Library.getERC20Calls(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(collateral, borrow)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.router, $.router))
                })
            ),
            index
        );
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.router,
                0,
                abi.encodeCall(
                    ITermMaxRouter.borrowTokenFromCollateral,
                    ($.subvault, $.market, 0, new address[](1), new uint128[](1), 0, 0)
                ),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.router,
                0,
                abi.encodeCall(
                    ITermMaxRouter.borrowTokenFromCollateral,
                    ($.subvault, $.market, 0, new address[](1), new uint128[](1), 1234, 0)
                ),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.router,
                0,
                abi.encodeCall(
                    ITermMaxRouter.borrowTokenFromCollateral,
                    ($.subvault, $.market, 0, new address[](1), new uint128[](1), 0, 1234567890)
                ),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.router,
                0,
                abi.encodeCall(
                    ITermMaxRouter.borrowTokenFromCollateral,
                    ($.subvault, $.market, 1 ether, new address[](1), new uint128[](1), 0, 0)
                ),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.router,
                1 wei,
                abi.encodeCall(
                    ITermMaxRouter.borrowTokenFromCollateral,
                    ($.subvault, $.market, 0, new address[](1), new uint128[](1), 0, 0)
                ),
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.router,
                0,
                abi.encodeCall(
                    ITermMaxRouter.borrowTokenFromCollateral,
                    ($.subvault, $.market, 0, new address[](1), new uint128[](1), 0, 0)
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.router,
                0,
                abi.encodeCall(
                    ITermMaxRouter.borrowTokenFromCollateral,
                    (address(0xdead), $.market, 0, new address[](1), new uint128[](1), 0, 0)
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.router,
                0,
                abi.encodeCall(
                    ITermMaxRouter.borrowTokenFromCollateral,
                    ($.subvault, address(0xdead), 0, new address[](1), new uint128[](1), 0, 0)
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.router,
                0,
                abi.encodeCall(
                    ITermMaxRouter.borrowTokenFromCollateral,
                    ($.subvault, $.market, 0, new address[](2), new uint128[](1), 0, 0)
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.router,
                0,
                abi.encodeCall(
                    ITermMaxRouter.borrowTokenFromCollateral,
                    ($.subvault, $.market, 0, new address[](1), new uint128[](2), 0, 0)
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.router,
                0,
                abi.encode(
                    ITermMaxRouter.borrowTokenFromCollateral.selector,
                    $.subvault,
                    $.market,
                    0,
                    new address[](1),
                    new uint128[](1),
                    0,
                    0
                ),
                false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.router, 0, abi.encodeCall(ITermMaxRouter.repayGt, ($.market, 0, 0, true)), true);
            tmp[i++] =
                Call($.curator, $.router, 0, abi.encodeCall(ITermMaxRouter.repayGt, ($.market, 1, 0, true)), true);
            tmp[i++] =
                Call($.curator, $.router, 0, abi.encodeCall(ITermMaxRouter.repayGt, ($.market, 0, 1 ether, true)), true);
            tmp[i++] =
                Call($.curator, $.router, 0, abi.encodeCall(ITermMaxRouter.repayGt, ($.market, 0, 0, false)), false);
            tmp[i++] = Call(
                $.curator, $.router, 1 ether, abi.encodeCall(ITermMaxRouter.repayGt, ($.market, 0, 0, true)), false
            );
            tmp[i++] = Call(
                address(0xdead), $.router, 0, abi.encodeCall(ITermMaxRouter.repayGt, ($.market, 0, 0, true)), false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(ITermMaxRouter.repayGt, ($.market, 0, 0, true)), false
            );
            tmp[i++] = Call(
                $.curator, $.router, 0, abi.encodeCall(ITermMaxRouter.repayGt, (address(0xdead), 0, 0, true)), false
            );
            tmp[i++] =
                Call($.curator, $.router, 0, abi.encode(ITermMaxRouter.repayGt.selector, $.market, 0, 0, true), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        {
            Call[] memory tmp = new Call[](8);
            uint256 i = 0;
            tmp[i++] = Call($.curator, gt, 0, abi.encodeCall(IGearingToken.merge, (new uint256[](2))), true);
            tmp[i++] = Call($.curator, gt, 0, abi.encodeCall(IGearingToken.merge, (new uint256[](1))), false);
            tmp[i++] = Call($.curator, gt, 1 wei, abi.encodeCall(IGearingToken.merge, (new uint256[](2))), false);
            tmp[i++] = Call(address(0xdead), gt, 0, abi.encodeCall(IGearingToken.merge, (new uint256[](2))), false);
            tmp[i++] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(IGearingToken.merge, (new uint256[](2))), false);
            tmp[i++] = Call($.curator, gt, 0, abi.encode(IGearingToken.merge.selector, new uint256[](2)), false);
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        /// @dev remove collateral
        {
            Call[] memory tmp = new Call[](8);
            uint256 i = 0;
            bytes memory collateralData = hex"000000000000000000000000000000000000000000000001158e460913d00000";
            tmp[i++] = Call($.curator, gt, 0, abi.encodeCall(IGearingToken.removeCollateral, (1, collateralData)), true);
            tmp[i++] = Call($.curator, gt, 0, abi.encodeCall(IGearingToken.removeCollateral, (2, collateralData)), true);
            tmp[i++] =
                Call($.curator, gt, 1 wei, abi.encodeCall(IGearingToken.removeCollateral, (1, collateralData)), false);
            tmp[i++] =
                Call(address(0xdead), gt, 0, abi.encodeCall(IGearingToken.removeCollateral, (1, collateralData)), false);
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IGearingToken.removeCollateral, (1, collateralData)),
                false
            );
            tmp[i++] =
                Call($.curator, gt, 0, abi.encode(IGearingToken.removeCollateral.selector, 1, collateralData), false);
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
