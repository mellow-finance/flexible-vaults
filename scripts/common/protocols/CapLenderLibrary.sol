// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";

import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import "../ParameterLibrary.sol";
import "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";

import "../interfaces/ICapLender.sol";
import "../interfaces/Imports.sol";

library CapLenderLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address asset;
        address lender;
        address subvault;
        string subvaultName;
        address curator;
    }

    function getCapLenderProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 length = 3;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        index = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.asset)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.lender))
                })
            ),
            index
        );

        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.lender,
            0,
            abi.encodeCall(ICapLender.borrow, ($.asset, 0, $.subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(ICapLender.borrow, (address(type(uint160).max), 0, address(type(uint160).max)))
            )
        );

        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.lender,
            0,
            abi.encodeCall(ICapLender.repay, ($.asset, 0, $.subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(ICapLender.repay, (address(type(uint160).max), 0, address(type(uint160).max)))
            )
        );
    }

    function getCapLenderDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = 3;
        descriptions = new string[](length);
        uint256 iterator = ArraysLibrary.insert(
            descriptions,
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.asset)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.lender))
                })
            ),
            0
        );

        ParameterLibrary.Parameter[] memory innerParameters;
        string memory assetSymbol = IERC20Metadata($.asset).symbol();

        innerParameters = ParameterLibrary.build("_asset", Strings.toHexString($.asset)).addAny("_amount").add(
            "_receiver", Strings.toHexString($.subvault)
        );
        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "ICapLender(",
                    Strings.toHexString($.lender),
                    ").borrow(",
                    assetSymbol,
                    ", anyInt, ",
                    $.subvaultName,
                    ")"
                )
            ),
            ABILibrary.getABI(ICapLender.borrow.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.asset), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("_asset", Strings.toHexString($.asset)).addAny("_amount").add(
            "_agent", Strings.toHexString($.subvault)
        );
        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked("ICapLender(", assetSymbol, ").repay(", assetSymbol, ", anyInt, ", $.subvaultName, ")")
            ),
            ABILibrary.getABI(ICapLender.repay.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.asset), "0"),
            innerParameters
        );
    }

    function getCapLenderCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][](3);
        index = ArraysLibrary.insert(
            calls,
            ERC20Library.getERC20Calls(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.asset)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.lender))
                })
            ),
            index
        );

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.lender, 0, abi.encodeCall(ICapLender.borrow, ($.asset, 0, $.subvault)), true);
            tmp[i++] =
                Call($.curator, $.lender, 0, abi.encodeCall(ICapLender.borrow, ($.asset, 1 ether, $.subvault)), true);

            tmp[i++] = Call(
                address(0xdead), $.lender, 0, abi.encodeCall(ICapLender.borrow, ($.asset, 1 ether, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(ICapLender.borrow, ($.asset, 1 ether, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, $.lender, 1 wei, abi.encodeCall(ICapLender.borrow, ($.asset, 1 ether, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, $.lender, 0, abi.encodeCall(ICapLender.borrow, (address(0xdead), 1 ether, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, $.lender, 0, abi.encodeCall(ICapLender.borrow, ($.asset, 1 ether, address(0xdead))), false
            );
            tmp[i++] = Call(
                $.curator, $.lender, 0, abi.encode(ICapLender.borrow.selector, $.asset, 1 ether, $.subvault), false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.lender, 0, abi.encodeCall(ICapLender.repay, ($.asset, 0, $.subvault)), true);
            tmp[i++] =
                Call($.curator, $.lender, 0, abi.encodeCall(ICapLender.repay, ($.asset, 1 ether, $.subvault)), true);

            tmp[i++] = Call(
                address(0xdead), $.lender, 0, abi.encodeCall(ICapLender.repay, ($.asset, 1 ether, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(ICapLender.repay, ($.asset, 1 ether, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, $.lender, 1 wei, abi.encodeCall(ICapLender.repay, ($.asset, 1 ether, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, $.lender, 0, abi.encodeCall(ICapLender.repay, (address(0xdead), 1 ether, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, $.lender, 0, abi.encodeCall(ICapLender.repay, ($.asset, 1 ether, address(0xdead))), false
            );
            tmp[i++] =
                Call($.curator, $.lender, 0, abi.encode(ICapLender.repay.selector, $.asset, 1 ether, $.subvault), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
    }
}
