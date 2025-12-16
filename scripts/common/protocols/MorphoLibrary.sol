// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";

import {ArraysLibrary, Call} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {BitmaskVerifier, IVerifier, ProofLibrary} from "../ProofLibrary.sol";

import {ERC20Library} from "../protocols/ERC20Library.sol";

import {IMorpho} from "../interfaces/IMorpho.sol";

library MorphoLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        bytes32 marketId;
        address morpho;
        address subvault;
        address curator;
    }

    function getMorphoMarketName(Info memory info) internal view returns (string memory) {
        IMorpho.MarketParams memory marketParams = IMorpho(info.morpho).idToMarketParams(info.marketId);
        string memory loanSymbol = IERC20Metadata(marketParams.loanToken).symbol();
        string memory collateralSymbol = IERC20Metadata(marketParams.collateralToken).symbol();
        return string(
            abi.encodePacked(loanSymbol, "/", collateralSymbol, "/", Strings.toHexString(uint256(info.marketId)))
        );
    }

    function getMorphoProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        IMorpho.MarketParams memory marketParams = IMorpho($.morpho).idToMarketParams($.marketId);
        IMorpho.MarketParams memory marketParamsMask = IMorpho.MarketParams({
            loanToken: address(type(uint160).max),
            collateralToken: address(type(uint160).max),
            oracle: address(type(uint160).max),
            irm: address(type(uint160).max),
            lltv: type(uint256).max
        });

        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator;

        /// @dev approve collateral/borrow tokens to Morpho
        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(marketParams.collateralToken, marketParams.loanToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.morpho, $.morpho))
                })
            ),
            iterator
        );
        /// @dev supply to Morpho
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.morpho,
            0,
            abi.encodeCall(IMorpho.supply, (marketParams, 0, 0, $.subvault, "")),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IMorpho.supply, (marketParamsMask, 0, 0, address(type(uint160).max), ""))
            )
        );
        /// @dev supply collateral to Morpho
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.morpho,
            0,
            abi.encodeCall(IMorpho.supplyCollateral, (marketParams, 0, $.subvault, "")),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IMorpho.supplyCollateral, (marketParamsMask, 0, address(type(uint160).max), ""))
            )
        );
        /// @dev repay borrow on Morpho
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.morpho,
            0,
            abi.encodeCall(IMorpho.repay, (marketParams, 0, 0, $.subvault, "")),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IMorpho.repay, (marketParamsMask, 0, 0, address(type(uint160).max), ""))
            )
        );
        /// @dev borrow from Morpho
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.morpho,
            0,
            abi.encodeCall(IMorpho.borrow, (marketParams, 0, 0, $.subvault, $.subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    IMorpho.borrow, (marketParamsMask, 0, 0, address(type(uint160).max), address(type(uint160).max))
                )
            )
        );
        /// @dev withdraw from Morpho
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.morpho,
            0,
            abi.encodeCall(IMorpho.withdraw, (marketParams, 0, 0, $.subvault, $.subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    IMorpho.withdraw, (marketParamsMask, 0, 0, address(type(uint160).max), address(type(uint160).max))
                )
            )
        );
        /// @dev withdraw collateral from Morpho
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.morpho,
            0,
            abi.encodeCall(IMorpho.withdrawCollateral, (marketParams, 0, $.subvault, $.subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    IMorpho.withdrawCollateral,
                    (marketParamsMask, 0, address(type(uint160).max), address(type(uint160).max))
                )
            )
        );

        assembly {
            mstore(leaves, iterator)
        }
    }

    function getMorphoDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 iterator;
        descriptions = new string[](50);
        IMorpho.MarketParams memory marketParams = IMorpho($.morpho).idToMarketParams($.marketId);
        string memory marketName = getMorphoMarketName($);
        ParameterLibrary.Parameter[] memory innerParameters;
        ParameterLibrary.Parameter[] memory prefixInnerParameters =
            (new ParameterLibrary.Parameter[](0)).addJson("marketParams", JsonLibrary.toJson(marketParams));

        /// @dev approve collateral/borrow to Morpho
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(marketParams.collateralToken, marketParams.loanToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.morpho, $.morpho))
                })
            ),
            iterator
        );
        /// @dev supply
        innerParameters = prefixInnerParameters.addAny("assets").addAny("shares").add(
            "onBehalf", Strings.toHexString($.subvault)
        ).add("data", "");
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("IMorpho(", Strings.toHexString($.morpho), ").supply(", marketName, ")")),
            ABILibrary.getABI(IMorpho.supply.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.morpho), "0"),
            innerParameters
        );
        /// @dev supplyCollateral
        innerParameters =
            prefixInnerParameters.addAny("assets").add("onBehalf", Strings.toHexString($.subvault)).add("data", "");
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("IMorpho(", Strings.toHexString($.morpho), ").supplyCollateral(", marketName, ")")),
            ABILibrary.getABI(IMorpho.supplyCollateral.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.morpho), "0"),
            innerParameters
        );
        /// @dev repay on Morpho
        innerParameters = prefixInnerParameters.addAny("assets").addAny("shares").add(
            "onBehalf", Strings.toHexString($.subvault)
        ).add("data", "");
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("IMorpho(", Strings.toHexString($.morpho), ").repay(", marketName, ")")),
            ABILibrary.getABI(IMorpho.repay.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.morpho), "0"),
            innerParameters
        );
        /// @dev borrow from Morpho
        innerParameters = prefixInnerParameters.addAny("assets").addAny("shares").add(
            "onBehalf", Strings.toHexString($.subvault)
        ).add("receiver", Strings.toHexString($.subvault));
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("IMorpho(", Strings.toHexString($.morpho), ").borrow(", marketName, ")")),
            ABILibrary.getABI(IMorpho.borrow.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.morpho), "0"),
            innerParameters
        );
        /// @dev withdraw from Morpho
        innerParameters = prefixInnerParameters.addAny("assets").addAny("shares").add(
            "onBehalf", Strings.toHexString($.subvault)
        ).add("receiver", Strings.toHexString($.subvault));
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("IMorpho(", Strings.toHexString($.morpho), ").withdraw(", marketName, ")")),
            ABILibrary.getABI(IMorpho.withdraw.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.morpho), "0"),
            innerParameters
        );
        /// @dev withdrawCollateral from Morpho
        innerParameters = prefixInnerParameters.addAny("assets").add("onBehalf", Strings.toHexString($.subvault)).add(
            "receiver", Strings.toHexString($.subvault)
        );
        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked("IMorpho(", Strings.toHexString($.morpho), ").withdrawCollateral(", marketName, ")")
            ),
            ABILibrary.getABI(IMorpho.withdrawCollateral.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.morpho), "0"),
            innerParameters
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getMorphoCalls(Info memory $) internal view returns (Call[][] memory calls) {
        uint256 index;
        calls = new Call[][](100);
        IMorpho.MarketParams memory marketParams = IMorpho($.morpho).idToMarketParams($.marketId);
        IMorpho.MarketParams memory params;
        /// @dev approve collateral/borrow tokens to Morpho
        index = ArraysLibrary.insert(
            calls,
            ERC20Library.getERC20Calls(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(marketParams.collateralToken, marketParams.loanToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.morpho, $.morpho))
                })
            ),
            index
        );
        /// @dev supply to Morpho
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.supply, (marketParams, 0, 0, $.subvault, "")), true);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.supply, (marketParams, 1 ether, 0, $.subvault, "")), true
            );
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.supply, (marketParams, 0, 1 ether, $.subvault, "")), true
            );
            tmp[i++] = Call(
                $.curator, $.morpho, 1 wei, abi.encodeCall(IMorpho.supply, (marketParams, 0, 0, $.subvault, "")), false
            );
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encode(IMorpho.supply.selector, marketParams, 0, 0, $.subvault, ""), false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.supply, (marketParams, 0, 0, $.subvault, "0xdeadbeef")),
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.morpho,
                0,
                abi.encodeCall(IMorpho.supply, (marketParams, 0, 0, $.subvault, "")),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IMorpho.supply, (marketParams, 0, 0, $.subvault, "")),
                false
            );
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.supply, (marketParams, 0, 0, address(0xdead), "")), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.loanToken = address(0xdead);
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.supply, (params, 0, 0, $.subvault, "")), false);
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.collateralToken = address(0xdead);
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.supply, (params, 0, 0, $.subvault, "")), false);
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.oracle = address(0xdead);
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.supply, (params, 0, 0, $.subvault, "")), false);
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.irm = address(0xdead);
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.supply, (params, 0, 0, $.subvault, "")), false);
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.lltv = marketParams.lltv - 1;
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.supply, (params, 0, 0, $.subvault, "")), false);
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        /// @dev supply collateral to Morpho
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.supplyCollateral, (marketParams, 0, $.subvault, "")),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.supplyCollateral, (marketParams, 1 ether, $.subvault, "")),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.supplyCollateral, (marketParams, 1 ether, $.subvault, "0xdeadbeef")),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                1 wei,
                abi.encodeCall(IMorpho.supplyCollateral, (marketParams, 0, $.subvault, "")),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encode(IMorpho.supplyCollateral.selector, marketParams, 0, $.subvault, ""),
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.morpho,
                0,
                abi.encodeCall(IMorpho.supplyCollateral, (marketParams, 0, $.subvault, "")),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IMorpho.supplyCollateral, (marketParams, 0, $.subvault, "")),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.supplyCollateral, (marketParams, 0, address(0xdead), "")),
                false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.loanToken = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.supplyCollateral, (params, 0, $.subvault, "")), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.collateralToken = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.supplyCollateral, (params, 0, $.subvault, "")), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.oracle = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.supplyCollateral, (params, 0, $.subvault, "")), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.irm = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.supplyCollateral, (params, 0, $.subvault, "")), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.lltv = marketParams.lltv - 1;
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.supplyCollateral, (params, 0, $.subvault, "")), false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        /// @dev repay borrow on Morpho
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.repay, (marketParams, 0, 0, $.subvault, "")), true);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.repay, (marketParams, 1 ether, 0, $.subvault, "")), true
            );
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.repay, (marketParams, 0, 1 ether, $.subvault, "")), true
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.repay, (marketParams, 0, 0, $.subvault, "0xdeadbeef")),
                false
            );
            tmp[i++] = Call(
                $.curator, $.morpho, 1 wei, abi.encodeCall(IMorpho.repay, (marketParams, 0, 0, $.subvault, "")), false
            );
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encode(IMorpho.repay.selector, marketParams, 0, 0, $.subvault, ""), false
            );
            tmp[i++] = Call(
                address(0xdead), $.morpho, 0, abi.encodeCall(IMorpho.repay, (marketParams, 0, 0, $.subvault, "")), false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IMorpho.repay, (marketParams, 0, 0, $.subvault, "")),
                false
            );
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.repay, (marketParams, 0, 0, address(0xdead), "")), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.loanToken = address(0xdead);
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.repay, (params, 0, 0, $.subvault, "")), false);
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.collateralToken = address(0xdead);
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.repay, (params, 0, 0, $.subvault, "")), false);
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.oracle = address(0xdead);
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.repay, (params, 0, 0, $.subvault, "")), false);
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.irm = address(0xdead);
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.repay, (params, 0, 0, $.subvault, "")), false);
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.lltv = params.lltv - 1;
            tmp[i++] =
                Call($.curator, $.morpho, 0, abi.encodeCall(IMorpho.repay, (params, 0, 0, $.subvault, "")), false);
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        /// @dev borrow from Morpho
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.borrow, (marketParams, 0, 0, $.subvault, $.subvault)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.borrow, (marketParams, 1 ether, 0, $.subvault, $.subvault)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.borrow, (marketParams, 0, 1 ether, $.subvault, $.subvault)),
                true
            );
            tmp[i++] = Call(
                address(0xdead),
                $.morpho,
                0,
                abi.encodeCall(IMorpho.borrow, (marketParams, 0, 0, $.subvault, $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                1 wei,
                abi.encodeCall(IMorpho.borrow, (marketParams, 0, 0, $.subvault, $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encode(IMorpho.borrow.selector, marketParams, 0, 0, $.subvault, $.subvault),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IMorpho.borrow, (marketParams, 0, 0, $.subvault, $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.borrow, (marketParams, 0, 0, address(0xdead), $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.borrow, (marketParams, 0, 0, $.subvault, address(0xdead))),
                false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.loanToken = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.borrow, (params, 0, 0, $.subvault, $.subvault)), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.collateralToken = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.borrow, (params, 0, 0, $.subvault, $.subvault)), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.oracle = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.borrow, (params, 0, 0, $.subvault, $.subvault)), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.irm = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.borrow, (params, 0, 0, $.subvault, $.subvault)), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.lltv = params.lltv - 1;
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.borrow, (params, 0, 0, $.subvault, $.subvault)), false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        /// @dev withdraw from Morpho
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdraw, (marketParams, 0, 0, $.subvault, $.subvault)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdraw, (marketParams, 1 ether, 0, $.subvault, $.subvault)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdraw, (marketParams, 0, 1 ether, $.subvault, $.subvault)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                1 wei,
                abi.encodeCall(IMorpho.withdraw, (marketParams, 0, 0, $.subvault, $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encode(IMorpho.withdraw.selector, marketParams, 0, 0, $.subvault, $.subvault),
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdraw, (marketParams, 0, 0, $.subvault, $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IMorpho.withdraw, (marketParams, 0, 0, $.subvault, $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdraw, (marketParams, 0, 0, address(0xdead), $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdraw, (marketParams, 0, 0, $.subvault, address(0xdead))),
                false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.loanToken = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.withdraw, (params, 0, 0, $.subvault, $.subvault)), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.collateralToken = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.withdraw, (params, 0, 0, $.subvault, $.subvault)), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.oracle = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.withdraw, (params, 0, 0, $.subvault, $.subvault)), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.irm = address(0xdead);
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.withdraw, (params, 0, 0, $.subvault, $.subvault)), false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.lltv = params.lltv - 1;
            tmp[i++] = Call(
                $.curator, $.morpho, 0, abi.encodeCall(IMorpho.withdraw, (params, 0, 0, $.subvault, $.subvault)), false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        /// @dev withdraw collateral from Morpho
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdrawCollateral, (marketParams, 0, $.subvault, $.subvault)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdrawCollateral, (marketParams, 1 ether, $.subvault, $.subvault)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                1 wei,
                abi.encodeCall(IMorpho.withdrawCollateral, (marketParams, 0, $.subvault, $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encode(IMorpho.withdrawCollateral.selector, marketParams, 0, $.subvault, $.subvault),
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdrawCollateral, (marketParams, 0, $.subvault, $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IMorpho.withdrawCollateral, (marketParams, 0, $.subvault, $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdrawCollateral, (marketParams, 0, address(0xdead), $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdrawCollateral, (marketParams, 0, $.subvault, address(0xdead))),
                false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.loanToken = address(0xdead);
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdrawCollateral, (params, 0, $.subvault, $.subvault)),
                false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.collateralToken = address(0xdead);
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdrawCollateral, (params, 0, $.subvault, $.subvault)),
                false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.oracle = address(0xdead);
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdrawCollateral, (params, 0, $.subvault, $.subvault)),
                false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.irm = address(0xdead);
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdrawCollateral, (params, 0, $.subvault, $.subvault)),
                false
            );
            params = IMorpho($.morpho).idToMarketParams($.marketId);
            params.lltv = params.lltv - 1;
            tmp[i++] = Call(
                $.curator,
                $.morpho,
                0,
                abi.encodeCall(IMorpho.withdrawCollateral, (params, 0, $.subvault, $.subvault)),
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
