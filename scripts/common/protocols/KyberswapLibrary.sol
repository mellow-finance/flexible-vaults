// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IMetaAggregationRouterV2} from "../interfaces/IMetaAggregationRouterV2.sol";
import "../interfaces/Imports.sol";

library KyberswapLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for IVerifier.VerificationPayload[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address kyberRouter;
        address[] assets;
    }

    function _getERC20Params(Info memory $) internal pure returns (ERC20Library.Info memory) {
        address[] memory to = new address[]($.assets.length);
        for (uint256 i = 0; i < $.assets.length; i++) {
            to[i] = $.kyberRouter;
        }
        return ERC20Library.Info({curator: $.curator, assets: $.assets, to: to});
    }

    function getKyberswapProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 iterator;
        leaves = new IVerifier.VerificationPayload[](50);

        iterator = leaves.insert(ERC20Library.getERC20Proofs(bitmaskVerifier, _getERC20Params($)), iterator);

        leaves[iterator++] = ProofLibrary.makeVerificationPayloadCompact(
            $.curator, $.kyberRouter, IMetaAggregationRouterV2.swap.selector
        );

        assembly {
            mstore(leaves, iterator)
        }
    }

    function getKyberswapDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 iterator;
        descriptions = new string[](50);

        iterator = ArraysLibrary.insert(descriptions, ERC20Library.getERC20Descriptions(_getERC20Params($)), iterator);

        ParameterLibrary.Parameter[] memory innerParameters;
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("IMetaAggregationRouterV2.swap(anyParams)")),
            ABILibrary.getABI(IMetaAggregationRouterV2.swap.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.kyberRouter), "0"),
            innerParameters.addAny("anyParams")
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getKyberswapCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 iterator;
        calls = new Call[][](50);

        iterator = calls.insert(ERC20Library.getERC20Calls(_getERC20Params($)), iterator);
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator, $.kyberRouter, 0, abi.encodeWithSelector(IMetaAggregationRouterV2.swap.selector, 0), true
            );
            tmp[i++] = Call(
                $.curator,
                $.kyberRouter,
                0,
                abi.encodeWithSelector(IMetaAggregationRouterV2.swap.selector, new bytes(128)),
                true
            );
            tmp[i++] = Call($.curator, $.kyberRouter, 0, abi.encodeWithSelector(0x59e50fed, 0), false); // swapGeneric (0x59e50fed)
            tmp[i++] = Call(
                address(0xdead),
                $.kyberRouter,
                0,
                abi.encodeWithSelector(IMetaAggregationRouterV2.swap.selector, 0),
                false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeWithSelector(IMetaAggregationRouterV2.swap.selector, 0), false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[iterator++] = tmp;
        }

        assembly {
            mstore(calls, iterator)
        }
    }
}
