// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "../../src/permissions/protocols/CowSwapVerifier.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {GPv2Signing} from "@cowswap/contracts/GPv2Settlement.sol";

contract Unit is Test {
    function testX() external {
        address settlement = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

        CowSwapVerifier verifierSingleton = new CowSwapVerifier(settlement, "Mellow", 1);

        address admin = address(this);

        CowSwapVerifier verifier =
            CowSwapVerifier(address(new TransparentUpgradeableProxy(address(verifierSingleton), admin, "")));

        verifier.initialize(abi.encode(admin, new address[](0), new bytes32[](0)));
        verifier.grantRole(verifier.CALLER_ROLE(), admin);

        verifier.verifyCall(
            admin, settlement, 0, abi.encodeCall(GPv2Signing.setPreSignature, (new bytes(56), false)), new bytes(0)
        );

        // GPv2Order.Data memory order;
        // verifier.setOrderStatus(order, true);

        // address subvault = address(uint160(1341234123));

        // bytes memory orderUid = new bytes(56);
        // GPv2Order.packOrderUidParams(orderUid, orderDigest, subvault, validTo);

        // bytes32 digest = abi.encodeCall(GPv2Signing.setPreSignature, (orderUid, true));

        // verifier.verifyCall(
        //     admin, settlement, 0, abi.encodeCall(GPv2Signing.setPreSignature, (new bytes(56), false)), new bytes(0)
        // );

        // verifier.verifyCall(
        //     admin, settlement, 0, abi.encodeCall(GPv2Settlement.invalidateOrder, (new bytes(56))), new bytes(0)
        // );
        // verifier.verifyCall(
        //     admin, settlement, 0, abi.encodeCall(GPv2Settlement.invalidateOrder, (new bytes(128))), new bytes(0)
        // );
    }
}
