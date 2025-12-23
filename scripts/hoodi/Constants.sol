// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";
import "../common/interfaces/Imports.sol";

library Constants {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xdb7057418E9272216551a6eA07876a1e26D306f9;
    address public constant WSTETH = 0x7E99eE3C66636DE415D2d7C880938F2f40f94De4;

    address public constant LIDO_V3_VAULT_FACTORY = 0x7Ba269a03eeD86f2f54CB04CA3b4b7626636Df4E;

    address public constant deployer = 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3;
    address public constant proxyAdmin = 0x0A8592F142c4Cc5653890a57A3F4ddDA90E9b20e;

    function protocolDeployment() internal pure returns (ProtocolDeployment memory) {
        return ProtocolDeployment({
            deploymentName: DEPLOYMENT_NAME,
            deploymentVersion: DEPLOYMENT_VERSION,
            eigenLayerDelegationManager: address(0),
            eigenLayerStrategyManager: address(0),
            eigenLayerRewardsCoordinator: address(0),
            symbioticVaultFactory: address(0),
            symbioticFarmFactory: address(0),
            wsteth: WSTETH,
            weth: WETH,
            proxyAdmin: proxyAdmin,
            deployer: deployer,
            factoryImplementation: Factory(0xba387fD8c8D57fe00f5BE51fDDf84cC3d3134758),
            factory: Factory(0xBcE5209147fCD81e1d7bebCc2deA7C5Bf6a212D9),
            consensusFactory: Factory(address(0)),
            depositQueueFactory: Factory(0x4c76069A21bFF5b6888D9598774a367e6830eA55),
            redeemQueueFactory: Factory(0x18Ae36d4EFe5739306AE1c4713fcb7A345fea2B5),
            feeManagerFactory: Factory(0x308278fEd0E278120fA05d5Cb24851e76636C7eA),
            oracleFactory: Factory(0xCa1F18FF20071FAF91FDfFC774a9DDaBfDbBcef8),
            riskManagerFactory: Factory(0x41482c4C573318dE2a00B2d28991780d96973D5a),
            shareManagerFactory: Factory(0x3485ddec4F917BdFc2546E85a653649447F05ad8),
            subvaultFactory: Factory(0x66A30eFC3822f54bf47947053ad2486fEFB453B2),
            vaultFactory: Factory(0x3Ea3DE622BCfa8E26D06bBFd5a9Ae6EaA6468748),
            verifierFactory: Factory(0xa5FB3c18BC688d6BfD3b328c1d1669280a149BFe),
            erc20VerifierFactory: Factory(address(0)),
            symbioticVerifierFactory: Factory(address(0)),
            eigenLayerVerifierFactory: Factory(address(0)),
            swapModuleFactory: Factory(address(0)),
            consensusImplementation: Consensus(address(0)),
            depositQueueImplementation: DepositQueue(payable(0xff1DD240FDeA3d39FB21F30005496d38D1d230dE)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(address(0))),
            redeemQueueImplementation: RedeemQueue(payable(0xCD144B34fd9549756D1C67b0BF8211beDBb5bbf5)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(address(0))),
            feeManagerImplementation: FeeManager(0xB28FF214b6e0e6D846Cc5aeedB48a8B295200b75),
            oracleImplementation: Oracle(0x20877BC866Cc20961fC3667068Ff1BcddBF97aA6),
            riskManagerImplementation: RiskManager(0xB04dFEeD673eF3e554864C9a2b58d33eC157DA11),
            tokenizedShareManagerImplementation: TokenizedShareManager(0xA0EA7d188Ce49E8c31148F3396EFf5db7b19Cb73),
            basicShareManagerImplementation: BasicShareManager(address(0)),
            subvaultImplementation: Subvault(payable(0x51FBd7acC12F5F20617FF117875a24Ae7b6EF291)),
            verifierImplementation: Verifier(0x03c024011Fa98b792a66105A657987D75bBF2E15),
            vaultImplementation: Vault(payable(0xbB611d96aE00Ba4DB729ACABC6648C7B75B9cf63)),
            bitmaskVerifier: BitmaskVerifier(0xE3899AF4c0397eaB3D5B501d7A91D12b5f9dCc69),
            eigenLayerVerifierImplementation: EigenLayerVerifier(address(0)),
            erc20VerifierImplementation: ERC20Verifier(address(0)),
            symbioticVerifierImplementation: SymbioticVerifier(address(0)),
            vaultConfigurator: VaultConfigurator(0x46E3D414943F26Db374342f725f201a72591F3Ef),
            basicRedeemHook: BasicRedeemHook(0x49cA3c4dE2a0796aC81F84A55701a9071942F60B),
            redirectingDepositHook: RedirectingDepositHook(0x3f19968b5AAcaaf28560D9aDD91C41cE59734742),
            lidoDepositHook: LidoDepositHook(address(0)),
            oracleHelper: OracleHelper(0xC3Ed3501ff78abc36d2C6CEA92d0e82d9a9BB63e),
            swapModuleImplementation: SwapModule(payable(0))
        });
    }
}
