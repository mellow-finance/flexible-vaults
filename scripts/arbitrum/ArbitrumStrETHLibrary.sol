// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/ABILibrary.sol";

import "../common/JsonLibrary.sol";
import "../common/ParameterLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import {IL2GatewayRouter} from "../common/interfaces/IL2GatewayRouter.sol";
import {BitmaskVerifier, Call, IVerifier, SubvaultCalls} from "../common/interfaces/Imports.sol";
import {Constants} from "./Constants.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library ArbitrumStrETHLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address ethereumAsset;
        address ethereumSubvault;
        address l2GatewayRouter;
        string name;
    }

    function getArbitrumStrETHProofs(Info memory info)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](1);
        leaves[0] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            info.curator,
            info.l2GatewayRouter,
            0,
            abi.encodeCall(
                IL2GatewayRouter.outboundTransfer, (info.ethereumAsset, info.ethereumSubvault, 0, new bytes(0))
            ),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    IL2GatewayRouter.outboundTransfer,
                    (address(type(uint160).max), address(type(uint160).max), 0, new bytes(0))
                )
            )
        );
        (merkleRoot, leaves) = ProofLibrary.generateMerkleProofs(leaves);
    }

    function getArbitrumStrETHDescriptions(Info memory info) internal pure returns (string[] memory descriptions) {
        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = ParameterLibrary.add2(
            "l1Token", Strings.toHexString(info.ethereumAsset), "to", Strings.toHexString(info.ethereumSubvault)
        );
        innerParameters = innerParameters.add2("amount", "any", "data", "0x");
        descriptions = new string[](1);
        descriptions[0] = JsonLibrary.toJson(
            string(
                abi.encodePacked("L2GatewayRouter.outboundTransfer(WstETH_ethereum, ethereumSubvault0, any, 0, 0, 0x)")
            ),
            ABILibrary.getABI(IL2GatewayRouter.outboundTransfer.selector),
            ParameterLibrary.build(Strings.toHexString(info.curator), Strings.toHexString(info.l2GatewayRouter), "0"),
            innerParameters
        );
    }

    function getArbitrumStrETHCalls(Info memory info, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;

        Call[] memory tmp = new Call[](10);
        uint256 i = 0;
        tmp[i++] = Call(
            info.curator,
            info.l2GatewayRouter,
            0,
            abi.encodeCall(
                IL2GatewayRouter.outboundTransfer, (info.ethereumAsset, info.ethereumSubvault, 0, new bytes(0))
            ),
            true
        );

        tmp[i++] = Call(
            info.curator,
            info.l2GatewayRouter,
            0,
            abi.encodeCall(
                IL2GatewayRouter.outboundTransfer, (info.ethereumAsset, info.ethereumSubvault, 1 ether, new bytes(0))
            ),
            true
        );

        tmp[i++] = Call(
            address(0xdead),
            info.l2GatewayRouter,
            0,
            abi.encodeCall(
                IL2GatewayRouter.outboundTransfer, (info.ethereumAsset, info.ethereumSubvault, 1 ether, new bytes(0))
            ),
            false
        );

        tmp[i++] = Call(
            info.curator,
            address(0xdead),
            0,
            abi.encodeCall(
                IL2GatewayRouter.outboundTransfer, (info.ethereumAsset, info.ethereumSubvault, 1 ether, new bytes(0))
            ),
            false
        );
        tmp[i++] = Call(
            info.curator,
            info.l2GatewayRouter,
            1 wei,
            abi.encodeCall(
                IL2GatewayRouter.outboundTransfer, (info.ethereumAsset, info.ethereumSubvault, 1 ether, new bytes(0))
            ),
            false
        );
        tmp[i++] = Call(
            info.curator,
            info.l2GatewayRouter,
            0,
            abi.encodeCall(
                IL2GatewayRouter.outboundTransfer, (address(0xdead), info.ethereumSubvault, 1 ether, new bytes(0))
            ),
            false
        );
        tmp[i++] = Call(
            info.curator,
            info.l2GatewayRouter,
            0,
            abi.encodeCall(
                IL2GatewayRouter.outboundTransfer, (info.ethereumAsset, address(0xdead), 1 ether, new bytes(0))
            ),
            false
        );

        assembly {
            mstore(tmp, i)
        }
        calls.calls = new Call[][](1);
        calls.calls[0] = tmp;
    }
}
