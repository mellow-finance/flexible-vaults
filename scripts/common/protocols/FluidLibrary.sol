// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/IFluidVault.sol";
import "../interfaces/Imports.sol";

import "./ERC20Library.sol";

library FluidLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address fluidVault;
        uint256 nft;
    }

    function getFluidProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](3);
        uint256 iterator = 0;

        IFluidVault.ConstantViews memory data = IFluidVault($.fluidVault).constantsView();
        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(data.supplyToken, data.borrowToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.fluidVault, $.fluidVault))
                })
            ),
            iterator
        );

        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.fluidVault,
            0,
            abi.encodeCall(IFluidVault.operate, ($.nft, 0, 0, $.subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                false,
                true,
                abi.encodeCall(IFluidVault.operate, (type(uint256).max, 0, 0, address(type(uint160).max)))
            )
        );

        assembly {
            mstore(leaves, iterator)
        }
    }

    function getFluidDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](3);
        uint256 iterator = 0;

        IFluidVault.ConstantViews memory data = IFluidVault($.fluidVault).constantsView();
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(data.supplyToken, data.borrowToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.fluidVault, $.fluidVault))
                })
            ),
            iterator
        );
        ParameterLibrary.Parameter[] memory innerParameters = ParameterLibrary.build("nftId_", Strings.toString($.nft))
            .addAny("newCol_").addAny("newDebt_").add("to_", Strings.toHexString($.subvault));
        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "FluidVault.operate(nftId_=", Strings.toString($.nft), ", any, any, ", $.subvaultName, ")"
                )
            ),
            ABILibrary.getABI(IFluidVault.operate.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.fluidVault), "0"),
            innerParameters
        );
    }

    function getFluidCalls(Info memory $) internal view returns (Call[][] memory calls) {
        calls = new Call[][](2);

        IFluidVault.ConstantViews memory data = IFluidVault($.fluidVault).constantsView();
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            calls,
            ERC20Library.getERC20Calls(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(data.supplyToken, data.borrowToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.fluidVault, $.fluidVault))
                })
            ),
            iterator
        );

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.fluidVault, 0, abi.encodeCall(IFluidVault.operate, ($.nft, 0, 0, $.subvault)), true);
            tmp[i++] =
                Call($.curator, $.fluidVault, 0, abi.encodeCall(IFluidVault.operate, ($.nft, 1, 1, $.subvault)), true);
            tmp[i++] = Call(
                address(0xdead), $.fluidVault, 0, abi.encodeCall(IFluidVault.operate, ($.nft, 0, 0, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IFluidVault.operate, ($.nft, 0, 0, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, $.fluidVault, 1 wei, abi.encodeCall(IFluidVault.operate, ($.nft, 0, 0, $.subvault)), false
            );
            tmp[i++] =
                Call($.curator, $.fluidVault, 0, abi.encodeCall(IFluidVault.operate, (0, 0, 0, $.subvault)), false);
            tmp[i++] = Call(
                $.curator, $.fluidVault, 0, abi.encodeCall(IFluidVault.operate, ($.nft, 0, 0, address(0xdead))), false
            );
            tmp[i++] = Call(
                $.curator, $.fluidVault, 0, abi.encode(IFluidVault.operate.selector, $.nft, 0, 0, $.subvault), false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[iterator++] = tmp;
        }
    }
}
