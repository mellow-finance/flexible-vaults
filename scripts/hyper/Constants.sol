// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";
import "../common/interfaces/Imports.sol";

library Constants {
    address public constant USDC = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;
    address public constant HYPE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    function protocolDeployment() internal pure returns (ProtocolDeployment memory) {
        return ProtocolDeployment({
            deploymentName: DEPLOYMENT_NAME,
            deploymentVersion: DEPLOYMENT_VERSION,
            cowswapVaultRelayer: address(0),
            cowswapSettlement: address(0),
            eigenLayerDelegationManager: address(0),
            eigenLayerStrategyManager: address(0),
            eigenLayerRewardsCoordinator: address(0),
            symbioticVaultFactory: address(0),
            symbioticFarmFactory: address(0),
            wsteth: address(0),
            weth: address(0),
            proxyAdmin: 0xb1E5a8F26C43d019f2883378548a350ecdD1423B,
            deployer: 0x4d551d74e851Bd93Ce44D5F588Ba14623249CDda,
            factoryImplementation: Factory(0x000000092C4e111CBA592380b258d94B37038B63),
            factory: Factory(0x00000003cEe0DbFb61dD598CD7978993A37f8F8C),
            consensusFactory: Factory(0x4C496F31a4D46044E57214f282420b8b078edf56),
            depositQueueFactory: Factory(0x66B1a68F8CE628d508290d5C1d74Bc50416BDF90),
            redeemQueueFactory: Factory(0x0a69B47c3E0bD7e5B1E1Db95d6C0b2914607e19f),
            feeManagerFactory: Factory(0x71a4D9739A35B4e86118F3a45bae662Bcc9357FA),
            oracleFactory: Factory(0xe4E2b5Db061A731D96b9267464c17Ba282326Ce7),
            riskManagerFactory: Factory(0x95ff5434A51f3E42fCeD2Cae36548d95e56bAb10),
            shareManagerFactory: Factory(0x3755c140b90dC4E6b1A6361279B2C2eCc0358689),
            subvaultFactory: Factory(0x72244F91242244E62Af3417294B828E262EbdfE7),
            vaultFactory: Factory(0xC7332ab052350Bbb9075f1160cc7073428981638),
            verifierFactory: Factory(0x40383d404e570D95fF68945d2a334fb2f5ecE0f6),
            erc20VerifierFactory: Factory(0x7025132709b3B01D663D97e56eae37988471c75a),
            symbioticVerifierFactory: Factory(address(0)),
            eigenLayerVerifierFactory: Factory(address(0)),
            swapModuleFactory: Factory(address(0)),
            accountFactory: Factory(0xCda7916AA830B4dAb8295FBa92953d5251f5FDFa),
            consensusImplementation: Consensus(0x00000008086A535Febd23fBd8C8F7d9D987930B7),
            depositQueueImplementation: DepositQueue(payable(0x0000000A151048f4f01996a9Cd35a982F5830251)),
            syncDepositQueueImplementation: SyncDepositQueue(payable(0x00000007d43702d556707a63132d42BcDf47E7dD)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x00000003e7D5d1EDF85b03b974aAc374d0FCB8A1)),
            redeemQueueImplementation: RedeemQueue(payable(0x00000002F8d3f0D03E9Ce461791F6A0a9d28D0f6)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0x000000047f8812704050cB86E549Fe8f28512A2D)),
            feeManagerImplementation: FeeManager(0x00000003bf6bEC83fA8ff147b04176B82F591497),
            oracleImplementation: Oracle(0x00000001bdbaFbE0Fb55b7d74a6dB74D1DA6047E),
            riskManagerImplementation: RiskManager(0x0000000a0d139B4B7add54D70e2a4ED3c81C513C),
            tokenizedShareManagerImplementation: TokenizedShareManager(0x0000000f2a485f26efd108144cCBFc46b18cB3e0),
            burnableTokenizedShareManagerImplementation: BurnableTokenizedShareManager(address(0)),
            basicShareManagerImplementation: BasicShareManager(0x0000000454d68af6Faf344e8acAa372f136749c5),
            subvaultImplementation: Subvault(payable(0x00000008c8A185371Ab8eB28bbdb875cd526B69C)),
            verifierImplementation: Verifier(0x00000007eEEbCA71f6b261061136BaFA666218A5),
            vaultImplementation: Vault(payable(0x00000002334dBFa3B92467eA9Eb970ec1e067377)),
            bitmaskVerifier: BitmaskVerifier(0x0000000f7DA5A9480262Ac3D654b1F4aA9F604B8),
            eigenLayerVerifierImplementation: EigenLayerVerifier(address(0)),
            erc20VerifierImplementation: ERC20Verifier(0x000000010849B881DA846FFEb1078A433284F8D0),
            symbioticVerifierImplementation: SymbioticVerifier(address(0)),
            vaultConfigurator: VaultConfigurator(0x00000003986f4F63CdBAB0f5d78fff57495fee85),
            basicRedeemHook: BasicRedeemHook(0x000000033FDa28b7025Fb16D53F81c3C1F78d572),
            redirectingDepositHook: RedirectingDepositHook(0x0000000Cbd64305e1668dB5F8a542c2c7EC61640),
            lidoDepositHook: LidoDepositHook(address(0)),
            oracleHelper: OracleHelper(0x00000005dc87A3230E0F3195C5e9220DCFF1E182),
            swapModuleImplementation: SwapModule(payable(address(0))),
            mellowAccountV1Implementation: MellowAccountV1(0x00000001f879d5dAE0066E714867014Ec265F4ab)
        });
    }

    OracleSubmitterFactory public constant oracleSubmitterFactory =
        OracleSubmitterFactory(0x0000000dB76510D5B4D99df16160469bF782B227);

    DeployVaultFactoryRegistry public constant deployVaultFactoryRegistry =
        DeployVaultFactoryRegistry(0x00000008656A21E6f690d40BAc97736f62E54853);

    DeployVaultFactory public constant deployVaultFactory =
        DeployVaultFactory(0x00000005b5Dda102b4F9104fE8c537f816ac76D4);
}
