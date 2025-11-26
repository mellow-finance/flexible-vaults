// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import "../ParameterLibrary.sol";
import "../ProofLibrary.sol";
import "../interfaces/Imports.sol";

import {ISymbioticVault as IVault} from "../../../src/strategies/SymbioticStrategy.sol";

library SymbioticLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address subvault;
        string subvaultName;
        address curator;
        address symbioticVault;
    }

    function getSymbioticProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 length = 4;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            IVault($.symbioticVault).collateral(),
            0,
            abi.encodeCall(IERC20.approve, ($.symbioticVault, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.symbioticVault,
            0,
            abi.encodeCall(IVault.deposit, ($.subvault, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IVault.deposit, (address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.symbioticVault,
            0,
            abi.encodeCall(IVault.withdraw, ($.subvault, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IVault.withdraw, (address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.symbioticVault,
            0,
            abi.encodeCall(IVault.claim, ($.subvault, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IVault.claim, (address(type(uint160).max), 0))
            )
        );

        assembly {
            mstore(leaves, index)
        }
    }

    function getSymbioticDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = 4;
        descriptions = new string[](length);
        uint256 index = 0;

        ParameterLibrary.Parameter[] memory innerParameters;
        address collateral = IVault($.symbioticVault).collateral();

        innerParameters = ParameterLibrary.buildERC20(Strings.toHexString($.symbioticVault));
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IERC20(",
                    IERC20Metadata(collateral).symbol(),
                    ").approve(SymbioticVault(",
                    Strings.toHexString($.symbioticVault),
                    "), anyInt)"
                )
            ),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(collateral), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("onBehalfOf", Strings.toHexString($.subvault)).add("amount", "any");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "ISymbioticVault(",
                    Strings.toHexString($.symbioticVault),
                    ").deposit(",
                    Strings.toHexString($.subvault),
                    ", anyInt)"
                )
            ),
            ABILibrary.getABI(IVault.deposit.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.symbioticVault), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("claimer", Strings.toHexString($.subvault)).add("amount", "any");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "ISymbioticVault(",
                    Strings.toHexString($.symbioticVault),
                    ").withdraw(",
                    Strings.toHexString($.subvault),
                    ", anyInt)"
                )
            ),
            ABILibrary.getABI(IVault.withdraw.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.symbioticVault), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("recipient", Strings.toHexString($.subvault)).add("epoch", "any");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "ISymbioticVault(",
                    Strings.toHexString($.symbioticVault),
                    ").claim(",
                    Strings.toHexString($.subvault),
                    ", anyInt)"
                )
            ),
            ABILibrary.getABI(IVault.claim.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.symbioticVault), "0"),
            innerParameters
        );
    }

    function getSymbioticCalls(Info memory $) internal view returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][](4);
        address underlyingAsset = IVault($.symbioticVault).collateral();
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, underlyingAsset, 0, abi.encodeCall(IERC20.approve, ($.symbioticVault, 0)), true);
            tmp[i++] =
                Call($.curator, underlyingAsset, 0, abi.encodeCall(IERC20.approve, ($.symbioticVault, 1 ether)), true);
            tmp[i++] = Call(
                address(0xdead), underlyingAsset, 0, abi.encodeCall(IERC20.approve, ($.symbioticVault, 1 ether)), false
            );
            tmp[i++] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.symbioticVault, 1 ether)), false);
            tmp[i++] =
                Call($.curator, underlyingAsset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
            tmp[i++] = Call(
                $.curator, underlyingAsset, 1 wei, abi.encodeCall(IERC20.approve, ($.symbioticVault, 1 ether)), false
            );
            tmp[i++] = Call(
                $.curator, underlyingAsset, 0, abi.encode(IERC20.approve.selector, $.symbioticVault, 1 ether), false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        // SymbioticVault deposit
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.symbioticVault, 0, abi.encodeCall(IVault.deposit, ($.subvault, 0)), true);
            tmp[i++] = Call($.curator, $.symbioticVault, 0, abi.encodeCall(IVault.deposit, ($.subvault, 1 ether)), true);

            tmp[i++] =
                Call(address(0xdead), $.symbioticVault, 0, abi.encodeCall(IVault.deposit, ($.subvault, 1 ether)), false);
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IVault.deposit, ($.subvault, 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.symbioticVault, 1 wei, abi.encodeCall(IVault.deposit, ($.subvault, 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.symbioticVault, 0, abi.encodeCall(IVault.deposit, (address(0xdead), 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.symbioticVault, 0, abi.encode(IVault.deposit.selector, $.subvault, 1 ether), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        // SymbioticVault withdraw
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.symbioticVault, 0, abi.encodeCall(IVault.withdraw, ($.subvault, 0)), true);
            tmp[i++] =
                Call($.curator, $.symbioticVault, 0, abi.encodeCall(IVault.withdraw, ($.subvault, 1 ether)), true);

            tmp[i++] = Call(
                address(0xdead), $.symbioticVault, 0, abi.encodeCall(IVault.withdraw, ($.subvault, 1 ether)), false
            );
            tmp[i++] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(IVault.withdraw, ($.subvault, 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.symbioticVault, 1 wei, abi.encodeCall(IVault.withdraw, ($.subvault, 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.symbioticVault, 0, abi.encodeCall(IVault.withdraw, (address(0xdead), 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.symbioticVault, 0, abi.encode(IVault.withdraw.selector, $.subvault, 1 ether), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        // SymbioticVault claim
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.symbioticVault, 0, abi.encodeCall(IVault.claim, ($.subvault, 0)), true);
            tmp[i++] = Call($.curator, $.symbioticVault, 0, abi.encodeCall(IVault.claim, ($.subvault, 1 ether)), true);

            tmp[i++] =
                Call(address(0xdead), $.symbioticVault, 0, abi.encodeCall(IVault.claim, ($.subvault, 1 ether)), false);
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IVault.claim, ($.subvault, 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.symbioticVault, 1 wei, abi.encodeCall(IVault.claim, ($.subvault, 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.symbioticVault, 0, abi.encodeCall(IVault.claim, (address(0xdead), 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.symbioticVault, 0, abi.encode(IVault.claim.selector, $.subvault, 1 ether), false);

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
