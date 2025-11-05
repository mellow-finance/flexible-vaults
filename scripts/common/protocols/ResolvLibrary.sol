pragma solidity 0.8.25;
// SPDX-License-Identifier: BUSL-1.1

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import "../ParameterLibrary.sol";
import "../ProofLibrary.sol";

import "../interfaces/IStUSR.sol";
import "../interfaces/IUsrExternalRequestsManager.sol";

import "../interfaces/Imports.sol";

library ResolvLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address asset;
        address usrRequestManager;
        address usr;
        address stUsr;
        address subvault;
        string subvaultName;
        address curator;
    }

    function getResolvProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            asset.approve(usrManager, any)
            usr.approve(usrManager, any)
            
            usrManager.requestMint(asset, amount, minLpAmount)
            usrManager.requestBurn(lpAmount, asset, minAssetAmount)

            usrManager.cancelMint(id)
            usrManager.cancelBurn(id)

            usrManager.redeem(shares, asset, minAssetAmount)

            usr.approve(stUsr)
            stUsr.deposit(amount)
            stUsr.withdraw(amount)
            stUsr.withdrawAll()
        */

        uint256 length = 11;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.asset,
            0,
            abi.encodeCall(IERC20.approve, ($.usrRequestManager, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.usr,
            0,
            abi.encodeCall(IERC20.approve, ($.usrRequestManager, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.usrRequestManager,
            0,
            abi.encodeCall(IUsrExternalRequestsManager.requestMint, ($.asset, 0, 0)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IUsrExternalRequestsManager.requestMint, (address(type(uint160).max), 0, 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.usrRequestManager,
            0,
            abi.encodeCall(IUsrExternalRequestsManager.requestBurn, (0, $.asset, 0)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IUsrExternalRequestsManager.requestBurn, (0, address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.usrRequestManager,
            0,
            abi.encodeCall(IUsrExternalRequestsManager.cancelMint, (0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IUsrExternalRequestsManager.cancelMint, (0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.usrRequestManager,
            0,
            abi.encodeCall(IUsrExternalRequestsManager.cancelBurn, (0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IUsrExternalRequestsManager.cancelBurn, (0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.usrRequestManager,
            0,
            abi.encodeCall(IUsrExternalRequestsManager.redeem, (0, $.asset, 0)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IUsrExternalRequestsManager.redeem, (0, address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.usr,
            0,
            abi.encodeCall(IERC20.approve, ($.stUsr, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.stUsr,
            0,
            abi.encodeCall(IStUSR.deposit, (0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IStUSR.deposit, (0)))
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.stUsr,
            0,
            abi.encodeCall(IStUSR.withdraw, (0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IStUSR.withdraw, (0)))
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.stUsr,
            0,
            abi.encodeCall(IStUSR.withdrawAll, ()),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IStUSR.withdrawAll, ()))
        );
    }

    function getResolvDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = 11;
        descriptions = new string[](length);
        uint256 index = 0;

        ParameterLibrary.Parameter[] memory innerParameters;

        innerParameters = ParameterLibrary.buildERC20(Strings.toHexString($.usrRequestManager));
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IERC20(",
                    IERC20Metadata($.asset).symbol(),
                    ").approve(usrExternalRequestManager(",
                    Strings.toHexString($.usrRequestManager),
                    "), anyInt)"
                )
            ),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.asset), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildERC20(Strings.toHexString($.usrRequestManager));
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IERC20(",
                    IERC20Metadata($.usr).symbol(),
                    ").approve(usrExternalRequestManager(",
                    Strings.toHexString($.usrRequestManager),
                    "), anyInt)"
                )
            ),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.usr), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("_depositTokenAddress", Strings.toHexString($.asset)).addAny("_amount")
            .addAny("_minMintAmount");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "UsrExternalRequestManager(",
                    Strings.toHexString($.usrRequestManager),
                    ").requestMint(",
                    IERC20Metadata($.asset).symbol(),
                    ", anyInt, anyInt)"
                )
            ),
            ABILibrary.getABI(IUsrExternalRequestsManager.requestMint.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.usrRequestManager), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("_issueTokenAmount").add(
            "_withdrawalTokenAddress", Strings.toHexString($.asset)
        ).addAny("_minWithdrawalAmount");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "UsrExternalRequestManager(",
                    Strings.toHexString($.usrRequestManager),
                    ").requestBurn(anyInt, ",
                    IERC20Metadata($.asset).symbol(),
                    ", anyInt)"
                )
            ),
            ABILibrary.getABI(IUsrExternalRequestsManager.requestBurn.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.usrRequestManager), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("_id");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "UsrExternalRequestManager(", Strings.toHexString($.usrRequestManager), ").cancelMint(anyInt)"
                )
            ),
            ABILibrary.getABI(IUsrExternalRequestsManager.cancelMint.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.usrRequestManager), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("_id");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "UsrExternalRequestManager(", Strings.toHexString($.usrRequestManager), ").cancelBurn(anyInt)"
                )
            ),
            ABILibrary.getABI(IUsrExternalRequestsManager.cancelBurn.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.usrRequestManager), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("_id");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "UsrExternalRequestManager(", Strings.toHexString($.usrRequestManager), ").redeem(anyInt)"
                )
            ),
            ABILibrary.getABI(IUsrExternalRequestsManager.cancelBurn.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.usrRequestManager), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("_amount").add(
            "_withdrawalTokenAddress", Strings.toHexString($.asset)
        ).addAny("_minExpectedAmount");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "UsrExternalRequestManager(",
                    Strings.toHexString($.usrRequestManager),
                    ").redeem(anyInt, ",
                    IERC20Metadata($.asset).symbol(),
                    ", anyInt)"
                )
            ),
            ABILibrary.getABI(IUsrExternalRequestsManager.redeem.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.usrRequestManager), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildERC20(Strings.toHexString($.stUsr));
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IERC20(", Strings.toHexString($.usr), ").approve(", IERC20Metadata($.stUsr).symbol(), ", anyInt)"
                )
            ),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.usr), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("_usrAmount");
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("StUSR(", Strings.toHexString($.stUsr), ").deposit(anyInt)")),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.stUsr), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("_usrAmount");
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("StUSR(", Strings.toHexString($.stUsr), ").withdraw(anyInt)")),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.stUsr), "0"),
            innerParameters
        );
        innerParameters = new ParameterLibrary.Parameter[](0);
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("StUSR(", Strings.toHexString($.stUsr), ").withdrawAll()")),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.stUsr), "0"),
            innerParameters
        );
    }

    function getCapLenderCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][](11);
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.asset, 0, abi.encodeCall(IERC20.approve, ($.usrRequestManager, 0)), true);

            tmp[i++] = Call($.curator, $.asset, 0, abi.encodeCall(IERC20.approve, ($.usrRequestManager, 1 ether)), true);
            tmp[i++] =
                Call(address(0xdead), $.asset, 0, abi.encodeCall(IERC20.approve, ($.usrRequestManager, 1 ether)), false);
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.usrRequestManager, 1 ether)), false
            );
            tmp[i++] =
                Call($.curator, $.asset, 1 wei, abi.encodeCall(IERC20.approve, ($.usrRequestManager, 1 ether)), false);
            tmp[i++] = Call($.curator, $.asset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.asset, 0, abi.encode(IERC20.approve.selector, $.usrRequestManager, 1 ether), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.usr, 0, abi.encodeCall(IERC20.approve, ($.usrRequestManager, 0)), true);

            tmp[i++] = Call($.curator, $.usr, 0, abi.encodeCall(IERC20.approve, ($.usrRequestManager, 1 ether)), true);
            tmp[i++] =
                Call(address(0xdead), $.usr, 0, abi.encodeCall(IERC20.approve, ($.usrRequestManager, 1 ether)), false);
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.usrRequestManager, 1 ether)), false
            );
            tmp[i++] =
                Call($.curator, $.usr, 1 wei, abi.encodeCall(IERC20.approve, ($.usrRequestManager, 1 ether)), false);
            tmp[i++] = Call($.curator, $.usr, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.usr, 0, abi.encode(IERC20.approve.selector, $.usrRequestManager, 1 ether), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.requestMint, ($.asset, 0, 0)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.requestMint, ($.asset, 1 ether, 1 ether)),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.requestMint, ($.asset, 1 ether, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IUsrExternalRequestsManager.requestMint, ($.asset, 1 ether, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                1 wei,
                abi.encodeCall(IUsrExternalRequestsManager.requestMint, ($.asset, 1 ether, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.requestMint, (address(0xdead), 1 ether, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encode(IUsrExternalRequestsManager.requestMint.selector, $.asset, 1 ether, 1 ether),
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
                $.curator,
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.requestBurn, (0, $.asset, 0)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.requestBurn, (1 ether, $.asset, 1 ether)),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.requestBurn, (1 ether, $.asset, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IUsrExternalRequestsManager.requestBurn, (1 ether, $.asset, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                1 wei,
                abi.encodeCall(IUsrExternalRequestsManager.requestBurn, (1 ether, $.asset, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.requestBurn, (1 ether, address(0xdead), 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encode(IUsrExternalRequestsManager.requestBurn.selector, 1 ether, $.asset, 1 ether),
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
                $.curator, $.usrRequestManager, 0, abi.encodeCall(IUsrExternalRequestsManager.cancelMint, (0)), true
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.cancelMint, (1 ether)),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.cancelMint, (1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IUsrExternalRequestsManager.cancelMint, (1 ether)), false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                1 wei,
                abi.encodeCall(IUsrExternalRequestsManager.cancelMint, (1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encode(IUsrExternalRequestsManager.cancelMint.selector, 1 ether),
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
                $.curator, $.usrRequestManager, 0, abi.encodeCall(IUsrExternalRequestsManager.cancelBurn, (0)), true
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.cancelBurn, (1 ether)),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.cancelBurn, (1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IUsrExternalRequestsManager.cancelBurn, (1 ether)), false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                1 wei,
                abi.encodeCall(IUsrExternalRequestsManager.cancelBurn, (1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encode(IUsrExternalRequestsManager.cancelBurn.selector, 1 ether),
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
                $.curator,
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.redeem, (0, $.asset, 0)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.redeem, (1 ether, $.asset, 1 ether)),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.redeem, (1 ether, $.asset, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IUsrExternalRequestsManager.redeem, (1 ether, $.asset, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                1 wei,
                abi.encodeCall(IUsrExternalRequestsManager.redeem, (1 ether, $.asset, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encodeCall(IUsrExternalRequestsManager.redeem, (1 ether, address(0xdead), 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.usrRequestManager,
                0,
                abi.encode(IUsrExternalRequestsManager.redeem.selector, 1 ether, $.asset, 1 ether),
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
            tmp[i++] = Call($.curator, $.asset, 0, abi.encodeCall(IERC20.approve, ($.stUsr, 0)), true);

            tmp[i++] = Call($.curator, $.asset, 0, abi.encodeCall(IERC20.approve, ($.stUsr, 1 ether)), true);
            tmp[i++] = Call(address(0xdead), $.asset, 0, abi.encodeCall(IERC20.approve, ($.stUsr, 1 ether)), false);
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.stUsr, 1 ether)), false);
            tmp[i++] = Call($.curator, $.asset, 1 wei, abi.encodeCall(IERC20.approve, ($.stUsr, 1 ether)), false);
            tmp[i++] = Call($.curator, $.asset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
            tmp[i++] = Call($.curator, $.asset, 0, abi.encode(IERC20.approve.selector, $.stUsr, 1 ether), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.stUsr, 0, abi.encodeCall(IStUSR.deposit, (0)), true);
            tmp[i++] = Call($.curator, $.stUsr, 0, abi.encodeCall(IStUSR.deposit, (1 ether)), true);

            tmp[i++] = Call(address(0xdead), $.stUsr, 0, abi.encodeCall(IStUSR.deposit, (1 ether)), false);
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IStUSR.deposit, (1 ether)), false);
            tmp[i++] = Call($.curator, $.stUsr, 1 wei, abi.encodeCall(IStUSR.deposit, (1 ether)), false);
            tmp[i++] = Call($.curator, $.stUsr, 0, abi.encode(IStUSR.deposit.selector, 1 ether), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.stUsr, 0, abi.encodeCall(IStUSR.withdraw, (0)), true);
            tmp[i++] = Call($.curator, $.stUsr, 0, abi.encodeCall(IStUSR.withdraw, (1 ether)), true);

            tmp[i++] = Call(address(0xdead), $.stUsr, 0, abi.encodeCall(IStUSR.withdraw, (1 ether)), false);
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IStUSR.withdraw, (1 ether)), false);
            tmp[i++] = Call($.curator, $.stUsr, 1 wei, abi.encodeCall(IStUSR.withdraw, (1 ether)), false);
            tmp[i++] = Call($.curator, $.stUsr, 0, abi.encode(IStUSR.withdraw.selector, 1 ether), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.stUsr, 0, abi.encodeCall(IStUSR.withdrawAll, ()), true);

            tmp[i++] = Call(address(0xdead), $.stUsr, 0, abi.encodeCall(IStUSR.withdrawAll, ()), false);
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IStUSR.withdrawAll, ()), false);
            tmp[i++] = Call($.curator, $.stUsr, 1 wei, abi.encodeCall(IStUSR.withdrawAll, ()), false);
            tmp[i++] = Call($.curator, $.stUsr, 0, abi.encode(IStUSR.withdrawAll.selector), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
    }
}
