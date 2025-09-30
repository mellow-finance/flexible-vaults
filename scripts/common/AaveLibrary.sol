// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "./ABILibrary.sol";
import {JsonLibrary} from "./JsonLibrary.sol";
import "./ParameterLibrary.sol";
import "./ProofLibrary.sol";
import "./interfaces/IAavePoolV3.sol";
import "./interfaces/Imports.sol";

library AaveLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address subvault;
        string subvaultName;
        address curator;
        address aaveInstance;
        string aaveInstanceName;
        address[] collaterals;
        address[] loans;
        uint8 categoryId;
    }

    function getAaveProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 length = ($.collaterals.length + $.loans.length) * 3 + 1;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.aaveInstance,
            0,
            abi.encodeCall(IAavePoolV3.setUserEMode, ($.categoryId)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IAavePoolV3.setUserEMode, (type(uint8).max))
            )
        );
        for (uint256 i = 0; i < $.collaterals.length; i++) {
            address asset = $.collaterals[i];
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                asset,
                0,
                abi.encodeCall(IERC20.approve, ($.aaveInstance, 0)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
                )
            );
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.aaveInstance,
                0,
                abi.encodeCall(IAavePoolV3.supply, (asset, 0, $.subvault, 0)),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(IAavePoolV3.supply, (address(type(uint160).max), 0, address(type(uint160).max), 0))
                )
            );
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.aaveInstance,
                0,
                abi.encodeCall(IAavePoolV3.withdraw, (asset, 0, $.subvault)),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(IAavePoolV3.withdraw, (address(type(uint160).max), 0, address(type(uint160).max)))
                )
            );
        }
        for (uint256 i = 0; i < $.loans.length; i++) {
            address asset = $.loans[i];
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                asset,
                0,
                abi.encodeCall(IERC20.approve, ($.aaveInstance, 0)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
                )
            );

            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.aaveInstance,
                0,
                abi.encodeCall(IAavePoolV3.borrow, (asset, 0, 2, 0, $.subvault)),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(
                        IAavePoolV3.borrow,
                        (address(type(uint160).max), 0, type(uint256).max, 0, address(type(uint160).max))
                    )
                )
            );
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.aaveInstance,
                0,
                abi.encodeCall(IAavePoolV3.repay, (asset, 0, 2, $.subvault)),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(
                        IAavePoolV3.repay,
                        (address(type(uint160).max), 0, type(uint256).max, address(type(uint160).max))
                    )
                )
            );
        }
    }

    // God, please, fix stack-too-deep 🙏
    function getAaveDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = ($.collaterals.length + $.loans.length) * 3 + 1;
        descriptions = new string[](length);
        uint256 index = 0;

        ParameterLibrary.Parameter[] memory innerParameters =
            ParameterLibrary.build("categoryId", Strings.toString($.categoryId));
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "AaveInstance(",
                    $.aaveInstanceName,
                    ").setUserEMode(categoryId=",
                    Strings.toString($.categoryId),
                    ")"
                )
            ),
            ABILibrary.getABI(IAavePoolV3.setUserEMode.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.aaveInstance), "0"),
            innerParameters
        );

        for (uint256 i = 0; i < $.collaterals.length; i++) {
            string memory asset = IERC20Metadata($.collaterals[i]).symbol();

            innerParameters = ParameterLibrary.build("to", Strings.toHexString($.aaveInstance)).addAny("amount");
            descriptions[index++] = JsonLibrary.toJson(
                string(abi.encodePacked("IERC20(", asset, ").approve(AaveInstance(", $.aaveInstanceName, "), anyInt)")),
                ABILibrary.getABI(IERC20.approve.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.collaterals[i]), "0"),
                innerParameters
            );

            innerParameters = ParameterLibrary.add2("asset", Strings.toHexString($.collaterals[i]), "amount", "any")
                .add2("onBehalfOf", Strings.toHexString($.subvault), "referralCode", "0");
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "AaveInstance(",
                        $.aaveInstanceName,
                        ").supply(",
                        asset,
                        ", anyInt, ",
                        $.subvaultName,
                        ", anyInt)"
                    )
                ),
                ABILibrary.getABI(IAavePoolV3.supply.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.aaveInstance), "0"),
                innerParameters
            );

            innerParameters = ParameterLibrary.add2("asset", Strings.toHexString($.collaterals[i]), "amount", "any").add(
                "to", Strings.toHexString($.subvault)
            );
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "AaveInstance(", $.aaveInstanceName, ").withdraw(", asset, ", anyInt, ", $.subvaultName, ")"
                    )
                ),
                ABILibrary.getABI(IAavePoolV3.withdraw.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.aaveInstance), "0"),
                innerParameters
            );
        }
        for (uint256 i = 0; i < $.loans.length; i++) {
            string memory asset = IERC20Metadata($.loans[i]).symbol();

            innerParameters = ParameterLibrary.build("to", Strings.toHexString($.aaveInstance)).addAny("amount");
            descriptions[index++] = JsonLibrary.toJson(
                string(abi.encodePacked("IERC20(", asset, ").approve(AaveInstance(", $.aaveInstanceName, "), anyInt)")),
                ABILibrary.getABI(IERC20.approve.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.loans[i]), "0"),
                innerParameters
            );
            innerParameters = ParameterLibrary.add2("asset", Strings.toHexString($.loans[i]), "amount", "any").add2(
                "interestRateMode", "2", "referralCode", "0"
            );
            innerParameters = innerParameters.add("onBehalfOf", Strings.toHexString($.subvault));
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "AaveInstance(",
                        $.aaveInstanceName,
                        ").borrow(",
                        asset,
                        ", anyInt, interestRateMode=2, anyInt, ",
                        $.subvaultName,
                        ")"
                    )
                ),
                ABILibrary.getABI(IAavePoolV3.borrow.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.aaveInstance), "0"),
                innerParameters
            );
            innerParameters = ParameterLibrary.add2("asset", Strings.toHexString($.loans[i]), "amount", "any").add2(
                "interestRateMode", "2", "onBehalfOf", Strings.toHexString($.subvault)
            );
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "AaveInstance(", $.aaveInstanceName, ").repay(", asset, ", anyInt, 2, ", $.subvaultName, ")"
                    )
                ),
                ABILibrary.getABI(IAavePoolV3.repay.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.aaveInstance), "0"),
                innerParameters
            );
        }
    }

    function getAaveCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][](($.collaterals.length + $.loans.length) * 3 + 1);

        // setUserEMode
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.setUserEMode, ($.categoryId)), true);
            tmp[i++] =
                Call($.curator, $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.setUserEMode, ($.categoryId + 1)), false);
            tmp[i++] = Call(
                address(0xdead), $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.setUserEMode, ($.categoryId)), false
            );
            tmp[i++] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(IAavePoolV3.setUserEMode, ($.categoryId)), false);
            tmp[i++] =
                Call($.curator, $.aaveInstance, 1 wei, abi.encodeCall(IAavePoolV3.setUserEMode, ($.categoryId)), false);
            tmp[i++] = Call(
                $.curator, $.aaveInstance, 1 wei, abi.encode(IAavePoolV3.setUserEMode.selector, $.categoryId), false
            );
            assembly {
                mstore(tmp, i)
            }

            calls[index++] = tmp;
        }

        for (uint256 j = 0; j < $.collaterals.length; j++) {
            address asset = $.collaterals[j];
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, ($.aaveInstance, 0)), true);
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, ($.aaveInstance, 1 ether)), true);
                tmp[i++] =
                    Call(address(0xdead), asset, 0, abi.encodeCall(IERC20.approve, ($.aaveInstance, 1 ether)), false);
                tmp[i++] = Call(
                    $.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.aaveInstance, 1 ether)), false
                );
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
                tmp[i++] =
                    Call($.curator, asset, 1 wei, abi.encodeCall(IERC20.approve, ($.aaveInstance, 1 ether)), false);
                tmp[i++] =
                    Call($.curator, asset, 0, abi.encode(IERC20.approve.selector, $.aaveInstance, 1 ether), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }

            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call(
                    $.curator, $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.supply, (asset, 0, $.subvault, 0)), true
                );
                tmp[i++] = Call(
                    $.curator, $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.supply, (asset, 1, $.subvault, 1)), true
                );
                tmp[i++] = Call(
                    address(0xdead),
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.supply, (asset, 1, $.subvault, 1)),
                    false
                );
                tmp[i++] = Call(
                    $.curator, address(0xdead), 0, abi.encodeCall(IAavePoolV3.supply, (asset, 1, $.subvault, 1)), false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.supply, (address(0xdead), 1, $.subvault, 1)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.supply, (asset, 1, address(0xdead), 1)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    1 wei,
                    abi.encodeCall(IAavePoolV3.supply, (asset, 1, $.subvault, 1)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    0,
                    abi.encode(IAavePoolV3.supply.selector, asset, 1, $.subvault, 1),
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
                    $.curator, $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.withdraw, (asset, 0, $.subvault)), true
                );
                tmp[i++] = Call(
                    $.curator, $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.withdraw, (asset, 1, $.subvault)), true
                );
                tmp[i++] = Call(
                    address(0xdead),
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.withdraw, (asset, 1, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator, address(0xdead), 0, abi.encodeCall(IAavePoolV3.withdraw, (asset, 1, $.subvault)), false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.withdraw, (address(0xdead), 1, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.withdraw, (asset, 1, address(0xdead))),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    1 wei,
                    abi.encodeCall(IAavePoolV3.withdraw, (asset, 1, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator, $.aaveInstance, 0, abi.encode(IAavePoolV3.withdraw.selector, asset, 1, $.subvault), false
                );
                assembly {
                    mstore(tmp, i)
                }

                calls[index++] = tmp;
            }
        }

        for (uint256 j = 0; j < $.loans.length; j++) {
            address asset = $.loans[j];
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, ($.aaveInstance, 0)), true);
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, ($.aaveInstance, 1 ether)), true);
                tmp[i++] =
                    Call(address(0xdead), asset, 0, abi.encodeCall(IERC20.approve, ($.aaveInstance, 1 ether)), false);
                tmp[i++] = Call(
                    $.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.aaveInstance, 1 ether)), false
                );
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
                tmp[i++] =
                    Call($.curator, asset, 1 wei, abi.encodeCall(IERC20.approve, ($.aaveInstance, 1 ether)), false);
                tmp[i++] =
                    Call($.curator, asset, 0, abi.encode(IERC20.approve.selector, $.aaveInstance, 1 ether), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }

            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call(
                    $.curator, $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.borrow, (asset, 0, 2, 0, $.subvault)), true
                );
                tmp[i++] = Call(
                    $.curator, $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.borrow, (asset, 1, 2, 1, $.subvault)), true
                );
                tmp[i++] = Call(
                    address(0xdead),
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.borrow, (asset, 1, 2, 1, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    address(0xdead),
                    0,
                    abi.encodeCall(IAavePoolV3.borrow, (asset, 1, 2, 1, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.borrow, (address(0xdead), 1, 2, 1, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.borrow, (asset, 1, 2, 1, address(0xdead))),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.borrow, (asset, 1, 3, 1, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    1 wei,
                    abi.encodeCall(IAavePoolV3.borrow, (asset, 1, 2, 1, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    0,
                    abi.encode(IAavePoolV3.borrow.selector, asset, 1, 2, 1, $.subvault),
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
                    $.curator, $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.repay, (asset, 0, 2, $.subvault)), true
                );
                tmp[i++] = Call(
                    $.curator, $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.repay, (asset, 1, 2, $.subvault)), true
                );
                tmp[i++] = Call(
                    address(0xdead),
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.repay, (asset, 1, 2, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator, address(0xdead), 0, abi.encodeCall(IAavePoolV3.repay, (asset, 1, 2, $.subvault)), false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.repay, (address(0xdead), 1, 2, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    0,
                    abi.encodeCall(IAavePoolV3.repay, (asset, 1, 2, address(0xdead))),
                    false
                );
                tmp[i++] = Call(
                    $.curator, $.aaveInstance, 0, abi.encodeCall(IAavePoolV3.repay, (asset, 1, 3, $.subvault)), false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.aaveInstance,
                    1 wei,
                    abi.encodeCall(IAavePoolV3.repay, (asset, 1, 2, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator, $.aaveInstance, 0, abi.encode(IAavePoolV3.repay.selector, asset, 1, 2, $.subvault), false
                );
                assembly {
                    mstore(tmp, i)
                }

                calls[index++] = tmp;
            }
        }
    }
}
