// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./ProofLibrary.sol";
import "./interfaces/ICowswapSettlement.sol";
import "./interfaces/Imports.sol";

library CowSwapLibrary {
    struct Info {
        address cowswapSettlement;
        address cowswapVaultRelayer;
        address curator;
        address[] assets;
    }

    function getCowSwapProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 length = $.assets.length + 2;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.cowswapSettlement,
            0,
            abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.cowswapSettlement,
            0,
            abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56)))
            )
        );
        for (uint256 i = 0; i < $.assets.length; i++) {
            address asset = $.assets[i];
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                asset,
                0,
                abi.encodeCall(IERC20.approve, ($.cowswapVaultRelayer, 0)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
                )
            );
        }
    }

    function getCowSwapDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = $.assets.length + 2;
        descriptions = new string[](length);
        uint256 index = 0;
        descriptions[index++] = string(abi.encodePacked("CowswapSettlement.setPreSignature(anyBytes(56), anyBool)"));
        descriptions[index++] = string(abi.encodePacked("CowswapSettlement.invalidateOrder(anyBytes(56))"));
        for (uint256 i = 0; i < $.assets.length; i++) {
            string memory asset = IERC20Metadata($.assets[i]).symbol();
            descriptions[index++] = string(abi.encodePacked("IERC20(", asset, ").approve(CowswapVaultRelayer, anyInt)"));
        }
    }

    function getCowSwapCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][]($.assets.length + 2);

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.cowswapSettlement,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.cowswapSettlement,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), true)),
                true
            );
            tmp[i++] = Call(
                address(0xdead),
                $.cowswapSettlement,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), true)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), true)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.cowswapSettlement,
                1 wei,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), true)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.cowswapSettlement,
                0,
                abi.encode(ICowswapSettlement.setPreSignature.selector, new bytes(56), true),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.cowswapSettlement,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(80), true)),
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
                $.cowswapSettlement,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
                true
            );
            tmp[i++] = Call(
                address(0xdead),
                $.cowswapSettlement,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.cowswapSettlement,
                1 wei,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.cowswapSettlement,
                0,
                abi.encode(ICowswapSettlement.invalidateOrder.selector, new bytes(56)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.cowswapSettlement,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(80))),
                false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        for (uint256 j = 0; j < $.assets.length; j++) {
            address asset = $.assets[j];
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, ($.cowswapVaultRelayer, 0)), true);
                tmp[i++] =
                    Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, ($.cowswapVaultRelayer, 1 ether)), true);
                tmp[i++] = Call(
                    address(0xdead), asset, 0, abi.encodeCall(IERC20.approve, ($.cowswapVaultRelayer, 1 ether)), false
                );
                tmp[i++] = Call(
                    $.curator,
                    address(0xdead),
                    0,
                    abi.encodeCall(IERC20.approve, ($.cowswapVaultRelayer, 1 ether)),
                    false
                );
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
                tmp[i++] = Call(
                    $.curator, asset, 1 wei, abi.encodeCall(IERC20.approve, ($.cowswapVaultRelayer, 1 ether)), false
                );
                tmp[i++] = Call(
                    $.curator, asset, 0, abi.encode(IERC20.approve.selector, $.cowswapVaultRelayer, 1 ether), false
                );
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }
        }
    }

    struct Data {
        IERC20 sellToken;
        IERC20 buyToken;
        address receiver;
        uint256 sellAmount;
        uint256 buyAmount;
        uint32 validTo;
        bytes32 appData;
        uint256 feeAmount;
        bytes32 kind;
        bool partiallyFillable;
        bytes32 sellTokenBalance;
        bytes32 buyTokenBalance;
    }

    bytes32 internal constant KIND_SELL = hex"f3b277728b3fee749481eb3e0b3b48980dbbab78658fc419025cb16eee346775";
    bytes32 internal constant BALANCE_ERC20 = hex"5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9";
    bytes32 internal constant TYPE_HASH = hex"d5a25ba2e97094ad7d83dc28a6572da797d6b3e7fc6663bd93efb789fc17e489";

    uint256 internal constant UID_LENGTH = 56;

    function hash(Data memory order, bytes32 domainSeparator) internal pure returns (bytes32 orderDigest) {
        bytes32 structHash;
        assembly {
            let dataStart := sub(order, 32)
            let temp := mload(dataStart)
            mstore(dataStart, TYPE_HASH)
            structHash := keccak256(dataStart, 416)
            mstore(dataStart, temp)
        }

        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, "\x19\x01")
            mstore(add(freeMemoryPointer, 2), domainSeparator)
            mstore(add(freeMemoryPointer, 34), structHash)
            orderDigest := keccak256(freeMemoryPointer, 66)
        }
    }

    function packOrderUidParams(bytes memory orderUid, bytes32 orderDigest, address owner, uint32 validTo)
        internal
        pure
    {
        require(orderUid.length == UID_LENGTH, "GPv2: uid buffer overflow");
        assembly {
            mstore(add(orderUid, 56), validTo)
            mstore(add(orderUid, 52), owner)
            mstore(add(orderUid, 32), orderDigest)
        }
    }
}
