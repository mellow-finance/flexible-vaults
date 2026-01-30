// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";

import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import "../ParameterLibrary.sol";
import "../ProofLibrary.sol";
import "./ERC20Library.sol";

import "../interfaces/IEthWrapper.sol";
import "../interfaces/Imports.sol";

library DVVLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address subvault;
        string subvaultName;
        address curator;
    }

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DVV = 0x5E362eb2c0706Bd1d134689eC75176018385430B;
    address public constant ETH_WRAPPER = 0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e;

    function _getERC20Info(address curator) internal pure returns (ERC20Library.Info memory) {
        return ERC20Library.Info({
            curator: curator,
            assets: ArraysLibrary.makeAddressArray(abi.encode(WETH)),
            to: ArraysLibrary.makeAddressArray(abi.encode(ETH_WRAPPER))
        });
    }

    function getDVVProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 length = 4;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        index =
            ArraysLibrary.insert(leaves, ERC20Library.getERC20Proofs(bitmaskVerifier, _getERC20Info($.curator)), index);

        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            ETH_WRAPPER,
            0,
            abi.encodeCall(IEthWrapper.deposit, (ETH, 0, DVV, $.subvault, address(0))),
            ProofLibrary.makeBitmask(
                true,
                true,
                false,
                true,
                abi.encodeCall(
                    IEthWrapper.deposit,
                    (address(type(uint160).max), 0, address(type(uint160).max), address(type(uint160).max), address(0))
                )
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            ETH_WRAPPER,
            0,
            abi.encodeCall(IEthWrapper.deposit, (WETH, 0, DVV, $.subvault, address(0))),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    IEthWrapper.deposit,
                    (address(type(uint160).max), 0, address(type(uint160).max), address(type(uint160).max), address(0))
                )
            )
        );

        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            DVV,
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
    }

    function getDVVDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = 4;
        descriptions = new string[](length);
        uint256 index = 0;

        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = ParameterLibrary.build("to", Strings.toHexString(ETH_WRAPPER)).addAny("amount");

        index = ArraysLibrary.insert(descriptions, ERC20Library.getERC20Descriptions(_getERC20Info($.curator)), index);

        innerParameters = ParameterLibrary.build("depositToken", Strings.toHexString(ETH)).addAny("amount").add(
            "vault", Strings.toHexString(DVV)
        ).add("receiver", Strings.toHexString($.subvault)).addAny("referral");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "WhitelistedEthWrapper.deposit(ETH, any, DVV, ", Strings.toHexString($.subvault), ", any)"
                )
            ),
            ABILibrary.getABI(IEthWrapper.deposit.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(ETH_WRAPPER), "any"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("depositToken", Strings.toHexString(WETH)).addAny("amount").add(
            "vault", Strings.toHexString(DVV)
        ).add("receiver", Strings.toHexString($.subvault)).addAny("referral");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "WhitelistedEthWrapper.deposit(WETH, any, DVV, ", Strings.toHexString($.subvault), ", any)"
                )
            ),
            ABILibrary.getABI(IEthWrapper.deposit.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(ETH_WRAPPER), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.buildAny("shares").add2(
            "receiver", Strings.toHexString($.subvault), "owner", Strings.toHexString($.subvault)
        );
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "DVV.redeem(anyInt, ", Strings.toHexString($.subvault), ", ", Strings.toHexString($.subvault), ")"
                )
            ),
            ABILibrary.getABI(IERC4626.redeem.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(DVV), "0"),
            innerParameters
        );
    }

    function getDVVCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index = 0;
        uint256 length = 4;
        calls = new Call[][](length);

        index = ArraysLibrary.insert(calls, ERC20Library.getERC20Calls(_getERC20Info($.curator)), index);

        {
            address asset = ETH;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;

            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, $.subvault, address(0))),
                true
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                1 ether,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, $.subvault, address(0))),
                true
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 1 ether, DVV, $.subvault, address(0))),
                true
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, $.subvault, address(1))),
                true
            );
            tmp[i++] = Call(
                address(0xdead),
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, $.subvault, address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, $.subvault, address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (address(0xdead), 0, DVV, $.subvault, address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, address(0xdead), $.subvault, address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, address(0xdead), address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encode(IEthWrapper.deposit.selector, asset, 0, DVV, $.subvault, address(0)),
                false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            address asset = WETH;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, $.subvault, address(0))),
                true
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 1 ether, DVV, $.subvault, address(0))),
                true
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, $.subvault, address(1))),
                true
            );
            tmp[i++] = Call(
                address(0xdead),
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, $.subvault, address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, $.subvault, address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                1 ether,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, $.subvault, address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (address(0xdead), 0, DVV, $.subvault, address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, address(0xdead), $.subvault, address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encodeCall(IEthWrapper.deposit, (asset, 0, DVV, address(0xdead), address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                ETH_WRAPPER,
                0,
                abi.encode(IEthWrapper.deposit.selector, asset, 0, DVV, $.subvault, address(0)),
                false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        // ERC4626 redeem
        {
            address asset = DVV;
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
            calls[index++] = tmp;
        }
    }
}
