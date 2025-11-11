// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import "../ProofLibrary.sol";
import "../interfaces/IStakeWiseEthVault.sol";
import "../interfaces/Imports.sol";

library StakeWiseLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address subvault;
        string subvaultName;
        address curator;
        address vault;
        string vaultName;
    }

    function getStakeWiseProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1. vault.deposit{value: any}(subvault, any)
            2. vault.depositAndMintOsToken{value: any}(subvault, any, any)
            3. vault.mintOsToken(subvault, any, any)
            4. vault.burnOsToken(any)
            5. vault.enterExitQueue(any, subvault)
            6. vault.claimExitedAssets(any, any, any)
        */
        uint256 length = 6;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.vault,
            0,
            abi.encodeCall(IStakeWiseEthVault.deposit, ($.subvault, address(0))),
            ProofLibrary.makeBitmask(
                true,
                true,
                false,
                true,
                abi.encodeCall(IStakeWiseEthVault.deposit, (address(type(uint160).max), address(0)))
            )
        );

        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.vault,
            0,
            abi.encodeCall(IStakeWiseEthVault.depositAndMintOsToken, ($.subvault, 0, address(0))),
            ProofLibrary.makeBitmask(
                true,
                true,
                false,
                true,
                abi.encodeCall(IStakeWiseEthVault.depositAndMintOsToken, (address(type(uint160).max), 0, address(0)))
            )
        );

        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.vault,
            0,
            abi.encodeCall(IStakeWiseEthVault.mintOsToken, ($.subvault, 0, address(0))),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IStakeWiseEthVault.mintOsToken, (address(type(uint160).max), 0, address(0)))
            )
        );

        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.vault,
            0,
            abi.encodeCall(IStakeWiseEthVault.burnOsToken, (0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IStakeWiseEthVault.burnOsToken, (0)))
        );

        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.vault,
            0,
            abi.encodeCall(IStakeWiseEthVault.enterExitQueue, (0, $.subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IStakeWiseEthVault.enterExitQueue, (0, address(type(uint160).max)))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.vault,
            0,
            abi.encodeCall(IStakeWiseEthVault.claimExitedAssets, (0, 0, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IStakeWiseEthVault.claimExitedAssets, (0, 0, 0))
            )
        );
    }

    function getStakeWiseDescriptions(Info memory $) internal pure returns (string[] memory descriptions) {
        /*
            1. vault.deposit(subvault, any)
            2. vault.depositAndMintOsToken(subvault, any, any)
            3. vault.mintOsToken(subvault, any, any)
            4. vault.burnOsToken(any)
            5. vault.enterExitQueue(any, subvault)
            6. vault.claimExitedAssets(any, any, any)
        */
        uint256 length = 6;
        descriptions = new string[](length);

        uint256 index = 0;
        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = ParameterLibrary.add2("receiver", Strings.toHexString($.subvault), "referrer", "any");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked("IStakeWiseEthVault(", $.vaultName, ").deposit{value: any}(", $.subvaultName, ", any)")
            ),
            ABILibrary.getABI(IStakeWiseEthVault.deposit.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.vault), "any"),
            innerParameters
        );

        innerParameters = ParameterLibrary.add2("receiver", Strings.toHexString($.subvault), "osTokenShares", "any")
            .addAny("referrer");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IStakeWiseEthVault(",
                    $.vaultName,
                    ").depositAndMintOsToken{value: any}(",
                    $.subvaultName,
                    ", any, any)"
                )
            ),
            ABILibrary.getABI(IStakeWiseEthVault.depositAndMintOsToken.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.vault), "any"),
            innerParameters
        );

        innerParameters = ParameterLibrary.add2("receiver", Strings.toHexString($.subvault), "osTokenShares", "any")
            .addAny("referrer");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked("IStakeWiseEthVault(", $.vaultName, ").mintOsToken(", $.subvaultName, ", any, any)")
            ),
            ABILibrary.getABI(IStakeWiseEthVault.mintOsToken.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.vault), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("osTokenShares", "any");
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("IStakeWiseEthVault(", $.vaultName, ").burnOstoken(any)")),
            ABILibrary.getABI(IStakeWiseEthVault.burnOsToken.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.vault), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.add2("shares", "any", "receiver", Strings.toHexString($.subvault));
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("IStakeWiseEthVault(", $.vaultName, ").enterExitQueue(any, ", $.subvaultName, ")")),
            ABILibrary.getABI(IStakeWiseEthVault.enterExitQueue.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.vault), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.add2("positionTicket", "any", "timestamp", "any").addAny("exitQueueIndex");
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("IStakeWiseEthVault(", $.vaultName, ").claimExitedAssets(any, any, any)")),
            ABILibrary.getABI(IStakeWiseEthVault.claimExitedAssets.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.vault), "0"),
            innerParameters
        );
    }

    function getStakeWiseCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][](6);

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.vault, 0, abi.encodeCall(IStakeWiseEthVault.deposit, ($.subvault, address(0))), true);
            tmp[i++] =
                Call($.curator, $.vault, 0, abi.encodeCall(IStakeWiseEthVault.deposit, ($.subvault, address(1))), true);
            tmp[i++] = Call(
                $.curator, $.vault, 1 wei, abi.encodeCall(IStakeWiseEthVault.deposit, ($.subvault, address(1))), true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.vault,
                1 wei,
                abi.encodeCall(IStakeWiseEthVault.deposit, ($.subvault, address(1))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                1 wei,
                abi.encodeCall(IStakeWiseEthVault.deposit, ($.subvault, address(1))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                1 wei,
                abi.encodeCall(IStakeWiseEthVault.deposit, (address(0xdead), address(1))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                1 wei,
                abi.encode(IStakeWiseEthVault.deposit.selector, $.subvault, address(1)),
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
                $.vault,
                0,
                abi.encodeCall(IStakeWiseEthVault.depositAndMintOsToken, ($.subvault, 0, address(0))),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                0,
                abi.encodeCall(IStakeWiseEthVault.depositAndMintOsToken, ($.subvault, 0, address(1))),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                1 wei,
                abi.encodeCall(IStakeWiseEthVault.depositAndMintOsToken, ($.subvault, 0, address(1))),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                1 wei,
                abi.encodeCall(IStakeWiseEthVault.depositAndMintOsToken, ($.subvault, 1 wei, address(1))),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.vault,
                1 wei,
                abi.encodeCall(IStakeWiseEthVault.depositAndMintOsToken, ($.subvault, 0, address(1))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                1 wei,
                abi.encodeCall(IStakeWiseEthVault.depositAndMintOsToken, ($.subvault, 0, address(1))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                1 wei,
                abi.encodeCall(IStakeWiseEthVault.depositAndMintOsToken, (address(0xdead), 0, address(1))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                1 wei,
                abi.encode(IStakeWiseEthVault.depositAndMintOsToken.selector, $.subvault, 0, address(1)),
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
                $.curator, $.vault, 0, abi.encodeCall(IStakeWiseEthVault.mintOsToken, ($.subvault, 0, address(0))), true
            );
            tmp[i++] = Call(
                $.curator, $.vault, 0, abi.encodeCall(IStakeWiseEthVault.mintOsToken, ($.subvault, 0, address(1))), true
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                0,
                abi.encodeCall(IStakeWiseEthVault.mintOsToken, ($.subvault, 1 wei, address(1))),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.vault,
                0,
                abi.encodeCall(IStakeWiseEthVault.mintOsToken, ($.subvault, 0, address(1))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IStakeWiseEthVault.mintOsToken, ($.subvault, 0, address(1))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                1 wei,
                abi.encodeCall(IStakeWiseEthVault.mintOsToken, ($.subvault, 0, address(1))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                0,
                abi.encodeCall(IStakeWiseEthVault.mintOsToken, (address(0xdead), 0, address(1))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                0,
                abi.encode(IStakeWiseEthVault.mintOsToken.selector, $.subvault, 0, address(1)),
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
            tmp[i++] = Call($.curator, $.vault, 0, abi.encodeCall(IStakeWiseEthVault.burnOsToken, (0)), true);
            tmp[i++] = Call($.curator, $.vault, 0, abi.encodeCall(IStakeWiseEthVault.burnOsToken, (1 wei)), true);

            tmp[i++] = Call(address(0xdead), $.vault, 0, abi.encodeCall(IStakeWiseEthVault.burnOsToken, (0)), false);
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IStakeWiseEthVault.burnOsToken, (0)), false);
            tmp[i++] = Call($.curator, $.vault, 1 wei, abi.encodeCall(IStakeWiseEthVault.burnOsToken, (0)), false);
            tmp[i++] = Call($.curator, $.vault, 0, abi.encode(IStakeWiseEthVault.burnOsToken.selector, 0), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.vault, 0, abi.encodeCall(IStakeWiseEthVault.enterExitQueue, (0, $.subvault)), true);
            tmp[i++] = Call(
                $.curator, $.vault, 0, abi.encodeCall(IStakeWiseEthVault.enterExitQueue, (1 wei, $.subvault)), true
            );
            tmp[i++] = Call(
                address(0xdead),
                $.vault,
                0,
                abi.encodeCall(IStakeWiseEthVault.enterExitQueue, (1 wei, $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IStakeWiseEthVault.enterExitQueue, (1 wei, $.subvault)),
                false
            );
            tmp[i++] = Call(
                $.curator, $.vault, 1 wei, abi.encodeCall(IStakeWiseEthVault.enterExitQueue, (1 wei, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator,
                $.vault,
                0,
                abi.encodeCall(IStakeWiseEthVault.enterExitQueue, (1 wei, address(0xdead))),
                false
            );
            tmp[i++] = Call(
                $.curator, $.vault, 0, abi.encode(IStakeWiseEthVault.enterExitQueue.selector, 1 wei, $.subvault), false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.vault, 0, abi.encodeCall(IStakeWiseEthVault.claimExitedAssets, (0, 0, 0)), true);
            tmp[i++] =
                Call($.curator, $.vault, 0, abi.encodeCall(IStakeWiseEthVault.claimExitedAssets, (1, 1, 1)), true);

            tmp[i++] = Call(
                address(0xdead), $.vault, 0, abi.encodeCall(IStakeWiseEthVault.claimExitedAssets, (0, 0, 0)), false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IStakeWiseEthVault.claimExitedAssets, (0, 0, 0)), false
            );
            tmp[i++] =
                Call($.curator, $.vault, 1 wei, abi.encodeCall(IStakeWiseEthVault.claimExitedAssets, (0, 0, 0)), false);
            tmp[i++] =
                Call($.curator, $.vault, 0, abi.encode(IStakeWiseEthVault.claimExitedAssets.selector, 0, 0, 0), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
    }
}
