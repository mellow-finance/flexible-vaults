// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import "../ParameterLibrary.sol";
import "../ProofLibrary.sol";
import "../interfaces/Imports.sol";

import {IBracketVaultV2} from "../interfaces/IBracketVaultV2.sol";

library BracketVaultLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address subvault;
        string subvaultName;
        address curator;
        address vault;
    }

    function getBracketVaultProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
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
            IBracketVaultV2($.vault).token(),
            0,
            abi.encodeCall(IERC20.approve, ($.vault, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.vault,
            0,
            abi.encodeCall(IBracketVaultV2.deposit, (0, $.subvault)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IBracketVaultV2.deposit, (0, address(type(uint160).max)))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.vault,
            0,
            abi.encodeCall(IBracketVaultV2.withdraw, (0, bytes32(0))),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IBracketVaultV2.withdraw, (0, bytes32(0))))
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.vault,
            0,
            abi.encodeCall(IBracketVaultV2.claimWithdrawal, (0, 0, 0, bytes32(0))),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IBracketVaultV2.claimWithdrawal, (0, 0, 0, bytes32(0)))
            )
        );
    }

    function getBracketVaultDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](4);
        uint256 index = 0;

        address token = IBracketVaultV2($.vault).token();
        string memory symbol = IERC20Metadata(token).symbol();

        ParameterLibrary.Parameter[] memory innerParameters;

        innerParameters = ParameterLibrary.buildERC20(Strings.toHexString($.vault));
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IERC20(", symbol, ").approve(IBracketVaultV2(", IERC20Metadata($.vault).name(), "), anyInt)"
                )
            ),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(token), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("assets").add("destination", Strings.toHexString($.subvault));
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IBracketVaultV2(", IERC20Metadata($.vault).name(), ").deposit(any, ", $.subvaultName, ")"
                )
            ),
            ABILibrary.getABI(IBracketVaultV2.deposit.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.vault), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("assets", "any").addAny("salt");
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("IBracketVaultV2(", IERC20Metadata($.vault).name(), ").withdraw(any, any)")),
            ABILibrary.getABI(IBracketVaultV2.withdraw.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.vault), "0"),
            innerParameters
        );

        innerParameters =
            ParameterLibrary.buildAny("shares").add2("claimEpoch", "any", "timestamp", "any").addAny("salt");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IBracketVaultV2(", IERC20Metadata($.vault).name(), ").claimWithdrawal(any, any, any, any)"
                )
            ),
            ABILibrary.getABI(IBracketVaultV2.claimWithdrawal.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.vault), "0"),
            innerParameters
        );
    }

    function getBracketVaultCalls(Info memory $) internal view returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][](4);

        {
            address token = IBracketVaultV2($.vault).token();
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, token, 0, abi.encodeCall(IERC20.approve, ($.vault, 0)), true);
            tmp[i++] = Call($.curator, token, 0, abi.encodeCall(IERC20.approve, ($.vault, 1 ether)), true);
            tmp[i++] = Call(address(0xdead), token, 0, abi.encodeCall(IERC20.approve, ($.vault, 1 ether)), false);
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.vault, 1 ether)), false);
            tmp[i++] = Call($.curator, token, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
            tmp[i++] = Call($.curator, token, 1 wei, abi.encodeCall(IERC20.approve, ($.vault, 1 ether)), false);
            tmp[i++] = Call($.curator, token, 0, abi.encode(IERC20.approve.selector, $.vault, 1 ether), false);
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.vault, 0, abi.encodeCall(IBracketVaultV2.deposit, (0, $.subvault)), true);
            tmp[i++] = Call($.curator, $.vault, 0, abi.encodeCall(IBracketVaultV2.deposit, (1 ether, $.subvault)), true);
            tmp[i++] =
                Call(address(0xdead), $.vault, 0, abi.encodeCall(IBracketVaultV2.deposit, (1 ether, $.subvault)), false);
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IBracketVaultV2.deposit, (1 ether, $.subvault)), false
            );
            tmp[i++] =
                Call($.curator, $.vault, 1 wei, abi.encodeCall(IBracketVaultV2.deposit, (1 ether, $.subvault)), false);
            tmp[i++] =
                Call($.curator, $.vault, 0, abi.encodeCall(IBracketVaultV2.deposit, (1 ether, address(0xdead))), false);
            tmp[i++] =
                Call($.curator, $.vault, 0, abi.encode(IBracketVaultV2.deposit.selector, 1 ether, $.subvault), false);
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.vault, 0, abi.encodeCall(IBracketVaultV2.withdraw, (0, bytes32(0))), true);
            tmp[i++] = Call(
                $.curator,
                $.vault,
                0,
                abi.encodeCall(IBracketVaultV2.withdraw, (1 ether, bytes32(type(uint256).max))),
                true
            );
            tmp[i++] = Call(
                address(0xdead),
                $.vault,
                0,
                abi.encodeCall(IBracketVaultV2.withdraw, (1 ether, bytes32(type(uint256).max))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IBracketVaultV2.withdraw, (1 ether, bytes32(type(uint256).max))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                1 wei,
                abi.encodeCall(IBracketVaultV2.withdraw, (1 ether, bytes32(type(uint256).max))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                0,
                abi.encode(IBracketVaultV2.withdraw.selector, 1 ether, bytes32(type(uint256).max)),
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
            tmp[i++] = Call(
                $.curator, $.vault, 0, abi.encodeCall(IBracketVaultV2.claimWithdrawal, (0, 0, 0, bytes32(0))), true
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                0,
                abi.encodeCall(IBracketVaultV2.claimWithdrawal, (1, 1, 1, bytes32(uint256(1)))),
                true
            );
            tmp[i++] = Call(
                address(0xdead),
                $.vault,
                0,
                abi.encodeCall(IBracketVaultV2.claimWithdrawal, (1, 1, 1, bytes32(uint256(1)))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IBracketVaultV2.claimWithdrawal, (1, 1, 1, bytes32(uint256(1)))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                1 wei,
                abi.encodeCall(IBracketVaultV2.claimWithdrawal, (1, 1, 1, bytes32(uint256(1)))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                0,
                abi.encode(IBracketVaultV2.claimWithdrawal.selector, 1, 1, 1, bytes32(uint256(1))),
                false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
    }
}
