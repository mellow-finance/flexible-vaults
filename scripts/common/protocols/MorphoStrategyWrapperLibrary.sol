// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";

import "../ArraysLibrary.sol";
import "../ProofLibrary.sol";
import "./ERC20Library.sol";
import "./ERC4626Library.sol";

import "../interfaces/IMorphoStrategyWrapper.sol";

library MorphoStrategyWrapperLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address morpho;
        address morphoStrategyWrapper;
        address subvault;
        address curator;
        string subvaultName;
    }

    function getMorphoStrategyProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        address rewardVault = IMorphoStrategyWrapper($.morphoStrategyWrapper).REWARD_VAULT();
        address collateral = IERC4626(rewardVault).asset();

        uint256 iterator = 0;
        leaves = new IVerifier.VerificationPayload[](50);
        /// @dev approve collateral tokens to MorphoStrategyWrapper
        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(collateral)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.morphoStrategyWrapper))
                })
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            ERC4626Library.getERC4626Proofs(
                bitmaskVerifier,
                ERC4626Library.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(rewardVault))
                })
            ),
            iterator
        );
        /// @dev deposit assets into MorphoStrategyWrapper
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.morphoStrategyWrapper,
            0,
            abi.encodeCall(IMorphoStrategyWrapper.depositAssets, (0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IMorphoStrategyWrapper.depositAssets, (0)))
        );
        /// @dev withdraw from MorphoStrategyWrapper
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.morphoStrategyWrapper,
            0,
            abi.encodeCall(IMorphoStrategyWrapper.withdraw, (0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IMorphoStrategyWrapper.withdraw, (0)))
        );
        /// @dev claim main reward token from MorphoStrategyWrapper
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.morphoStrategyWrapper,
            0,
            abi.encodeCall(IMorphoStrategyWrapper.claim, ()),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IMorphoStrategyWrapper.claim, ()))
        );
        /// @dev claim extra reward tokens from MorphoStrategyWrapper
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.morphoStrategyWrapper,
            0,
            abi.encodeCall(IMorphoStrategyWrapper.claimExtraRewards, ()),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IMorphoStrategyWrapper.claimExtraRewards, ())
            )
        );
        assembly {
            mstore(leaves, iterator)
        }
    }

    function getMorphoStrategyDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        address rewardVault = IMorphoStrategyWrapper($.morphoStrategyWrapper).REWARD_VAULT();
        address collateral = IERC4626(rewardVault).asset();
        descriptions = new string[](50);
        uint256 iterator = 0;
        /// @dev approve collateral tokens to MorphoStrategyWrapper
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(collateral)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.morphoStrategyWrapper))
                })
            ),
            iterator
        );
        /// @dev deposit/withdraw ERC4626 shares to/from rewardVault
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC4626Library.getERC4626Descriptions(
                ERC4626Library.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(rewardVault))
                })
            ),
            iterator
        );
        /// @dev deposit assets into MorphoStrategyWrapper
        ParameterLibrary.Parameter[] memory innerParameters = ParameterLibrary.build("amount", "any");
        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IMorphoStrategyWrapper(", Strings.toHexString($.morphoStrategyWrapper), ").depositAssets(any)"
                )
            ),
            ABILibrary.getABI(IMorphoStrategyWrapper.depositAssets.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.morphoStrategyWrapper), "0"),
            innerParameters
        );
        /// @dev withdraw from MorphoStrategyWrapper
        innerParameters = ParameterLibrary.build("amount", "any");
        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IMorphoStrategyWrapper(", Strings.toHexString($.morphoStrategyWrapper), ").withdraw(any)"
                )
            ),
            ABILibrary.getABI(IMorphoStrategyWrapper.withdraw.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.morphoStrategyWrapper), "0"),
            innerParameters
        );
        /// @dev claim main reward token from MorphoStrategyWrapper
        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked("IMorphoStrategyWrapper(", Strings.toHexString($.morphoStrategyWrapper), ").claim()")
            ),
            ABILibrary.getABI(IMorphoStrategyWrapper.claim.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.morphoStrategyWrapper), "0"),
            new ParameterLibrary.Parameter[](0)
        );
        /// @dev claim extra reward tokens from MorphoStrategyWrapper
        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IMorphoStrategyWrapper(", Strings.toHexString($.morphoStrategyWrapper), ").claimExtraRewards()"
                )
            ),
            ABILibrary.getABI(IMorphoStrategyWrapper.claimExtraRewards.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.morphoStrategyWrapper), "0"),
            new ParameterLibrary.Parameter[](0)
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getMorphoStrategyCalls(Info memory $) internal view returns (Call[][] memory calls) {
        uint256 index;
        calls = new Call[][](100);

        address rewardVault = IMorphoStrategyWrapper($.morphoStrategyWrapper).REWARD_VAULT();
        address collateral = IERC4626(rewardVault).asset();
        /// @dev approve collateral tokens to MorphoStrategyWrapper
        index = ArraysLibrary.insert(
            calls,
            ERC20Library.getERC20Calls(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(collateral)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.morphoStrategyWrapper))
                })
            ),
            index
        );
        /// @dev deposit/withdraw ERC4626 shares to/from rewardVault
        index = ArraysLibrary.insert(
            calls,
            ERC4626Library.getERC4626Calls(
                ERC4626Library.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(rewardVault))
                })
            ),
            index
        );

        //IMorphoStrategyWrapper.depositAssets.selector;
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator, $.morphoStrategyWrapper, 0, abi.encodeCall(IMorphoStrategyWrapper.depositAssets, (0)), true
            );
            tmp[i++] = Call(
                $.curator,
                $.morphoStrategyWrapper,
                0,
                abi.encodeCall(IMorphoStrategyWrapper.depositAssets, (1 ether)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.morphoStrategyWrapper,
                1 wei,
                abi.encodeCall(IMorphoStrategyWrapper.depositAssets, (1 ether)),
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.morphoStrategyWrapper,
                0,
                abi.encodeCall(IMorphoStrategyWrapper.depositAssets, (1 ether)),
                false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IMorphoStrategyWrapper.depositAssets, (1 ether)), false
            );
            tmp[i++] = Call(
                $.curator,
                $.morphoStrategyWrapper,
                0,
                abi.encode(IMorphoStrategyWrapper.depositAssets.selector, 1 ether),
                false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        //IMorphoStrategyWrapper.withdraw.selector;
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.morphoStrategyWrapper, 0, abi.encodeCall(IMorphoStrategyWrapper.withdraw, (0)), true);
            tmp[i++] = Call(
                $.curator, $.morphoStrategyWrapper, 0, abi.encodeCall(IMorphoStrategyWrapper.withdraw, (1 ether)), true
            );
            tmp[i++] = Call(
                $.curator,
                $.morphoStrategyWrapper,
                1 wei,
                abi.encodeCall(IMorphoStrategyWrapper.withdraw, (1 ether)),
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.morphoStrategyWrapper,
                0,
                abi.encodeCall(IMorphoStrategyWrapper.withdraw, (1 ether)),
                false
            );
            tmp[i++] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(IMorphoStrategyWrapper.withdraw, (1 ether)), false);
            tmp[i++] = Call(
                $.curator,
                $.morphoStrategyWrapper,
                0,
                abi.encode(IMorphoStrategyWrapper.withdraw.selector, 1 ether),
                false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        //IMorphoStrategyWrapper.claim.selector;
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call($.curator, $.morphoStrategyWrapper, 0, abi.encodeCall(IMorphoStrategyWrapper.claim, ()), true);
            tmp[i++] = Call(
                address(0xdead), $.morphoStrategyWrapper, 0, abi.encodeCall(IMorphoStrategyWrapper.claim, ()), false
            );
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IMorphoStrategyWrapper.claim, ()), false);
            tmp[i++] =
                Call($.curator, $.morphoStrategyWrapper, 1 wei, abi.encodeCall(IMorphoStrategyWrapper.claim, ()), false);
            tmp[i++] =
                Call($.curator, $.morphoStrategyWrapper, 0, abi.encode(IMorphoStrategyWrapper.claim.selector), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        //IMorphoStrategyWrapper.claimExtraRewards.selector;
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.morphoStrategyWrapper,
                0,
                abi.encodeCall(IMorphoStrategyWrapper.claimExtraRewards, ()),
                true
            );
            tmp[i++] = Call(
                address(0xdead),
                $.morphoStrategyWrapper,
                0,
                abi.encodeCall(IMorphoStrategyWrapper.claimExtraRewards, ()),
                false
            );
            tmp[i++] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(IMorphoStrategyWrapper.claimExtraRewards, ()), false);
            tmp[i++] = Call(
                $.curator,
                $.morphoStrategyWrapper,
                1 wei,
                abi.encodeCall(IMorphoStrategyWrapper.claimExtraRewards, ()),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.morphoStrategyWrapper,
                0,
                abi.encode(IMorphoStrategyWrapper.claimExtraRewards.selector),
                false
            );

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
