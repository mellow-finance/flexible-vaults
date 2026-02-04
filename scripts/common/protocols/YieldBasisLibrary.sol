// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {ERC4626Library} from "./ERC4626Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IYieldBasis} from "../interfaces/IYieldBasis.sol";
import {IYieldBasisGauge} from "../interfaces/IYieldBasisGauge.sol";
import {IYieldBasisZap} from "../interfaces/IYieldBasisZap.sol";

import "../interfaces/Imports.sol";

library YieldBasisLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for IVerifier.VerificationPayload[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address zap;
        address[] ybTokens;
    }

    function getGauges(Info memory $) internal view returns (address[] memory gauges) {
        gauges = new address[]($.ybTokens.length);
        for (uint256 i = 0; i < $.ybTokens.length; i++) {
            gauges[i] = IYieldBasis($.ybTokens[i]).staker();
        }
    }

    function getAssets(Info memory $) internal view returns (address[] memory assets) {
        assets = new address[]($.ybTokens.length);
        for (uint256 i = 0; i < $.ybTokens.length; i++) {
            assets[i] = IYieldBasis($.ybTokens[i]).ASSET_TOKEN();
        }
    }

    function makeDuplicates(address addr, uint256 count) internal pure returns (address[] memory addrs) {
        addrs = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            addrs[i] = addr;
        }
    }

    function getYieldBasisProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator;

        // ERC4626 gauges
        iterator = leaves.insert(
            ERC4626Library.getERC4626Proofs(
                bitmaskVerifier,
                ERC4626Library.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    assets: getGauges($)
                })
            ),
            iterator
        );

        address[] memory assets = getAssets($);

        // ERC20 approve asset to ybTokens
        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier, ERC20Library.Info({curator: $.curator, assets: assets, to: $.ybTokens})
            ),
            iterator
        );

        // ERC20 approve asset to zap
        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({curator: $.curator, assets: assets, to: makeDuplicates($.zap, assets.length)})
            ),
            iterator
        );

        for (uint256 i = 0; i < $.ybTokens.length; i++) {
            address ybToken = $.ybTokens[i];
            address gauge = IYieldBasis(ybToken).staker(); // inherited from IRC4626

            // function deposit(uint256 assets, uint256 debt, uint256 min_shares)
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                ybToken,
                0,
                abi.encodeCall(IYieldBasis.deposit, (0, 0, 0)),
                ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IYieldBasis.deposit, (0, 0, 0)))
            );

            // function withdraw(uint256 shares, uint256 min_assets)
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                ybToken,
                0,
                abi.encodeCall(IYieldBasis.withdraw, (0, 0)),
                ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IYieldBasis.withdraw, (0, 0)))
            );

            // function emergency_withdraw(uint256 shares)
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                ybToken,
                0,
                abi.encodeCall(IYieldBasis.emergency_withdraw, (0)),
                ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IYieldBasis.emergency_withdraw, (0)))
            );

            // function deposit_and_stake(address gauge, uint256 assets, uint256 debt, uint256 min_shares)
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.zap,
                0,
                abi.encodeCall(IYieldBasisZap.deposit_and_stake, (gauge, 0, 0, 0)),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(IYieldBasisZap.deposit_and_stake, (address(type(uint160).max), 0, 0, 0))
                )
            );

            // function withdraw_and_unstake(address gauge, uint256 shares, uint256 min_assets)
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.zap,
                0,
                abi.encodeCall(IYieldBasisZap.withdraw_and_unstake, (gauge, 0, 0)),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(IYieldBasisZap.withdraw_and_unstake, (address(type(uint160).max), 0, 0))
                )
            );

            // function claim(address reward)
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                gauge,
                0,
                abi.encodeCall(IYieldBasisGauge.claim, (address(0))),
                ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IYieldBasisGauge.claim, (address(0))))
            );
        }

        assembly {
            mstore(leaves, iterator)
        }
    }

    function getYieldBasisDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](50);
        uint256 iterator;

        // ERC4626 gauge
        iterator = descriptions.insert(
            ERC4626Library.getERC4626Descriptions(
                ERC4626Library.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    assets: getGauges($)
                })
            ),
            iterator
        );

        address[] memory assets = getAssets($);

        // ERC20 approve asset to ybTokens
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC20Library.getERC20Descriptions(ERC20Library.Info({curator: $.curator, assets: assets, to: $.ybTokens})),
            iterator
        );

        // ERC20 approve asset to zap
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({curator: $.curator, assets: assets, to: makeDuplicates($.zap, assets.length)})
            ),
            iterator
        );

        for (uint256 i = 0; i < $.ybTokens.length; i++) {
            address ybToken = $.ybTokens[i];
            string memory ybTokenSymbol = IYieldBasis(ybToken).symbol();

            // function deposit(uint256 assets, uint256 debt, uint256 min_shares)
            {
                ParameterLibrary.Parameter[] memory innerParameters;
                innerParameters = innerParameters.addAny("assets");
                innerParameters = innerParameters.addAny("debt");
                innerParameters = innerParameters.addAny("min_shares");
                descriptions[iterator++] = JsonLibrary.toJson(
                    string(
                        abi.encodePacked(
                            "IYieldBasis(", ybTokenSymbol, ").deposit(assets=anyInt, debt=anyInt, min_shares=anyInt)"
                        )
                    ),
                    ABILibrary.getABI(IYieldBasis.deposit.selector),
                    ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(ybToken), "0"),
                    innerParameters
                );
            }

            // function withdraw(uint256 shares, uint256 min_assets)
            {
                ParameterLibrary.Parameter[] memory innerParameters;
                innerParameters = innerParameters.addAny("shares");
                innerParameters = innerParameters.addAny("min_assets");
                descriptions[iterator++] = JsonLibrary.toJson(
                    string(
                        abi.encodePacked("IYieldBasis(", ybTokenSymbol, ").withdraw(shares=anyInt, min_assets=anyInt)")
                    ),
                    ABILibrary.getABI(IYieldBasis.withdraw.selector),
                    ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(ybToken), "0"),
                    innerParameters
                );
            }

            // function emergency_withdraw(uint256 shares)
            {
                ParameterLibrary.Parameter[] memory innerParameters;
                innerParameters = innerParameters.addAny("shares");
                descriptions[iterator++] = JsonLibrary.toJson(
                    string(abi.encodePacked("IYieldBasis(", ybTokenSymbol, ").emergency_withdraw(shares=anyInt)")),
                    ABILibrary.getABI(IYieldBasis.emergency_withdraw.selector),
                    ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(ybToken), "0"),
                    innerParameters
                );
            }
            {
                address gauge = IYieldBasis(ybToken).staker(); // inherited from IRC4626
                string memory gaugeSymbol = IYieldBasisGauge(gauge).symbol();

                // function deposit_and_stake(address gauge, uint256 assets, uint256 debt, uint256 min_shares)
                {
                    ParameterLibrary.Parameter[] memory innerParameters;
                    innerParameters = innerParameters.add("gauge", Strings.toHexString(gauge));
                    innerParameters = innerParameters.addAny("assets");
                    innerParameters = innerParameters.addAny("debt");
                    innerParameters = innerParameters.addAny("min_shares");
                    descriptions[iterator++] = JsonLibrary.toJson(
                        string(
                            abi.encodePacked(
                                "IYieldBasisZap.deposit_and_stake(gauge=",
                                gaugeSymbol,
                                ", assets=anyInt, debt=anyInt, min_shares=anyInt)"
                            )
                        ),
                        ABILibrary.getABI(IYieldBasisZap.deposit_and_stake.selector),
                        ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.zap), "0"),
                        innerParameters
                    );
                }

                // function withdraw_and_unstake(address gauge, uint256 shares, uint256 min_assets)
                {
                    ParameterLibrary.Parameter[] memory innerParameters;
                    innerParameters = innerParameters.add("gauge", Strings.toHexString(gauge));
                    innerParameters = innerParameters.addAny("shares");
                    innerParameters = innerParameters.addAny("min_assets");
                    descriptions[iterator++] = JsonLibrary.toJson(
                        string(
                            abi.encodePacked(
                                "IYieldBasisZap.withdraw_and_unstake(gauge=",
                                gaugeSymbol,
                                ", shares=anyInt, min_assets=anyInt)"
                            )
                        ),
                        ABILibrary.getABI(IYieldBasisZap.withdraw_and_unstake.selector),
                        ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.zap), "0"),
                        innerParameters
                    );
                }

                // function claim(address reward)
                {
                    ParameterLibrary.Parameter[] memory innerParameters;
                    innerParameters = innerParameters.addAny("reward");
                    descriptions[iterator++] = JsonLibrary.toJson(
                        string(abi.encodePacked("IYieldBasisGauge(", gaugeSymbol, ").claim(reward=Any)")),
                        ABILibrary.getABI(IYieldBasisGauge.claim.selector),
                        ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(gauge), "0"),
                        innerParameters
                    );
                }
            }
        }

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getYieldBasisCalls(Info memory $) internal view returns (Call[][] memory calls) {
        uint256 iterator = 0;
        calls = new Call[][](50);

        // ERC4626 gauges
        iterator = calls.insert(
            ERC4626Library.getERC4626Calls(
                ERC4626Library.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    assets: getGauges($)
                })
            ),
            iterator
        );

        address[] memory assets = getAssets($);

        // ERC20 approve asset to ybToken
        iterator = ArraysLibrary.insert(
            calls,
            ERC20Library.getERC20Calls(ERC20Library.Info({curator: $.curator, assets: assets, to: $.ybTokens})),
            iterator
        );

        // ERC20 approve asset to zap
        iterator = ArraysLibrary.insert(
            calls,
            ERC20Library.getERC20Calls(
                ERC20Library.Info({curator: $.curator, assets: assets, to: makeDuplicates($.zap, assets.length)})
            ),
            iterator
        );

        for (uint256 i = 0; i < $.ybTokens.length; i++) {
            address ybToken = $.ybTokens[i];
            address gauge = IYieldBasis(ybToken).staker(); // inherited from IRC4626
            address asset = IYieldBasis(ybToken).ASSET_TOKEN();

            // function deposit(uint256 assets, uint256 debt, uint256 min_shares)
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;

                tmp[i++] =
                    Call($.curator, ybToken, 0, abi.encodeCall(IYieldBasis.deposit, (1 ether, 1 ether, 1 ether)), true);
                tmp[i++] = Call($.curator, ybToken, 0, abi.encodeCall(IYieldBasis.deposit, (0, 0, 0)), true);
                tmp[i++] = Call(
                    address(0xdead), ybToken, 0, abi.encodeCall(IYieldBasis.deposit, (1 ether, 1 ether, 1 ether)), false
                );
                tmp[i++] = Call(
                    $.curator,
                    address(0xdead),
                    0,
                    abi.encodeCall(IYieldBasis.deposit, (1 ether, 1 ether, 1 ether)),
                    false
                );
                tmp[i++] = Call(
                    $.curator, ybToken, 1 wei, abi.encodeCall(IYieldBasis.deposit, (1 ether, 1 ether, 1 ether)), false
                );
                tmp[i++] = Call(
                    $.curator, ybToken, 0, abi.encode(IYieldBasis.deposit.selector, 1 ether, 1 ether, 1 ether), false
                );
                assembly {
                    mstore(tmp, i)
                }
                calls[iterator++] = tmp;
            }

            // function withdraw(uint256 shares, uint256 min_assets)
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, ybToken, 0, abi.encodeCall(IYieldBasis.withdraw, (1 ether, 1 ether)), true);
                tmp[i++] = Call($.curator, ybToken, 0, abi.encodeCall(IYieldBasis.withdraw, (0, 0)), true);
                tmp[i++] =
                    Call(address(0xdead), ybToken, 0, abi.encodeCall(IYieldBasis.withdraw, (1 ether, 1 ether)), false);
                tmp[i++] =
                    Call($.curator, address(0xdead), 0, abi.encodeCall(IYieldBasis.withdraw, (1 ether, 1 ether)), false);
                tmp[i++] =
                    Call($.curator, ybToken, 1 wei, abi.encodeCall(IYieldBasis.withdraw, (1 ether, 1 ether)), false);
                tmp[i++] =
                    Call($.curator, ybToken, 0, abi.encode(IYieldBasis.withdraw.selector, 1 ether, 1 ether), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[iterator++] = tmp;
            }

            // function emergency_withdraw(uint256 shares)
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, ybToken, 0, abi.encodeCall(IYieldBasis.emergency_withdraw, (1 ether)), true);
                tmp[i++] = Call($.curator, ybToken, 0, abi.encodeCall(IYieldBasis.emergency_withdraw, (0)), true);
                tmp[i++] =
                    Call(address(0xdead), ybToken, 0, abi.encodeCall(IYieldBasis.emergency_withdraw, (1 ether)), false);
                tmp[i++] = Call(
                    $.curator, address(0xdead), 0, abi.encodeCall(IYieldBasis.emergency_withdraw, (1 ether)), false
                );
                tmp[i++] =
                    Call($.curator, ybToken, 1 wei, abi.encodeCall(IYieldBasis.emergency_withdraw, (1 ether)), false);
                tmp[i++] =
                    Call($.curator, ybToken, 0, abi.encode(IYieldBasis.emergency_withdraw.selector, 1 ether), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[iterator++] = tmp;
            }

            // function deposit_and_stake(address gauge, uint256 assets, uint256 debt, uint256 min_shares)
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;

                tmp[i++] = Call(
                    $.curator,
                    $.zap,
                    0,
                    abi.encodeCall(IYieldBasisZap.deposit_and_stake, (gauge, 1 ether, 1 ether, 1 ether)),
                    true
                );
                tmp[i++] =
                    Call($.curator, $.zap, 0, abi.encodeCall(IYieldBasisZap.deposit_and_stake, (gauge, 0, 0, 0)), true);
                tmp[i++] = Call(
                    address(0xdead),
                    $.zap,
                    0,
                    abi.encodeCall(IYieldBasisZap.deposit_and_stake, (gauge, 1 ether, 1 ether, 1 ether)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    address(0xdead),
                    0,
                    abi.encodeCall(IYieldBasisZap.deposit_and_stake, (gauge, 1 ether, 1 ether, 1 ether)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.zap,
                    1 wei,
                    abi.encodeCall(IYieldBasisZap.deposit_and_stake, (gauge, 1 ether, 1 ether, 1 ether)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.zap,
                    0,
                    abi.encode(IYieldBasisZap.deposit_and_stake.selector, gauge, 1 ether, 1 ether, 1 ether),
                    false
                );
                assembly {
                    mstore(tmp, i)
                }
                calls[iterator++] = tmp;
            }

            // function withdraw_and_unstake(address gauge, uint256 shares, uint256 min_assets)
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;

                tmp[i++] = Call(
                    $.curator,
                    $.zap,
                    0,
                    abi.encodeCall(IYieldBasisZap.withdraw_and_unstake, (gauge, 1 ether, 1 ether)),
                    true
                );
                tmp[i++] =
                    Call($.curator, $.zap, 0, abi.encodeCall(IYieldBasisZap.withdraw_and_unstake, (gauge, 0, 0)), true);
                tmp[i++] = Call(
                    address(0xdead),
                    $.zap,
                    0,
                    abi.encodeCall(IYieldBasisZap.withdraw_and_unstake, (gauge, 1 ether, 1 ether)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    address(0xdead),
                    0,
                    abi.encodeCall(IYieldBasisZap.withdraw_and_unstake, (gauge, 1 ether, 1 ether)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.zap,
                    1 wei,
                    abi.encodeCall(IYieldBasisZap.withdraw_and_unstake, (gauge, 1 ether, 1 ether)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.zap,
                    0,
                    abi.encode(IYieldBasisZap.withdraw_and_unstake.selector, gauge, 1 ether, 1 ether),
                    false
                );
                assembly {
                    mstore(tmp, i)
                }
                calls[iterator++] = tmp;
            }

            // function claim(address reward)
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;

                tmp[i++] = Call($.curator, gauge, 0, abi.encodeCall(IYieldBasisGauge.claim, (address(1))), true);
                tmp[i++] = Call($.curator, gauge, 0, abi.encodeCall(IYieldBasisGauge.claim, (address(0))), true);
                tmp[i++] = Call(address(0xdead), gauge, 0, abi.encodeCall(IYieldBasisGauge.claim, (address(1))), false);
                tmp[i++] =
                    Call($.curator, address(0xdead), 0, abi.encodeCall(IYieldBasisGauge.claim, (address(1))), false);
                tmp[i++] = Call($.curator, gauge, 1 wei, abi.encodeCall(IYieldBasisGauge.claim, (address(1))), false);
                tmp[i++] = Call($.curator, gauge, 0, abi.encode(IYieldBasisGauge.claim.selector, address(1)), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[iterator++] = tmp;
            }
        }
    }
}
