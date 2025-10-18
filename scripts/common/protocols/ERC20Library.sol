// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import "../ProofLibrary.sol";
import "../interfaces/Imports.sol";

library ERC20Library {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address[] assets;
        address[] to;
    }

    function getERC20Proofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 length = $.assets.length;
        leaves = new IVerifier.VerificationPayload[](length);

        for (uint256 i = 0; i < length; i++) {
            address asset = $.assets[i];
            leaves[i] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                asset,
                0,
                abi.encodeCall(IERC20.approve, ($.to[i], 0)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
                )
            );
        }
    }

    function getERC20Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = $.assets.length;
        descriptions = new string[](length);
        ParameterLibrary.Parameter[] memory innerParameters;
        for (uint256 i = 0; i < $.assets.length; i++) {
            string memory asset = IERC20Metadata($.assets[i]).symbol();
            innerParameters = ParameterLibrary.build("to", Strings.toHexString($.to[i])).addAny("amount");
            descriptions[i] = JsonLibrary.toJson(
                string(abi.encodePacked("IERC20(", asset, ").approve(", Strings.toHexString($.to[i]), ", anyInt)")),
                ABILibrary.getABI(IERC20.approve.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.assets[i]), "0"),
                innerParameters
            );
        }
    }

    function getCowSwapCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][]($.assets.length);
        for (uint256 j = 0; j < $.assets.length; j++) {
            address asset = $.assets[j];
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, ($.to[j], 0)), true);
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, ($.to[j], 1 ether)), true);
                tmp[i++] = Call(address(0xdead), asset, 0, abi.encodeCall(IERC20.approve, ($.to[j], 1 ether)), false);
                tmp[i++] =
                    Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.to[j], 1 ether)), false);
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
                tmp[i++] = Call($.curator, asset, 1 wei, abi.encodeCall(IERC20.approve, ($.to[j], 1 ether)), false);
                tmp[i++] = Call($.curator, asset, 0, abi.encode(IERC20.approve.selector, $.to[j], 1 ether), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }
        }
    }
}
