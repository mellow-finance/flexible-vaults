// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ICurveGauge} from "../interfaces/ICurveGauge.sol";
import {ICurvePool} from "../interfaces/ICurvePool.sol";
import {ICurveRewardMinter} from "../interfaces/ICurveRewardMinter.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/Imports.sol";

library CurveLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address subvault;
        string subvaultName;
        address curator;
        address pool;
        address gauge;
        address rewardMinter;
    }

    function getCurveProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 n = ICurvePool($.pool).N_COINS();

        leaves = new IVerifier.VerificationPayload[](50);
        uint256 index = 0;
        for (uint256 i = 0; i < n; i++) {
            address asset = ICurvePool($.pool).coins(i);
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                asset,
                0,
                abi.encodeCall(IERC20.approve, ($.pool, 0)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
                )
            );
        }
        {
            bytes memory callData = abi.encodeCall(ICurvePool.add_liquidity, (new uint256[](n), 0));
            assembly {
                mstore(add(callData, 100), not(0))
            }
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.pool,
                0,
                abi.encodeCall(ICurvePool.add_liquidity, (new uint256[](n), 0)),
                ProofLibrary.makeBitmask(true, true, true, true, callData)
            );
        }
        {
            bytes memory callData = abi.encodeCall(ICurvePool.remove_liquidity, (0, new uint256[](n)));
            assembly {
                mstore(add(callData, 100), not(0))
            }
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.pool,
                0,
                abi.encodeCall(ICurvePool.remove_liquidity, (0, new uint256[](n))),
                ProofLibrary.makeBitmask(true, true, true, true, callData)
            );
        }

        if ($.gauge != address(0)) {
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.pool,
                0,
                abi.encodeCall(IERC20.approve, ($.gauge, 0)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
                )
            );

            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.gauge,
                0,
                abi.encodeCall(ICurveGauge.deposit, (0)),
                ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(ICurveGauge.deposit, (0)))
            );

            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.gauge,
                0,
                abi.encodeCall(ICurveGauge.withdraw, (0)),
                ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(ICurveGauge.withdraw, (0)))
            );

            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.gauge,
                0,
                abi.encodeCall(ICurveGauge.claim_rewards, ()),
                ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(ICurveGauge.claim_rewards, ()))
            );
        }

        if ($.rewardMinter != address(0)) {
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.rewardMinter,
                0,
                abi.encodeCall(ICurveRewardMinter.mint, ($.gauge)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(ICurveRewardMinter.mint, (address(type(uint160).max)))
                )
            );
        }
        assembly {
            mstore(leaves, index)
        }
    }

    function getCurveDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 n = ICurvePool($.pool).N_COINS();

        descriptions = new string[](50);
        uint256 index = 0;

        ParameterLibrary.Parameter[] memory innerParameters;
        for (uint256 i = 0; i < n; i++) {
            address asset = ICurvePool($.pool).coins(i);
            string memory assetSymbol = IERC20Metadata(asset).symbol();
            innerParameters = ParameterLibrary.build("to", Strings.toHexString($.pool)).addAny("amount");
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "IERC20(", assetSymbol, ").approve(IERC4626(", ICurvePool($.pool).name(), "), any)"
                    )
                ),
                ABILibrary.getABI(IERC20.approve.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(asset), "0"),
                innerParameters
            );
        }

        innerParameters = (new ParameterLibrary.Parameter[](0)).addAnyArray("_amounts", n).addAny("_min_mint_amount");
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("ICurvePool(", ICurvePool($.pool).name(), ").add_liquidity(any[N_COINS], any)")),
            ABILibrary.getABI(ICurvePool.add_liquidity.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.pool), "0"),
            innerParameters
        );

        innerParameters = (new ParameterLibrary.Parameter[](0)).addAny("_burn_amount").addAnyArray("_min_amounts", n);
        descriptions[index++] = JsonLibrary.toJson(
            string(abi.encodePacked("ICurvePool(", ICurvePool($.pool).name(), ").remove_liquidity(any, any[N_COINS])")),
            ABILibrary.getABI(ICurvePool.remove_liquidity.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.pool), "0"),
            innerParameters
        );

        if ($.gauge != address(0)) {
            innerParameters = ParameterLibrary.build("to", Strings.toHexString($.gauge)).addAny("amount");
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "IERC20(", ICurvePool($.pool).name(), ").approve(", ICurveGauge($.gauge).name(), ", any)"
                    )
                ),
                ABILibrary.getABI(IERC20.approve.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.pool), "0"),
                innerParameters
            );

            innerParameters = ParameterLibrary.build("_value", "any");
            descriptions[index++] = JsonLibrary.toJson(
                string(abi.encodePacked("ICurveGauge(", ICurvePool($.gauge).name(), ").deposit(any)")),
                ABILibrary.getABI(ICurveGauge.deposit.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.gauge), "0"),
                innerParameters
            );

            innerParameters = ParameterLibrary.build("_value", "any");
            descriptions[index++] = JsonLibrary.toJson(
                string(abi.encodePacked("ICurveGauge(", ICurvePool($.gauge).name(), ").withdraw(any)")),
                ABILibrary.getABI(ICurveGauge.withdraw.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.gauge), "0"),
                innerParameters
            );

            innerParameters = new ParameterLibrary.Parameter[](0);
            descriptions[index++] = JsonLibrary.toJson(
                string(abi.encodePacked("ICurveGauge(", ICurvePool($.gauge).name(), ").claim_rewards()")),
                ABILibrary.getABI(ICurveGauge.claim_rewards.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.gauge), "0"),
                innerParameters
            );
        }

        if ($.rewardMinter != address(0)) {
            innerParameters = ParameterLibrary.build("gauge", Strings.toHexString($.gauge));
            descriptions[index++] = JsonLibrary.toJson(
                string(abi.encodePacked("ICurveRewardMinter.mint(gauge: ", ICurvePool($.gauge).name(), ")")),
                ABILibrary.getABI(ICurveRewardMinter.mint.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.rewardMinter), "0"),
                innerParameters
            );
        }
        assembly {
            mstore(descriptions, index)
        }
    }

    function getCurveCalls(Info memory $) internal view returns (Call[][] memory calls) {
        uint256 n = ICurvePool($.pool).N_COINS();

        calls = new Call[][](50);

        uint256 index = 0;

        for (uint256 j = 0; j < n; j++) {
            address asset = ICurvePool($.pool).coins(j);
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, ($.pool, 0)), true);
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, ($.pool, 1 ether)), true);
                tmp[i++] = Call(address(0xdead), asset, 0, abi.encodeCall(IERC20.approve, ($.pool, 1 ether)), false);
                tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.pool, 1 ether)), false);
                tmp[i++] = Call($.curator, asset, 1 wei, abi.encodeCall(IERC20.approve, ($.pool, 1 ether)), false);
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
                tmp[i++] = Call($.curator, asset, 0, abi.encode(IERC20.approve.selector, $.pool, 1 ether), false);

                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            uint256[] memory amounts = new uint256[](n);
            tmp[i++] = Call($.curator, $.pool, 0, abi.encodeCall(ICurvePool.add_liquidity, (amounts, 0)), true);
            tmp[i++] = Call($.curator, $.pool, 0, abi.encodeCall(ICurvePool.add_liquidity, (amounts, 1 ether)), true);
            for (uint256 j = 0; j < amounts.length; j++) {
                amounts[j] = 1 ether - j;
            }
            tmp[i++] = Call($.curator, $.pool, 0, abi.encodeCall(ICurvePool.add_liquidity, (amounts, 1 ether)), true);
            tmp[i++] =
                Call(address(0xdead), $.pool, 0, abi.encodeCall(ICurvePool.add_liquidity, (amounts, 1 ether)), false);
            tmp[i++] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(ICurvePool.add_liquidity, (amounts, 1 ether)), false);
            tmp[i++] =
                Call($.curator, $.pool, 1 wei, abi.encodeCall(ICurvePool.add_liquidity, (amounts, 1 ether)), false);
            tmp[i++] = Call(
                $.curator, $.pool, 0, abi.encodeCall(ICurvePool.add_liquidity, (new uint256[](100), 1 ether)), false
            );
            tmp[i++] =
                Call($.curator, $.pool, 0, abi.encode(ICurvePool.add_liquidity.selector, amounts, 1 ether), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            uint256[] memory amounts = new uint256[](n);
            tmp[i++] = Call($.curator, $.pool, 0, abi.encodeCall(ICurvePool.remove_liquidity, (0, amounts)), true);
            tmp[i++] = Call($.curator, $.pool, 0, abi.encodeCall(ICurvePool.remove_liquidity, (1 ether, amounts)), true);
            for (uint256 j = 0; j < amounts.length; j++) {
                amounts[j] = 1 ether - j;
            }
            tmp[i++] = Call($.curator, $.pool, 0, abi.encodeCall(ICurvePool.remove_liquidity, (1 ether, amounts)), true);
            tmp[i++] =
                Call(address(0xdead), $.pool, 0, abi.encodeCall(ICurvePool.remove_liquidity, (1 ether, amounts)), false);
            tmp[i++] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(ICurvePool.remove_liquidity, (1 ether, amounts)), false
            );
            tmp[i++] =
                Call($.curator, $.pool, 1 wei, abi.encodeCall(ICurvePool.remove_liquidity, (1 ether, amounts)), false);
            tmp[i++] = Call(
                $.curator, $.pool, 0, abi.encodeCall(ICurvePool.remove_liquidity, (1 ether, new uint256[](100))), false
            );
            tmp[i++] =
                Call($.curator, $.pool, 0, abi.encode(ICurvePool.remove_liquidity.selector, 1 ether, amounts), false);

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        if ($.gauge != address(0)) {
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, $.pool, 0, abi.encodeCall(IERC20.approve, ($.gauge, 0)), true);
                tmp[i++] = Call($.curator, $.pool, 0, abi.encodeCall(IERC20.approve, ($.gauge, 1 ether)), true);
                tmp[i++] = Call(address(0xdead), $.pool, 0, abi.encodeCall(IERC20.approve, ($.gauge, 1 ether)), false);
                tmp[i++] =
                    Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.gauge, 1 ether)), false);
                tmp[i++] = Call($.curator, $.pool, 1 wei, abi.encodeCall(IERC20.approve, ($.gauge, 1 ether)), false);
                tmp[i++] = Call($.curator, $.pool, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
                tmp[i++] = Call($.curator, $.pool, 0, abi.encode(IERC20.approve.selector, $.gauge, 1 ether), false);

                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }

            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, $.gauge, 0, abi.encodeCall(ICurveGauge.deposit, (0)), true);
                tmp[i++] = Call($.curator, $.gauge, 0, abi.encodeCall(ICurveGauge.deposit, (1 ether)), true);
                tmp[i++] = Call(address(0xdead), $.gauge, 0, abi.encodeCall(ICurveGauge.deposit, (1 ether)), false);
                tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(ICurveGauge.deposit, (1 ether)), false);
                tmp[i++] = Call($.curator, $.gauge, 1 wei, abi.encodeCall(ICurveGauge.deposit, (1 ether)), false);
                tmp[i++] = Call($.curator, $.gauge, 0, abi.encode(ICurveGauge.deposit.selector, 1 ether), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }

            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, $.gauge, 0, abi.encodeCall(ICurveGauge.withdraw, (0)), true);
                tmp[i++] = Call($.curator, $.gauge, 0, abi.encodeCall(ICurveGauge.withdraw, (1 ether)), true);
                tmp[i++] = Call(address(0xdead), $.gauge, 0, abi.encodeCall(ICurveGauge.withdraw, (1 ether)), false);
                tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(ICurveGauge.withdraw, (1 ether)), false);
                tmp[i++] = Call($.curator, $.gauge, 1 wei, abi.encodeCall(ICurveGauge.withdraw, (1 ether)), false);
                tmp[i++] = Call($.curator, $.gauge, 0, abi.encode(ICurveGauge.withdraw.selector, 1 ether), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }

            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, $.gauge, 0, abi.encodeCall(ICurveGauge.claim_rewards, ()), true);
                tmp[i++] = Call(address(0xdead), $.gauge, 0, abi.encodeCall(ICurveGauge.claim_rewards, ()), false);
                tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(ICurveGauge.claim_rewards, ()), false);
                tmp[i++] = Call($.curator, $.gauge, 1 wei, abi.encodeCall(ICurveGauge.claim_rewards, ()), false);
                tmp[i++] = Call($.curator, $.gauge, 0, abi.encode(ICurveGauge.claim_rewards.selector, 1 wei), false);

                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }
        }
        if ($.rewardMinter != address(0)) {
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                // tmp[i++] = Call($.curator, $.rewardMinter, 0, abi.encodeCall(ICurveRewardMinter.mint, ($.gauge)), true);
                tmp[i++] = Call(
                    $.curator, $.rewardMinter, 0, abi.encodeCall(ICurveRewardMinter.mint, (address(0xdead))), false
                );
                tmp[i++] =
                    Call(address(0xdead), $.rewardMinter, 0, abi.encodeCall(ICurveRewardMinter.mint, ($.gauge)), false);
                tmp[i++] =
                    Call($.curator, address(0xdead), 0, abi.encodeCall(ICurveRewardMinter.mint, ($.gauge)), false);
                tmp[i++] =
                    Call($.curator, $.rewardMinter, 1 wei, abi.encodeCall(ICurveRewardMinter.mint, ($.gauge)), false);
                tmp[i++] =
                    Call($.curator, $.rewardMinter, 0, abi.encode(ICurveRewardMinter.mint.selector, $.gauge), false);

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
