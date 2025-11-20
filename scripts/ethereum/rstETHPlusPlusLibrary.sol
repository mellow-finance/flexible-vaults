// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ABILibrary} from "../common/ABILibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {AaveLibrary} from "../common/protocols/AaveLibrary.sol";
import {MorphoLibrary} from "../common/protocols/MorphoLibrary.sol";
import {SwapModuleLibrary} from "../common/protocols/SwapModuleLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library rstETHPlusPlusLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for IVerifier.VerificationPayload[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address swapModule;
        bytes32[] morphoMarketId;
        address[] aaveCollaterals;
        address[] aaveLoans;
    }

    function _getSwapModuleAssets(address payable swapModule) internal view returns (address[] memory uniqueAssets) {
        uint256 tokenInCount = SwapModule(swapModule).getRoleMemberCount(Permissions.SWAP_MODULE_TOKEN_IN_ROLE);
        uint256 tokenOutCount = SwapModule(swapModule).getRoleMemberCount(Permissions.SWAP_MODULE_TOKEN_OUT_ROLE);
        uint256 totalCount = tokenInCount + tokenOutCount;
        address[] memory assets = new address[](totalCount);
        for (uint256 i = 0; i < tokenInCount; i++) {
            assets[i] = SwapModule(swapModule).getRoleMember(Permissions.SWAP_MODULE_TOKEN_IN_ROLE, i);
        }
        for (uint256 i = tokenInCount; i < totalCount; i++) {
            assets[i] = SwapModule(swapModule).getRoleMember(Permissions.SWAP_MODULE_TOKEN_OUT_ROLE, i - tokenInCount);
        }
        uniqueAssets = ArraysLibrary.unique(assets);
    }

    function getSubvault0Proofs(Info memory $)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1. weth.deposit{any}()
            2. cowswap (ETH/WETH/wstETH -> weETH/rsETH) via SwapModule
            3. aave borrow/repay ETH/WETH (weETH/rsETH collateral)
            4. morpho borrow/repay ETH/WETH (weETH/rsETH collateral)
            5. rstETH.redeem(shares, subvault0, subvault0)
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](100);
        uint256 iterator = 0;

        leaves[iterator++] =
            WethLibrary.getWethDepositProof(bitmaskVerifier, WethLibrary.Info($.curator, Constants.WETH));

        iterator = leaves.insert(
            SwapModuleLibrary.getSwapModuleProofs(
                bitmaskVerifier,
                SwapModuleLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    swapModule: $.swapModule,
                    curators: ArraysLibrary.makeAddressArray(abi.encode($.curator)),
                    assets: _getSwapModuleAssets(payable($.swapModule))
                })
            ),
            iterator
        );

        iterator = leaves.insert(
            AaveLibrary.getAaveProofs(
                bitmaskVerifier,
                AaveLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    aaveInstance: Constants.AAVE_CORE,
                    aaveInstanceName: "Core",
                    collaterals: $.aaveCollaterals,
                    loans: $.aaveLoans,
                    categoryId: 1
                })
            ),
            iterator
        );

        for (uint256 i = 0; i < $.morphoMarketId.length; i++) {
            iterator = leaves.insert(
                MorphoLibrary.getMorphoProofs(
                    bitmaskVerifier,
                    MorphoLibrary.Info({
                        morpho: Constants.MORPHO_ETHEREUM,
                        marketId: $.morphoMarketId[i],
                        subvault: $.subvault,
                        curator: $.curator
                    })
                ),
                iterator
            );
        }

        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            Constants.RSTETH,
            0,
            abi.encodeCall(IERC4626.redeem, (0, $.subvault, $.subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IERC4626.redeem, (0, address(type(uint160).max), address(type(uint160).max)))
            )
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](50);
        uint256 iterator = 0;
        descriptions[iterator++] = WethLibrary.getWethDepositDescription(WethLibrary.Info($.curator, Constants.WETH));

        iterator = descriptions.insert(
            SwapModuleLibrary.getSwapModuleDescriptions(
                SwapModuleLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    swapModule: $.swapModule,
                    curators: ArraysLibrary.makeAddressArray(abi.encode($.curator)),
                    assets: _getSwapModuleAssets(payable($.swapModule))
                })
            ),
            iterator
        );

        iterator = descriptions.insert(
            AaveLibrary.getAaveDescriptions(
                AaveLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    aaveInstance: Constants.AAVE_CORE,
                    aaveInstanceName: "Core",
                    collaterals: $.aaveCollaterals,
                    loans: $.aaveLoans,
                    categoryId: 1
                })
            ),
            iterator
        );
        for (uint256 i = 0; i < $.morphoMarketId.length; i++) {
            iterator = descriptions.insert(
                MorphoLibrary.getMorphoDescriptions(
                    MorphoLibrary.Info({
                        morpho: Constants.MORPHO_ETHEREUM,
                        marketId: $.morphoMarketId[i],
                        subvault: $.subvault,
                        curator: $.curator
                    })
                ),
                iterator
            );
        }

        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = ParameterLibrary.add2("shares", "any", "receiver", Strings.toHexString($.subvault)).add(
            "owner", Strings.toHexString($.subvault)
        );
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("rstETH.redeem(any, subvault0, subvault0)")),
            ABILibrary.getABI(IERC4626.redeem.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(Constants.RSTETH), "0"),
            innerParameters
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault0Calls(Info memory $, IVerifier.VerificationPayload[] memory leaves)
        internal
        view
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        Call[][] memory calls_ = new Call[][](leaves.length);

        uint256 iterator = 0;
        calls_[iterator++] = WethLibrary.getWethDepositCalls(WethLibrary.Info($.curator, Constants.WETH));
        iterator = calls_.insert(
            SwapModuleLibrary.getSwapModuleCalls(
                SwapModuleLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    swapModule: $.swapModule,
                    curators: ArraysLibrary.makeAddressArray(abi.encode($.curator)),
                    assets: _getSwapModuleAssets(payable($.swapModule))
                })
            ),
            iterator
        );

        iterator = calls_.insert(
            AaveLibrary.getAaveCalls(
                AaveLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    aaveInstance: Constants.AAVE_CORE,
                    aaveInstanceName: "Core",
                    collaterals: $.aaveCollaterals,
                    loans: $.aaveLoans,
                    categoryId: 1
                })
            ),
            iterator
        );

        for (uint256 i = 0; i < $.morphoMarketId.length; i++) {
            iterator = calls_.insert(
                MorphoLibrary.getMorphoCalls(
                    MorphoLibrary.Info({
                        morpho: Constants.MORPHO_ETHEREUM,
                        marketId: $.morphoMarketId[i],
                        subvault: $.subvault,
                        curator: $.curator
                    })
                ),
                iterator
            );
        }

        {
            address asset = Constants.RSTETH;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (0, $.subvault, $.subvault)), true);
            tmp[i++] =
                Call($.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)), true);
            tmp[i++] = Call(
                address(0xdead), asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)), false
            );
            tmp[i++] =
                Call($.curator, asset, 1 wei, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)), false);
            tmp[i++] = Call(
                $.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, address(0xdead), $.subvault)), false
            );
            tmp[i++] = Call(
                $.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, address(0xdead))), false
            );
            tmp[i++] =
                Call($.curator, asset, 0, abi.encode(IERC4626.redeem.selector, 1 ether, $.subvault, $.subvault), false);
            assembly {
                mstore(tmp, i)
            }
            calls_[iterator++] = tmp;
        }

        assembly {
            mstore(calls_, iterator)
        }

        calls.calls = calls_;
    }
}
