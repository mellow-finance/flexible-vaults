// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../../src/oracles/OracleSubmitter.sol";
import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";

import "./Constants.sol";
import "./msvUSDLibrary.sol";

import "../common/ArraysLibrary.sol";

interface IEthereumMezoBridge {
    function bridgeERC20(address token, uint256 amount, address recipient) external;
}

contract Deploy is Script, Test {
    // Actors
    address public proxyAdmin = 0x54977739CF18B316f47B1e10E3068Bb3F04e08B6;
    address public lazyVaultAdmin = 0x0571A6ca8e1AD9822FA69e9cb7854110FD77d24d;
    address public activeVaultAdmin = 0x0f01301a869B7C15a782bd2e60beB08C8709CC08;
    address public oracleUpdater = 0x96ff6055DFdcd0d370D77b6dCd6a465438A613D5;
    address public curator = 0x3c9B9D820188fF57c8482EbFdF1093b1EFeFf068;

    address public pauser = 0x2EE0AB05EB659E0681DC5f2EabFf1F4D284B3Ef7;

    Vault public vault = Vault(payable(0x7207595E4c18a9A829B9dc868F11F3ADd8FCF626));

    address arbitrumSubvault0 = 0x9214Fb3563BC6FE429c608071CBc5278b0e43639;

    function _x() internal {
        OracleSubmitter submitter = new OracleSubmitter(
            lazyVaultAdmin, oracleUpdater, activeVaultAdmin, 0xccB10707cc3105178CBef8ee5b7DC84D5d1b277F
        );

        console.log("submitter: %s", address(submitter));
    }

    function testMerkle0() internal {
        bytes32 merkleRoot = 0x0486d4f796ab8f981c9bad0d8a2ad60e405ce408c7a4bc74a3a69d51a81dae28;
        Subvault subvault = Subvault(payable(vault.subvaultAt(0)));

        //vm.startPrank(lazyVaultAdmin);
        //vault.grantRole(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
        assertEq(subvault.verifier().merkleRoot(), merkleRoot, "merkle root mismatch");
        //subvault.verifier().setMerkleRoot(merkleRoot);
        //vm.stopPrank();

        bytes4 swapSelector = 0xe21fd0e9; // IMetaAggregationRouterV2.swap.selector
        bytes memory swapCalldata = hex"e21fd0e9000000000000000000000000000000000000000000000000000000000000002000000000000000000000000063242a4ea82847b20e506b63b0e2e2eff0cc6cb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001840000000000000000000000000000000000000000000000000000000000000154000000000000000450686970d20cc0c3700000000000000450686970d20cc0c37000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000041f47461377f901be643cd9561fe100ffb30aff50e60dfddf95aa80af3d3f61fe503dc904d600898baf859359b8cef39ef8f5b59d84b55476f239e822af52f7c831b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014400000000000000000000000009757bbb42b3faac201d5ba2374b9ac62dc77a584000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001c0000000000000004192ffdc4c78c0000000000000000000487a0d51cdc8d8000000000000000000450686970d20cc0c37000000000000000000000000a6aebc740000000000000000000000000000000000000000000aec0000000f42400000000000000000000000000000004f82e73edb06d29ff62c91ec8f5ff06571bdeb2900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000069b0221b0000000000000000000000000000000000000000000000000000000000001420000000000000000000000000000000000000000000000000000000000000000361f598cd000000000000000031439a79a3535d69b65c3be384840282b4ea0aa7b45a3c0e000000000000000031439a79a3535d69b65c3be384840282b4ea0aa7599d0714000000000000000031439a79a3535d69b65c3be384840282b4ea0aa70000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000aa000000000000000000000000000000000000000000000000000000000000011c00000000000000000000000006f40d4a6237c257fff2db00fa0510deeecd303eb80000000000000000004860e3a2aa3ba00000000000000450686970d20cc0c37000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000002808e7a9879d4325d23b9d6e0900000000000000015455c918e405a2831fbff8595c0aae35ee3db9d1000000000000000000000000000000000000000000000000000000000000008000000000000000000000000063242a4ea82847b20e506b63b0e2e2eff0cc6cb00000000000000000000000000000000000000000000000000000000000000040000000000000000000000000cba27c8e7115b4eb50aa14999bc0866674a96ecb0000000000000000000000000000000000000000000000000000000100ad139d00000000000000000000000000000000000000000000001cfd9eed858388e6653b9d6e0900000000000000015455c918e405a2831fbff8595c0aae35ee3db9d1000000000000000000000000000000000000000000000000000000000000008000000000000000000000000063242a4ea82847b20e506b63b0e2e2eff0cc6cb00000000000000000000000000000000000000000000000000000000000000040000000000000000000000000c1cd3d0913f4633b43fcddbcd7342bc9b71c676f0000000000000000000000000000000000000000000000000000000100eed0b5000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc280000000000000000000013d89647e80000000000000000012ed39b1ab42401e000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000afb361dc34d88133b9d6e0900000000000000025455c918e405a2831fbff8595c0aae35ee3db9d1000000000000000000000000000000000000000000000000000000000000008000000000000000000000000063242a4ea82847b20e506b63b0e2e2eff0cc6cb00000000000000000000000000000000000000000000000000000000000000040000000000000000000000000c7bbec68d12a0d1830360f8ec58fa599ba1b0e9b00000000000000000000000000000000000000000000000000000001000276a400000000000000000000000000000000000000000000000007f20393e7f4b80b3b9d6e0900000000000000035455c918e405a2831fbff8595c0aae35ee3db9d1000000000000000000000000000000000000000000000000000000000000008000000000000000000000000063242a4ea82847b20e506b63b0e2e2eff0cc6cb00000000000000000000000000000000000000000000000000000000000000040000000000000000000000000e0554a476a092703abdb3ef35c80e0d76d32939f000000000000000000000000fffd8963efd1fc6a506488495d951d5263988d25ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff890e63370000000000000103f77f93531ef2505d6e45b9dccf555d5a48400d08000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000460000000000044000000000024a540ec8c73322200d68e1b86c471a5c850854f22000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003e40947c2d9000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000007f20393e7f4b80b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d1a34369686ae59ac97ae4e1df5635ffda9ee7c000000000000000000000000129b3d9a0a6e4beab88f5cb1e57995d72a6e24f100000000000000000000000063242a4ea82847b20e506b63b0e2e2eff0cc6cb0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000007f20393e7f4b80b0000000000000000000000000000000000000000000000000000000045f3266e0000000000000000000000000000000000000000000000000000000045999d470000000000000000000000000000000000000000000000000000000069b01da6000000000000000000000000000000000000000000000000622a3c06b5948a030000000000000000000000000000000000000000000000000000000069b01d7c0000000000000000000000000000000000000000000000000000000069b01d860000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001850257d16bdbf4d52bc151db573b0f52300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002800000000000000000000000006044eef7179034319e2c8636ea885b37cbfa9aba00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000004199e4a20403cc6b8fd5e804cc90af440610365607f8da996b4cad0e165b3c0731267ce61321b08e0f1e0b698aba5c10afb20b733c83a6cc6cbe50d63fdda4063b1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041c0402f83c20a891469a5fce0c904dcb9bd2fe9efbcd609760a4b82ef93634cc6179508e911094ab0623874fefa3d85be6aabec9036b1c815893498156819777b1c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec78000000000000000000000000000065600000000000000000000000060b74e9800000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000060b74e9816717ef60000000000000003d1877a31a73c7cb31c02b9e7d7c336531562b21e000000000000000000000000000000000000000000000000000000000000008000000000000000000000000063242a4ea82847b20e506b63b0e2e2eff0cc6cb000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000e0e0e08a6a4b9dc7bd67bcb7aade5cf48157d444000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000000000000000000000000053e2d6238da30000003200000000000000000000000000000000000000008000000040d672e172ace70e0000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff890e63370000000000000103f77f93531ef2505d6e45b9dccf555d5a48400d08000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000460000000000044000000000024a540ec8c73322200d68e1b86c471a5c850854f22000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003e40947c2d900000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000060b74e9800000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d1a34369686ae59ac97ae4e1df5635ffda9ee7c000000000000000000000000129b3d9a0a6e4beab88f5cb1e57995d72a6e24f100000000000000000000000063242a4ea82847b20e506b63b0e2e2eff0cc6cb0000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000060b74e980000000000000000000000000000000000000000000000000000000060b8a74000000000000000000000000000000000000000000000000000000000603cd99d0000000000000000000000000000000000000000000000000000000069b01da6000000000000000000000000000000000000000000000000592a78b504eafee80000000000000000000000000000000000000000000000000000000069b01d7a0000000000000000000000000000000000000000000000000000000069b01d980000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000013be3629a1154d2b97ca64e55e07436f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002800000000000000000000000006044eef7179034319e2c8636ea885b37cbfa9aba000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000041c4ac6933600f65e1416f253d02145787b256d343c942ce105a703001e83977290f727280ee64fec4ccee699bbce283969d8cceef0a1cdb8851eb996387e1d4411b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000412e351e9e92b0d8ee451b29dc57b904fe7cbaca7af2ebcae112cb07b96b4dcc902de33cf5196d25ebb81631c408bcabfd2716212c5a099cf8e31e9f2a7d221d531b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4880000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006f40d4a6237c257fff2db00fa0510deeecd303eb000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002000000000000000000000000009757bbb42b3faac201d5ba2374b9ac62dc77a5840000000000000000000000000000000000000000000000450686970d20cc0c3700000000000000000000000000000000000000000000000000000000a5d961e900000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000000100000000000000000000000063242a4ea82847b20e506b63b0e2e2eff0cc6cb000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000450686970d20cc0c3700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bd7b22536f75726365223a226d656c6c6f772d7065726d697373696f6e2d6275696c646572222c22416d6f756e74496e555344223a22323832302e313132343735222c22416d6f756e744f7574555344223a22323830322e343138353035222c22416d6f756e744f7574223a2232373936343639333634222c22526f7574654944223a223561616533356434426f6c4d454c79473a32633837393361385142424532727675222c2254696d657374616d70223a313737333134393534377d000000";

        IVerifier.VerificationPayload memory swapPayload;
        swapPayload.verificationData = abi.encode(0xbcd786b56b1dc0af3a0604410b2fb1823745a8c8f2206663b64e01746444b105);
        swapPayload.verificationType = IVerifier.VerificationType.MERKLE_COMPACT;
        swapPayload.proof = new bytes32[](6);
        swapPayload.proof[0] = 0xc9bf73a082e08f38b22fd9748beef74f08ad3d2213c25cd0377a1313c87966e7;
        swapPayload.proof[1] = 0x68befa8076cc91e3fd515c5baedd3005d51926a40367e80f19ad1b9308d52344;
        swapPayload.proof[2] = 0xe44a498ad89c92f8728bbf1c3722f8bef93f27d9dfdaeada123bb50fd51cc300;
        swapPayload.proof[3] = 0x72169cda38b37f8720e194de49fae330f554f9f97b3a4d6ff4ca63a5e863af65;
        swapPayload.proof[4] = 0xf40341ff4fb0b74ed103df2c5d736cb153bf518da56c7d1aa38132dd698ce004;
        swapPayload.proof[5] = 0x6098363448cdd393f943579927faaf1257f18032386dedba9d2d22dd47b353b1;

        bytes memory approveCalldata = abi.encodeCall(IERC20.approve, (Constants.KYBERSWAP_ROUTER, 1274 ether));
        IVerifier.VerificationPayload memory approvePayload;
        approvePayload.verificationData = hex"0000000000000000000000000000000263fb29c3d6b0c5837883519ef05ea20a53a794e0123792e57cd75c079c5b35f69ba46bd55f7f8105cc74be47512c2e33000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        approvePayload.verificationType = IVerifier.VerificationType.CUSTOM_VERIFIER;
        approvePayload.proof = new bytes32[](6);
        approvePayload.proof[0] = 0xefebb83ce64e5f9a8ef900506f777bcae69580f408169659664a5112f46d56c4;
        approvePayload.proof[1] = 0x646797c5599d61fce01e9433db5255cecd46de47c6b7779924b33e8ac1c4df8f;
        approvePayload.proof[2] = 0x88f2be81cb2ceac1d0f5dd24e7f741a3157efcc65b479ce8ba084f978ec0991a;
        approvePayload.proof[3] = 0x640fbfc5fb42f34236192379332e0c0521436936eee37cdbd21df6295db0fff9;
        approvePayload.proof[4] = 0xf40341ff4fb0b74ed103df2c5d736cb153bf518da56c7d1aa38132dd698ce004;
        approvePayload.proof[5] = 0x6098363448cdd393f943579927faaf1257f18032386dedba9d2d22dd47b353b1;

        assertTrue(
            subvault.verifier().getVerificationResult(
                curator, Constants.KYBERSWAP_ROUTER, 0, swapCalldata, swapPayload
            ),
            "swap proof should be valid"
        );
        assertTrue(
            subvault.verifier().getVerificationResult(
                curator, Constants.FLUID, 0, approveCalldata, approvePayload
            ),
            "approve proof should be valid"
        );

        vm.startPrank(curator);
        subvault.call(Constants.FLUID, 0, approveCalldata, approvePayload);
        subvault.call(Constants.KYBERSWAP_ROUTER, 0, swapCalldata, swapPayload);
        vm.stopPrank();
    }

    function testMerkle1() internal {
        // "description": "IEthereumMezoBridge(0xF6680EA3b480cA2b72D96ea13cCAF2cFd8e6908c).bridgeERC20(USDC,any,msvUSD_Subvault_0_Mezo)",
        bytes32 merkleRoot = 0x7dc8902709b6299885c4bf395da90f46e1ef5c8568959e273c27be186571fed3;
        Subvault subvault = Subvault(payable(vault.subvaultAt(1)));

        //vm.startPrank(lazyVaultAdmin);
        //vault.grantRole(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
        //subvault.verifier().setMerkleRoot(merkleRoot);
        //vm.stopPrank();
        assertEq(subvault.verifier().merkleRoot(), merkleRoot, "merkle root mismatch");

        bytes memory bridgeCalldata = abi.encodeCall(IEthereumMezoBridge.bridgeERC20, (Constants.USDC, 10e6, 0x6F05747CdFe61b998f928CE509547CB630A981a1));
        IVerifier.VerificationPayload memory payload;
        payload.verificationData = hex"0000000000000000000000000000000263fb29c3d6b0c5837883519ef05ea20ab21639296f7d8708f9d8115d17b6e02e61e3d050762b5a34e9299c10255821db000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000";
        payload.verificationType = IVerifier.VerificationType.CUSTOM_VERIFIER;
        payload.proof = new bytes32[](3);
        payload.proof[0] = 0x36adef90cb8431992a8911e1cf5f19820e1d10e509552879f8d4b9cf1f0bdc37;
        payload.proof[1] = 0xa1b568b678a116913c6f18046041a731e1df62b083bcf34537a13ebe0c2e2f58;
        payload.proof[2] = 0xc14e763954d695eeb487f081aca04592a4fa9a70162839ffc41ba4d01e1f4b45;

        assertTrue(
            subvault.verifier().getVerificationResult(
                curator, 0xF6680EA3b480cA2b72D96ea13cCAF2cFd8e6908c, 0, bridgeCalldata, payload
            ),
            "bridge proof should be valid"
        );

        vm.startPrank(curator);
        subvault.call(0xF6680EA3b480cA2b72D96ea13cCAF2cFd8e6908c, 0, bridgeCalldata, payload);
        vm.stopPrank();
    }

    function run() external {
        testMerkle1();
        return;
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        if (true) {
            _x();
            return;
        }

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        TimelockController timelockController;

        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
            address[] memory executors = ArraysLibrary.makeAddressArray(abi.encode(pauser));
            timelockController = new TimelockController(0, proposers, executors, lazyVaultAdmin);
        }
        {
            uint256 i = 0;

            // lazyVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);

            // emergeny pauser roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, address(timelockController));
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
            holders[i++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));

            // oracle updater roles:
            holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleUpdater);

            // curator roles:
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
            holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
            holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, deployer);
            assembly {
                mstore(holders, i)
            }
        }
        address[] memory assets_ =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.MUSD));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Mezo Stable Vault", "msvUSD"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, lazyVaultAdmin, uint24(0), uint24(0), uint24(0), uint24(5e3)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005 ether,
                    suspiciousAbsoluteDeviation: 0.001 ether,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 20 hours,
                    depositInterval: 1 hours,
                    redeemInterval: 72 hours
                }),
                assets_
            ),
            defaultDepositHook: address($.redirectingDepositHook),
            defaultRedeemHook: address($.basicRedeemHook),
            queueLimit: 6,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        // queues setup
        vault.createQueue(0, true, proxyAdmin, Constants.USDC, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, Constants.USDT, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, Constants.MUSD, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.USDC, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.USDT, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.MUSD, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.USDC);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        // emergency pause setup
        timelockController.schedule(
            address(vault.shareManager()),
            0,
            abi.encodeCall(
                IShareManager.setFlags,
                (
                    IShareManager.Flags({
                        hasMintPause: true,
                        hasBurnPause: true,
                        hasTransferPause: true,
                        hasWhitelist: true,
                        hasTransferWhitelist: true,
                        globalLockup: type(uint32).max
                    })
                )
            ),
            bytes32(0),
            bytes32(0),
            0
        );

        {
            address[6] memory queues = [
                vault.queueAt(Constants.USDC, 0),
                vault.queueAt(Constants.USDT, 0),
                vault.queueAt(Constants.MUSD, 0),
                vault.queueAt(Constants.USDC, 1),
                vault.queueAt(Constants.USDT, 1),
                vault.queueAt(Constants.MUSD, 1)
            ];
            for (uint256 i = 0; i < queues.length; i++) {
                timelockController.schedule(
                    address(vault),
                    0,
                    abi.encodeCall(IShareModule.setQueueStatus, (queues[i], true)),
                    bytes32(0),
                    bytes32(0),
                    0
                );
            }
        }

        timelockController.renounceRole(timelockController.PROPOSER_ROLE(), deployer);
        timelockController.renounceRole(timelockController.CANCELLER_ROLE(), deployer);

        vault.renounceRole(Permissions.CREATE_QUEUE_ROLE, deployer);
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        console.log("Vault %s", address(vault));

        console.log("DepositQueue (USDC) %s", address(vault.queueAt(Constants.USDC, 0)));
        console.log("DepositQueue (USDT) %s", address(vault.queueAt(Constants.USDT, 0)));
        console.log("DepositQueue (MUSD) %s", address(vault.queueAt(Constants.MUSD, 0)));

        console.log("RedeemQueue (USDC) %s", address(vault.queueAt(Constants.USDC, 1)));
        console.log("RedeemQueue (USDT) %s", address(vault.queueAt(Constants.USDT, 1)));
        console.log("RedeemQueue (MUSD) %s", address(vault.queueAt(Constants.MUSD, 1)));

        console.log("Oracle %s", address(vault.oracle()));
        console.log("ShareManager %s", address(vault.shareManager()));
        console.log("FeeManager %s", address(vault.feeManager()));
        console.log("RiskManager %s", address(vault.riskManager()));

        console.log("Timelock controller:", address(timelockController));

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < reports.length; i++) {
                reports[i].asset = assets_[i];
            }
            reports[0].priceD18 = 1e30;
            reports[1].priceD18 = 1e30;
            reports[2].priceD18 = 1 ether;

            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
            // uint256 timestamp = oracle.getReport(Constants.USDC).timestamp;
            // for (uint256 i = 0; i < reports.length; i++) {
            //     oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(timestamp));
            // }
        }

        vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);

        revert("ok");
    }

    function _createSubvault0() internal {
        IRiskManager riskManager = vault.riskManager();
        vm.startPrank(lazyVaultAdmin);

        vault.grantRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, lazyVaultAdmin);
        vault.grantRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, lazyVaultAdmin);
        address verifier = vault.verifierFactory().create(0, proxyAdmin, abi.encode(vault, bytes32(0)));

        address subvault0 = vault.createSubvault(0, proxyAdmin, verifier);
        riskManager.allowSubvaultAssets(
            subvault0, ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT))
        );
        riskManager.setSubvaultLimit(subvault0, type(int256).max / 2);
        vm.stopPrank();
    }

    function _deploySwapModule(address subvault) internal returns (address swapModule, address[] memory assets) {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[3] memory tokens = [Constants.USDT, Constants.USDC, Constants.CRV];
        address[] memory actors =
            ArraysLibrary.makeAddressArray(abi.encode(curator, tokens, tokens, Constants.KYBERSWAP_ROUTER));
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE
            )
        );

        vm.startBroadcast(deployerPk);
        swapModule = swapModuleFactory.create(
            0, proxyAdmin, abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, 0.995e8, actors, permissions)
        );
        vm.stopBroadcast();
        return (swapModule, ArraysLibrary.makeAddressArray(abi.encode(tokens)));
    }

    function _createSubvault0Proofs() internal returns (bytes32 merkleRoot, SubvaultCalls memory calls) {
        address payable subvault0Mainnet = payable(vault.subvaultAt(0));
        (address swapModule, address[] memory swapModuleAssets) = _deploySwapModule(subvault0Mainnet);

        msvUSDLibrary.Info memory info = msvUSDLibrary.Info({
            curator: curator,
            subvaultEth: subvault0Mainnet,
            subvaultArb: arbitrumSubvault0,
            swapModule: swapModule,
            subvaultEthName: "subvault0:ethereum",
            subvaultArbName: "subvault0:arbitrum",
            targetChainName: "Arbitrum",
            oftUSDT: Constants.ETHEREUM_USDT_OFT_ADAPTER,
            fUSDT: Constants.ETHEREUM_FLUID_USDT_FTOKEN,
            fUSDC: Constants.ETHEREUM_FLUID_USDC_FTOKEN,
            swapModuleAssets: swapModuleAssets,
            kyberRouter: Constants.KYBERSWAP_ROUTER,
            kyberSwapAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.FLUID))
        });

        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = msvUSDLibrary.getSubvault0Proofs(info);

        IVerifier verifier = Subvault(subvault0Mainnet).verifier();

        vm.startPrank(lazyVaultAdmin);
        verifier.setMerkleRoot(merkleRoot);
        vm.stopPrank();

        console.log("Subvault0 Merkle Root at verifier %s:", address(verifier));
        console.logBytes32(merkleRoot);

        string[] memory descriptions = msvUSDLibrary.getSubvault0Descriptions(info);
        ProofLibrary.storeProofs("ethereum:msvUSD:subvault0", merkleRoot, leaves, descriptions);

        calls = msvUSDLibrary.getSubvault0Calls(info, leaves);

        _runChecks(verifier, calls);
    }

    function _runChecks(IVerifier verifier, SubvaultCalls memory calls) internal view {
        for (uint256 i = 0; i < calls.payloads.length; i++) {
            AcceptanceLibrary._verifyCalls(verifier, calls.calls[i], calls.payloads[i]);
        }
    }
}
