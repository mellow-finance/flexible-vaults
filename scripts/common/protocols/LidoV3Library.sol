// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/Imports.sol";

import "./ERC20Library.sol";

import "../interfaces/ILidoV3Dashboard.sol";

library LidoV3Library {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address wsteth;
        address curator;
        address subvault;
        string subvaultName;
        address dashboard;
        string dashboardName;
    }

    function _getERC20Info(Info memory $) internal pure returns (ERC20Library.Info memory) {
        return ERC20Library.Info({
            curator: $.curator,
            assets: ArraysLibrary.makeAddressArray(abi.encode($.wsteth)),
            to: ArraysLibrary.makeAddressArray(abi.encode($.dashboard))
        });
    }

    function getLidoV3Proofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            Allowed calls:
            1. wstETH.approve(dashboard)
            2. dashboard.fund{value: any}()
            3. dashboard.withdraw(subvault, any)
            4. dashboard.mintWstETH{value: any}(subvault, any)
            5. dashboard.burnWstETH(any)
            6. dashboard.rebalanceVaultWithShares(any)
            7. dashboard.rebalanceVaultWithEther{value: any}(any)
        */
        leaves = new IVerifier.VerificationPayload[](10);
        uint256 iterator = 0;

        iterator =
            ArraysLibrary.insert(leaves, ERC20Library.getERC20Proofs(bitmaskVerifier, _getERC20Info($)), iterator);

        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.dashboard,
            0,
            abi.encodeCall(ILidoV3Dashboard.fund, ()),
            ProofLibrary.makeBitmask(true, true, false, true, abi.encodeCall(ILidoV3Dashboard.fund, ()))
        );
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.dashboard,
            0,
            abi.encodeCall(ILidoV3Dashboard.withdraw, ($.subvault, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ILidoV3Dashboard.withdraw, (address(type(uint160).max), 0))
            )
        );
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.dashboard,
            0,
            abi.encodeCall(ILidoV3Dashboard.mintWstETH, ($.subvault, 0)),
            ProofLibrary.makeBitmask(
                true, true, false, true, abi.encodeCall(ILidoV3Dashboard.mintWstETH, (address(type(uint160).max), 0))
            )
        );
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.dashboard,
            0,
            abi.encodeCall(ILidoV3Dashboard.burnWstETH, (0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(ILidoV3Dashboard.burnWstETH, (0)))
        );
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.dashboard,
            0,
            abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithShares, (0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithShares, (0))
            )
        );
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.dashboard,
            0,
            abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithEther, (0)),
            ProofLibrary.makeBitmask(
                true, true, false, true, abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithEther, (0))
            )
        );

        assembly {
            mstore(leaves, iterator)
        }
    }

    function getLidoV3Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](10);
        uint256 iterator = 0;

        /*
            Allowed calls:
            1. wstETH.approve(dashboard)
            2. dashboard.fund{value: any}()
            3. dashboard.withdraw(subvault, any)
            4. dashboard.mintWstETH{value: any}(subvault, any)
            5. dashboard.burnWstETH(any)
            6. dashboard.rebalanceVaultWithShares(any)
            7. dashboard.rebalanceVaultWithEther{value: any}(any)
        */

        iterator = ArraysLibrary.insert(descriptions, ERC20Library.getERC20Descriptions(_getERC20Info($)), iterator);

        ParameterLibrary.Parameter[] memory innerParameters;
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("LidoV3Dashboard(", $.dashboardName, ").fund{value: any}()")),
            ABILibrary.getABI(ILidoV3Dashboard.fund.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.dashboard), "any"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("claimer", Strings.toHexString($.subvault)).addAny("amount");
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("LidoV3Dashboard(", $.dashboardName, ").withdraw(", $.subvaultName, ", any)")),
            ABILibrary.getABI(ILidoV3Dashboard.withdraw.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.dashboard), "0"),
            innerParameters
        );

        innerParameters =
            ParameterLibrary.build("recipient_", Strings.toHexString($.subvault)).addAny("amountOfWstETH_");
        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "LidoV3Dashboard(", $.dashboardName, ").mintWstETH{value: any}(", $.subvaultName, ", any)"
                )
            ),
            ABILibrary.getABI(ILidoV3Dashboard.mintWstETH.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.dashboard), "any"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("amountOfWstETH_");
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("LidoV3Dashboard(", $.dashboardName, ").burnWstETH(any)")),
            ABILibrary.getABI(ILidoV3Dashboard.burnWstETH.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.dashboard), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("shares_");
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("LidoV3Dashboard(", $.dashboardName, ").rebalanceVaultWithShares(any)")),
            ABILibrary.getABI(ILidoV3Dashboard.rebalanceVaultWithShares.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.dashboard), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("ether_");
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("LidoV3Dashboard(", $.dashboardName, ").rebalanceVaultWithEther{value: any}(any)")),
            ABILibrary.getABI(ILidoV3Dashboard.rebalanceVaultWithEther.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.dashboard), "any"),
            innerParameters
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getLidoV3Calls(Info memory $) internal pure returns (Call[][] memory calls) {
        calls = new Call[][](10);

        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(calls, ERC20Library.getERC20Calls(_getERC20Info($)), iterator);

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.fund, ()), true);
            tmp[i++] = Call($.curator, $.dashboard, 1 ether, abi.encodeCall(ILidoV3Dashboard.fund, ()), true);
            tmp[i++] = Call(address(0xdead), $.dashboard, 1 ether, abi.encodeCall(ILidoV3Dashboard.fund, ()), false);
            tmp[i++] = Call($.curator, address(0xdead), 1 ether, abi.encodeCall(ILidoV3Dashboard.fund, ()), false);
            tmp[i++] = Call($.curator, $.dashboard, 1 ether, abi.encode(ILidoV3Dashboard.fund.selector), false);

            assembly {
                mstore(tmp, i)
            }
            calls[iterator++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.withdraw, ($.subvault, 0)), true);
            tmp[i++] =
                Call($.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.withdraw, ($.subvault, 1 ether)), true);
            tmp[i++] = Call(
                address(0xdead), $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.withdraw, ($.subvault, 1 ether)), false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(ILidoV3Dashboard.withdraw, ($.subvault, 1 ether)), false
            );
            tmp[i++] = Call(
                $.curator, $.dashboard, 1 wei, abi.encodeCall(ILidoV3Dashboard.withdraw, ($.subvault, 1 ether)), false
            );
            tmp[i++] = Call(
                $.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.withdraw, (address(0xdead), 1 ether)), false
            );
            tmp[i++] = Call(
                $.curator, $.dashboard, 0, abi.encode(ILidoV3Dashboard.withdraw.selector, $.subvault, 1 ether), false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[iterator++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.mintWstETH, ($.subvault, 0)), true);
            tmp[i++] = Call(
                $.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.mintWstETH, ($.subvault, 1 ether)), true
            );
            tmp[i++] = Call(
                $.curator,
                $.dashboard,
                1 ether,
                abi.encodeCall(ILidoV3Dashboard.mintWstETH, ($.subvault, 1 ether)),
                true
            );
            tmp[i++] = Call(
                $.curator, $.dashboard, 1 ether, abi.encodeCall(ILidoV3Dashboard.mintWstETH, ($.subvault, 0)), true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.dashboard,
                1 ether,
                abi.encodeCall(ILidoV3Dashboard.mintWstETH, ($.subvault, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 1 ether, abi.encodeCall(ILidoV3Dashboard.mintWstETH, ($.subvault, 0)), false
            );
            tmp[i++] = Call(
                $.curator,
                $.dashboard,
                1 ether,
                abi.encodeCall(ILidoV3Dashboard.mintWstETH, (address(0xdead), 0)),
                false
            );
            tmp[i++] = Call(
                $.curator, $.dashboard, 1 ether, abi.encode(ILidoV3Dashboard.mintWstETH.selector, $.subvault, 0), false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[iterator++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.burnWstETH, (0)), true);
            tmp[i++] = Call($.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.burnWstETH, (1 ether)), true);

            tmp[i++] =
                Call(address(0xdead), $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.burnWstETH, (1 ether)), false);
            tmp[i++] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(ILidoV3Dashboard.burnWstETH, (1 ether)), false);
            tmp[i++] =
                Call($.curator, $.dashboard, 1 wei, abi.encodeCall(ILidoV3Dashboard.burnWstETH, (1 ether)), false);
            tmp[i++] = Call($.curator, $.dashboard, 0, abi.encode(ILidoV3Dashboard.burnWstETH.selector, 1 ether), false);

            assembly {
                mstore(tmp, i)
            }
            calls[iterator++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithShares, (0)), true);
            tmp[i++] = Call(
                $.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithShares, (1 ether)), true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.dashboard,
                0,
                abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithShares, (1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithShares, (1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.dashboard,
                1 wei,
                abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithShares, (1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.dashboard,
                0,
                abi.encode(ILidoV3Dashboard.rebalanceVaultWithShares.selector, 1 ether),
                false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[iterator++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithEther, (0)), true);
            tmp[i++] = Call(
                $.curator, $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithEther, (1 ether)), true
            );
            tmp[i++] = Call(
                $.curator, $.dashboard, 1 ether, abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithEther, (0)), true
            );
            tmp[i++] = Call(
                $.curator,
                $.dashboard,
                1 ether,
                abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithEther, (1 ether)),
                true
            );

            tmp[i++] = Call(
                address(0xdead), $.dashboard, 0, abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithEther, (0)), false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(ILidoV3Dashboard.rebalanceVaultWithEther, (0)), false
            );
            tmp[i++] =
                Call($.curator, $.dashboard, 0, abi.encode(ILidoV3Dashboard.rebalanceVaultWithEther.selector, 0), false);
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
