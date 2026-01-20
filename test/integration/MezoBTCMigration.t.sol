// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "../../scripts/common/ArraysLibrary.sol";
import "../Imports.sol";

contract Integration is Test {
    address admin = 0xb7b2ee53731Fc80080ED2906431e08452BC58786;

    address btcVault = 0xc8e9223CF09012c0E1920aD59618e35C84Ad99F4;
    address cbBtcVault = 0x02c16F03E779fa9757E5c634c21E6c3c48784E92;

    address newBtcVault = 0xa8A3De0c5594A09d0cD4C8abc4e3AaB9BaE03F36;
    address newCbBtcVault = 0x63a76a4a94cAB1DD49fcf0d7E3FC53a78AC8Ec5C;

    function btcHolders() internal pure returns (address[] memory) {
        return ArraysLibrary.makeAddressArray(
            abi.encode(
                [
                    0x08385BF79f956270Cc849648Cb320C225672FADb,
                    0x173cC2106034E373Df29c3f2533E42800Af5b58f,
                    0x1CafBDD4cEDFaC589Fc6f7265357f917dbC923CD,
                    0x2a753D7Ec940E8fea6d85139358c22B92f77e6a9,
                    0x30e045e5932F5D668592BC334F2d6AD0B23cACDC,
                    0x330198F0FB0A0881958D3095E0cBDC4Bc3DCe22c,
                    0x37403db50E79631838cebe89a62FE2B34C31C184,
                    0x3C4CCC30a0428818368848F497b6CdF0F58f3Cb4,
                    0x4311bF7e926dd1AD33B8D79294762583F9dFD641,
                    0x439AE60bcDaA65905A96dAD9bcd47eA5B0936b05,
                    0x489D69939b4Aca357f630055e351A81F1Fbb7Fb6,
                    0x4AfD8663FEed49FddaaD1294D08FF36bB1040298,
                    0x4d551d74e851Bd93Ce44D5F588Ba14623249CDda,
                    0x4F5FE8DA30C1c11fE537730940CeD62AC37Ea371,
                    0x609076BbA6f0a303a5Cac58e900C8ac611cb15b5,
                    0x72597dE06E58Ad98C6F66c6cD8FAb1dD9F73a2ca,
                    0x73166CD97EB14456169826E437037dB2ABB22d91,
                    0x7426428C645f4fC4E0aFF79Be4909CA5a373800d,
                    0x7f8917FbE06b5577538Fb8D98367c4aaae4515a6,
                    0x80F849a5e7cb6CF07F1146135BC9c6BfF3F004f8,
                    0x865c75a12839f8DCf7315dDFA334418DcDe8fc04,
                    0x8D4Fbf807AEfECFfc824AaEf7d738703B6CF24eb,
                    0x92b52e6441A9e2E03d080E951249d93dF222f855,
                    0x938Eb8D151984b28080C29456B7892b0C4C0A120,
                    0x976FF5353B397ca3934Ba1AeBa258C0844Eb2B46,
                    0x9C7c2B00Ea7800fbe32FD50d844645Db07C27a74,
                    0xA01Eb89517AF8ea5755F288d3D35630F9D6315a8,
                    0xa3612639A90F9cAD15C330223C71D2E979694116,
                    0xA8e2d554aDf787F3c20e49E8Df6C0490871E5588,
                    0xB073053e70333aBd3c1161f4a64eBB1f15bc04e9,
                    0xb7102F2E2546BBEd1c9206dDD88ab7554c6a8A30,
                    0xC6f0F6E69b07Db21aE188F10ba4d71De234c14cC,
                    0xd1543Ae2cc815b510d64a404EC58B3d4179cB2B5,
                    0xE130554497691a53890Ab3d04B881762ED635ae7,
                    0xE97F557C7991ed5290234b3225254d12df62732d,
                    0xecfe3D1898Cc508657Cd032F6C41f5Af0CEfbAE2,
                    0xEE4a267E98260aCf829Ca9dC6c9f3d5d82183Bce,
                    0xF17b03b741bB7162bD5236203B59197d216b7F3D,
                    0xFe36DBaB33E154D8fC2957eE6e43088f7999eEa3,
                    0xFEf6503A2cf17DB14fae5d5874A50522677cFcEc
                ]
            )
        );
    }

    function cbBtcHolders() internal pure returns (address[] memory) {
        return ArraysLibrary.makeAddressArray(
            abi.encode(
                [
                    0x3C4CCC30a0428818368848F497b6CdF0F58f3Cb4,
                    0x4d551d74e851Bd93Ce44D5F588Ba14623249CDda,
                    0x609076BbA6f0a303a5Cac58e900C8ac611cb15b5,
                    0x640AF57EB6d96780c5265c66Bd0351F47b09a0ad,
                    0x664a24920464FfA1aFC4Ec75CE514005Af8cd16F,
                    0x75cBddFc50aaa5CCc8B9982539aBAce4a501766d,
                    0x7D431bE16cc6b72FC3b6794b37928e471047E5Ea,
                    0x8D106c747CD21272D4C9Ff0Af8d53A9C9AcA25d2,
                    0xC6f0F6E69b07Db21aE188F10ba4d71De234c14cC,
                    0xe448d9D70eFe95714e38d210E58d458dab0A77d5,
                    0xF495C8BEca7016674F67BE25e485DbF41dc5A151
                ]
            )
        );
    }

    function logCall(address target, bytes memory data) internal pure {
        console2.log("{");
        console2.log('  "to": "%s",', target);
        console2.log('  "value": "0",');
        console2.log('  "data": "%s",', vm.toString(data));
        console2.log('  "contractMethod": {');
        console2.log('    "inputs": [],');
        console2.log('     "name": "fallback",');
        console2.log('     "payable": true');
        console2.log("  },");
        console2.log('  "contractInputsValues": null');
        console2.log("},");
    }

    function migrate(Vault vault, Vault newVault, address[] memory holders) internal {
        BasicShareManager shareManager = BasicShareManager(address(vault.shareManager()));
        uint256 totalShares = shareManager.totalShares();
        uint256 checksum = 0;
        uint256[] memory sharesOf = new uint256[](holders.length);
        for (uint256 i = 0; i < holders.length; i++) {
            uint256 shares = shareManager.sharesOf(holders[i]);
            sharesOf[i] = shares;
            checksum += shares;
        }

        if (checksum != totalShares) {
            revert("Invalid checksum");
        }

        Subvault subvault = Subvault(payable(vault.subvaultAt(0)));
        IVerifier verifier = subvault.verifier();

        vm.startPrank(admin);

        vault.grantRole(verifier.ALLOW_CALL_ROLE(), admin);
        logCall(address(vault), abi.encodeCall(vault.grantRole, (verifier.ALLOW_CALL_ROLE(), admin)));

        vault.grantRole(verifier.CALLER_ROLE(), admin);
        logCall(address(vault), abi.encodeCall(vault.grantRole, (verifier.CALLER_ROLE(), admin)));

        address[] memory assets = new address[](vault.getAssetCount());
        {
            IVerifier.CompactCall[] memory calls = new IVerifier.CompactCall[](assets.length);

            for (uint256 i = 0; i < assets.length; i++) {
                assets[i] = vault.assetAt(i);
                calls[i] = IVerifier.CompactCall({who: admin, where: assets[i], selector: IERC20.transfer.selector});
            }

            logCall(address(verifier), abi.encodeCall(verifier.allowCalls, (calls)));
            verifier.allowCalls(calls);
        }

        {
            IVerifier.VerificationPayload memory payload;
            for (uint256 i = 0; i < assets.length; i++) {
                uint256 amount = IERC20(assets[i]).balanceOf(address(subvault));
                bytes memory response =
                    subvault.call(assets[i], 0, abi.encodeCall(IERC20.transfer, (admin, amount)), payload);
                logCall(
                    address(subvault),
                    abi.encodeCall(
                        subvault.call, (assets[i], 0, abi.encodeCall(IERC20.transfer, (admin, amount)), payload)
                    )
                );

                assertTrue(abi.decode(response, (bool)));

                address queue = newVault.queueAt(assets[i], 0);
                IERC20(assets[i]).approve(queue, amount);
                logCall(assets[i], abi.encodeCall(IERC20.approve, (queue, amount)));

                IDepositQueue(queue).deposit(uint224(amount), address(0), new bytes32[](0));
                logCall(queue, abi.encodeCall(IDepositQueue.deposit, (uint224(amount), address(0), new bytes32[](0))));
            }
        }

        TokenizedShareManager newShareManager = TokenizedShareManager(address(newVault.shareManager()));
        assertEq(newShareManager.sharesOf(admin), totalShares);

        uint256[] memory newSharesBefore = new uint256[](holders.length);
        for (uint256 i = 0; i < holders.length; i++) {
            newSharesBefore[i] = newShareManager.sharesOf(holders[i]);
        }

        for (uint256 i = 0; i < holders.length; i++) {
            bool success = newShareManager.transfer(holders[i], sharesOf[i]);
            logCall(address(newShareManager), abi.encodeCall(newShareManager.transfer, (holders[i], sharesOf[i])));
            assertTrue(success);
        }

        vm.stopPrank();
        for (uint256 i = 0; i < holders.length; i++) {
            assertEq(newSharesBefore[i] + sharesOf[i], newShareManager.sharesOf(holders[i]));
        }
    }

    function testMezoMigrationBtcVault_NO_CI() external {
        Vault vault = Vault(payable(btcVault));
        Vault newVault = Vault(payable(newBtcVault));

        address[] memory holders = btcHolders();
        migrate(vault, newVault, holders);
    }

    function testMezoMigrationCbBtcVault_NO_CI() external {
        Vault vault = Vault(payable(cbBtcVault));
        Vault newVault = Vault(payable(newCbBtcVault));

        address[] memory holders = cbBtcHolders();
        migrate(vault, newVault, holders);
    }
}
