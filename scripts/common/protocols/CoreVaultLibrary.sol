// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import "../ParameterLibrary.sol";
import "../ProofLibrary.sol";
import "../interfaces/IAavePoolV3.sol";
import "../interfaces/Imports.sol";

library CoreVaultLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address subvault;
        string subvaultName;
        address curator;
        address vault;
        address[] depositQueues;
        address[] redeemQueues;
    }

    function getCoreVaultProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 length = ($.depositQueues.length + $.redeemQueues.length) * 2;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        Vault vault = Vault(payable($.vault));
        for (uint256 i = 0; i < $.depositQueues.length; i++) {
            address queue = $.depositQueues[i];
            require(vault.hasQueue(queue) && vault.isDepositQueue(queue), "CoreVaultLibrary: invalid deposit queue");
            if (IDepositQueue(queue).asset() == TransferLibrary.ETH) {
                leaves[index++] = ProofLibrary.makeVerificationPayload(
                    bitmaskVerifier,
                    $.curator,
                    queue,
                    0,
                    abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](0))),
                    ProofLibrary.makeBitmask(
                        true,
                        true,
                        false,
                        true,
                        abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](0)))
                    )
                );
            } else {
                leaves[index++] = ProofLibrary.makeVerificationPayload(
                    bitmaskVerifier,
                    $.curator,
                    IDepositQueue(queue).asset(),
                    0,
                    abi.encodeCall(IERC20.approve, (queue, 0)),
                    ProofLibrary.makeBitmask(
                        true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
                    )
                );
                leaves[index++] = ProofLibrary.makeVerificationPayload(
                    bitmaskVerifier,
                    $.curator,
                    queue,
                    0,
                    abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](0))),
                    ProofLibrary.makeBitmask(
                        true, true, true, true, abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](0)))
                    )
                );
            }
        }
        for (uint256 i = 0; i < $.redeemQueues.length; i++) {
            address queue = $.redeemQueues[i];
            require(vault.hasQueue(queue) && !vault.isDepositQueue(queue), "CoreVaultLibrary: invalid redeem queue");
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                queue,
                0,
                abi.encodeCall(IRedeemQueue.redeem, (0)),
                ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IRedeemQueue.redeem, (0)))
            );
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                queue,
                0,
                abi.encodeCall(IRedeemQueue.claim, ($.subvault, new uint32[](1))),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(IRedeemQueue.claim, (address(type(uint160).max), new uint32[](1)))
                )
            );
        }

        assembly {
            mstore(leaves, index)
        }
    }

    function getCoreVaultDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = ($.depositQueues.length + $.redeemQueues.length) * 2;
        descriptions = new string[](length);
        uint256 index = 0;
        ParameterLibrary.Parameter[] memory innerParameters;
        for (uint256 i = 0; i < $.depositQueues.length; i++) {
            address queue = $.depositQueues[i];
            address asset = IDepositQueue(queue).asset();
            if (asset == TransferLibrary.ETH) {
                innerParameters = ParameterLibrary.build("assets", "any").addAny("referral");
                innerParameters = innerParameters.add("merkleProof", "[]");
                descriptions[index++] = JsonLibrary.toJson(
                    string(
                        abi.encodePacked("DepositQueue(ETH).deposit(anyInt==msg.value, anyAddress, new bytes32[](0))")
                    ),
                    ABILibrary.getABI(IDepositQueue.deposit.selector),
                    ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(queue), "anyInt"),
                    innerParameters
                );
            } else {
                string memory symbol = IERC20Metadata(asset).symbol();
                innerParameters = ParameterLibrary.build("to", Strings.toHexString(queue)).addAny("amount");
                descriptions[index++] = JsonLibrary.toJson(
                    string(abi.encodePacked("IERC20(", symbol, ").approve(DepositQueue(", symbol, "), anyInt)")),
                    ABILibrary.getABI(IERC20.approve.selector),
                    ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(asset), "0"),
                    innerParameters
                );

                innerParameters = ParameterLibrary.build("assets", "any").addAny("referral");
                innerParameters = innerParameters.add("merkleProof", "[]");
                descriptions[index++] = JsonLibrary.toJson(
                    string(abi.encodePacked("DepositQueue(", symbol, ").deposit(anyInt, anyAddress, new bytes32[](0))")),
                    ABILibrary.getABI(IDepositQueue.deposit.selector),
                    ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(queue), "0"),
                    innerParameters
                );
            }
        }

        for (uint256 i = 0; i < $.redeemQueues.length; i++) {
            address queue = $.redeemQueues[i];
            address asset = IRedeemQueue(queue).asset();

            innerParameters = ParameterLibrary.build("shares", "any");
            string memory symbol = asset == TransferLibrary.ETH ? "ETH" : IERC20Metadata(asset).symbol();
            descriptions[index++] = JsonLibrary.toJson(
                string(abi.encodePacked("RedeemQueue(", symbol, ").redeem(anyInt)")),
                ABILibrary.getABI(IRedeemQueue.redeem.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(queue), "0"),
                innerParameters
            );

            innerParameters =
                ParameterLibrary.build("receiver", Strings.toHexString($.subvault)).add("timestamps", "[any]");
            descriptions[index++] = JsonLibrary.toJson(
                string(abi.encodePacked("RedeemQueue(", symbol, ").claim(subvault, [antInt32])")),
                ABILibrary.getABI(IRedeemQueue.claim.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(queue), "0"),
                innerParameters
            );
        }

        assembly {
            mstore(descriptions, index)
        }
    }

    function getCoreVaultCalls(Info memory $) internal view returns (Call[][] memory calls) {
        uint256 length = ($.depositQueues.length + $.redeemQueues.length) * 2;
        calls = new Call[][](length);
        uint256 index = 0;

        for (uint256 j = 0; j < $.depositQueues.length; j++) {
            address queue = $.depositQueues[j];
            address asset = IDepositQueue(queue).asset();

            if (asset == TransferLibrary.ETH) {
                {
                    Call[] memory tmp = new Call[](16);
                    uint256 i = 0;
                    tmp[i++] = Call(
                        $.curator,
                        queue,
                        0,
                        abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](0))),
                        true
                    );
                    tmp[i++] = Call(
                        $.curator,
                        queue,
                        0,
                        abi.encodeCall(IDepositQueue.deposit, (1 ether, address(0), new bytes32[](0))),
                        true
                    );
                    tmp[i++] = Call(
                        $.curator,
                        queue,
                        1 ether,
                        abi.encodeCall(IDepositQueue.deposit, (1 ether, address(0), new bytes32[](0))),
                        true
                    );

                    tmp[i++] = Call(
                        address(0xdead),
                        queue,
                        0,
                        abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](0))),
                        false
                    );
                    tmp[i++] = Call(
                        $.curator,
                        address(0xdead),
                        0,
                        abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](0))),
                        false
                    );
                    tmp[i++] = Call(
                        $.curator,
                        queue,
                        0,
                        abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](50))),
                        false
                    );
                    tmp[i++] = Call(
                        $.curator,
                        queue,
                        0,
                        abi.encode(IDepositQueue.deposit.selector, 0, address(0), new bytes32[](0)),
                        false
                    );

                    assembly {
                        mstore(tmp, i)
                    }
                    calls[index++] = tmp;
                }
            } else {
                {
                    Call[] memory tmp = new Call[](16);
                    uint256 i = 0;
                    tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, (queue, 0)), true);
                    tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, (queue, 1 ether)), true);
                    tmp[i++] = Call(address(0xdead), asset, 0, abi.encodeCall(IERC20.approve, (queue, 1 ether)), false);
                    tmp[i++] =
                        Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, (queue, 1 ether)), false);
                    tmp[i++] =
                        Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
                    tmp[i++] = Call($.curator, asset, 1 wei, abi.encodeCall(IERC20.approve, (queue, 1 ether)), false);
                    tmp[i++] = Call($.curator, asset, 0, abi.encode(IERC20.approve.selector, queue, 1 ether), false);
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
                        queue,
                        0,
                        abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](0))),
                        true
                    );
                    tmp[i++] = Call(
                        $.curator,
                        queue,
                        0,
                        abi.encodeCall(IDepositQueue.deposit, (1 ether, address(0), new bytes32[](0))),
                        true
                    );
                    tmp[i++] = Call(
                        $.curator,
                        queue,
                        0,
                        abi.encodeCall(IDepositQueue.deposit, (1 ether, address(0xbeaf), new bytes32[](0))),
                        true
                    );

                    tmp[i++] = Call(
                        address(0xdead),
                        queue,
                        0,
                        abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](0))),
                        false
                    );
                    tmp[i++] = Call(
                        $.curator,
                        address(0xdead),
                        0,
                        abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](0))),
                        false
                    );
                    tmp[i++] = Call(
                        $.curator,
                        queue,
                        1 wei,
                        abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](0))),
                        false
                    );
                    tmp[i++] = Call(
                        $.curator,
                        queue,
                        0,
                        abi.encodeCall(IDepositQueue.deposit, (0, address(0), new bytes32[](50))),
                        false
                    );
                    tmp[i++] = Call(
                        $.curator,
                        queue,
                        0,
                        abi.encode(IDepositQueue.deposit.selector, 0, address(0), new bytes32[](0)),
                        false
                    );

                    assembly {
                        mstore(tmp, i)
                    }
                    calls[index++] = tmp;
                }
            }
        }

        for (uint256 j = 0; j < $.redeemQueues.length; j++) {
            address queue = $.redeemQueues[j];

            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, queue, 0, abi.encodeCall(IRedeemQueue.redeem, (0)), true);
                tmp[i++] = Call($.curator, queue, 0, abi.encodeCall(IRedeemQueue.redeem, (1 ether)), true);

                tmp[i++] = Call(address(0xdead), queue, 0, abi.encodeCall(IRedeemQueue.redeem, (1 ether)), false);
                tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IRedeemQueue.redeem, (1 ether)), false);
                tmp[i++] = Call($.curator, queue, 1 wei, abi.encodeCall(IRedeemQueue.redeem, (1 ether)), false);
                tmp[i++] = Call($.curator, queue, 0, abi.encode(IRedeemQueue.redeem.selector, 1 ether), false);

                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                uint32[] memory timestamps = new uint32[](1);
                tmp[i++] = Call($.curator, queue, 0, abi.encodeCall(IRedeemQueue.claim, ($.subvault, timestamps)), true);
                timestamps[0] = 1e9;
                tmp[i++] = Call($.curator, queue, 0, abi.encodeCall(IRedeemQueue.claim, ($.subvault, timestamps)), true);

                tmp[i++] =
                    Call(address(0xdead), queue, 0, abi.encodeCall(IRedeemQueue.claim, ($.subvault, timestamps)), false);
                tmp[i++] = Call(
                    $.curator, address(0xdead), 0, abi.encodeCall(IRedeemQueue.claim, ($.subvault, timestamps)), false
                );
                tmp[i++] =
                    Call($.curator, queue, 1 wei, abi.encodeCall(IRedeemQueue.claim, ($.subvault, timestamps)), false);
                tmp[i++] =
                    Call($.curator, queue, 0, abi.encodeCall(IRedeemQueue.claim, (address(0xdead), timestamps)), false);
                tmp[i++] =
                    Call($.curator, queue, 0, abi.encodeCall(IRedeemQueue.claim, ($.subvault, new uint32[](50))), false);
                tmp[i++] =
                    Call($.curator, queue, 0, abi.encodeCall(IRedeemQueue.claim, ($.subvault, new uint32[](0))), false);
                tmp[i++] =
                    Call($.curator, queue, 0, abi.encode(IRedeemQueue.claim.selector, $.subvault, timestamps), false);

                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }
        }

        assembly {
            mstore(calls, index)
        }
    }
}
