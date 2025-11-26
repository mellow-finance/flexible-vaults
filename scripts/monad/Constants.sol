// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";
import "../common/interfaces/Imports.sol";

library Constants {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    address public constant MON = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WMON = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A;
    address public constant SHMON = 0x1B68626dCa36c7fE922fD2d55E4f631d962dE19c;

    address public constant USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
    address public constant USDT0 = 0xe7cd86e13AC4309349F30B3435a9d337750fC82D;
    address public constant AUSD = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;

    address public constant MORPHO_STEAKHOUSE_MON = 0x80bDee8E6a274AE08F89a4A59Ba68046612a76eb;
    address public constant MORPHO_STEAKHOUSE_USDC = 0x802c91d807A8DaCA257c4708ab264B6520964e44;
    address public constant MORPHO_STEAKHOUSE_USDT = 0x961a59Fe249b9795FAE7fA35f9E89629689D5278;
    address public constant MORPHO_STEAKHOUSE_AUSD = 0xBC03E505EE65f9fAa68a2D7e5A74452858C16D29;

    address public constant AAVE_CORE = 0x80F00661b13CC5F6ccd3885bE7b4C9c67545D585;
    address public constant AAVE_V3_ORACLE = 0x94bbA11004B9877d13bb5E1aE29319b6f7bDEdD4;

    function protocolDeployment() internal pure returns (ProtocolDeployment memory) {
        return ProtocolDeployment({
            deploymentName: DEPLOYMENT_NAME,
            deploymentVersion: DEPLOYMENT_VERSION,
            eigenLayerDelegationManager: address(0),
            eigenLayerStrategyManager: address(0),
            eigenLayerRewardsCoordinator: address(0),
            symbioticVaultFactory: address(0),
            symbioticFarmFactory: address(0),
            wsteth: address(0),
            weth: WMON,
            proxyAdmin: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
            deployer: 0x4d551d74e851Bd93Ce44D5F588Ba14623249CDda,
            // --- factories ---
            factoryImplementation: Factory(0x0000000834bD05fe8A94b5e0bFeC2A58A4C9171E),
            factory: Factory(0x000000049057E402f46800CDC08199b1358a7691),
            erc20VerifierFactory: Factory(0xC14BCd44686EE3eAF483EdC5436d93e97Ac50D71),
            symbioticVerifierFactory: Factory(address(0)),
            eigenLayerVerifierFactory: Factory(address(0)),
            riskManagerFactory: Factory(0x195b23BA895ed8c951A093D295a33ecbE2BD8EDD),
            subvaultFactory: Factory(0x5e11c97dB901EdD8932fdaA77b015da89F3f289E),
            verifierFactory: Factory(0x48766B2e6B321f6550988d1A2e09b42E91708759),
            vaultFactory: Factory(0x04c0287DEdE16e0C04A1C2A52F31400a88f1dF4c),
            shareManagerFactory: Factory(0xFA6CD2822912f86f17429683334F2B79FB5cd7E7),
            consensusFactory: Factory(0x2e84d9E713610d7eAFcDF7f998ce1Bdb835F5668),
            depositQueueFactory: Factory(0xa67330bb89668bA66502a6D6670dACf5F334eb53),
            redeemQueueFactory: Factory(0xA92CeA07d6009DE8F2AA377a4298dECCF94d942a),
            feeManagerFactory: Factory(0xDC40601EeE986E739831A96669F931EB818F43d2),
            oracleFactory: Factory(0x2c2ca09e5511bd69fFe9f156254b901DdC4f7FC5),
            swapModuleFactory: Factory(address(0)),
            // --- implementations ---
            consensusImplementation: Consensus(0x000000005AB29dAA855DfA661d8D9D25cD88c103),
            depositQueueImplementation: DepositQueue(payable(0x00000004F672aA091EbF44545cb8aE75143d8F4c)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x00000008D840ca76629607583C697FEdFA5fdd49)),
            redeemQueueImplementation: RedeemQueue(payable(0x00000004051f95d5836fF4149ca4a26B5Cfb8784)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0x00000002CB862cEdD58B73B24996f54E43a3E00f)),
            feeManagerImplementation: FeeManager(0x00000005e070fE45D9bc67A4E3201994347Ec9F5),
            oracleImplementation: Oracle(0x0000000cCDCc8A633bC9738fD8D3129e70f7a049),
            riskManagerImplementation: RiskManager(0x00000004d3A91Eb46d4F405bf539EeaE30A01782),
            tokenizedShareManagerImplementation: TokenizedShareManager(0x0000000F017D7077E34F4292E034478c371EB2C3),
            basicShareManagerImplementation: BasicShareManager(0x00000001198a8ac01F183Cfc340FdBF01b441C83),
            subvaultImplementation: Subvault(payable(0x000000019aEA95f32aCcBD160B12Dc39C3b6c0A7)),
            verifierImplementation: Verifier(0x00000001eA707eC337425AEB128d5C92EbAc3dA0),
            vaultImplementation: Vault(payable(0x000000061Cf24abc52E54BA275579e21E96e7716)),
            bitmaskVerifier: BitmaskVerifier(0x000000019a3e622ee54B1F6e155fB740D1fd9F0F),
            erc20VerifierImplementation: ERC20Verifier(0x00000009710AebAE63B94487a7d4A0B07e6c4837),
            symbioticVerifierImplementation: SymbioticVerifier(address(0)),
            eigenLayerVerifierImplementation: EigenLayerVerifier(address(0)),
            swapModuleImplementation: SwapModule(payable(address(0))),
            // --- helpers / hooks ---
            vaultConfigurator: VaultConfigurator(0x0000000594E51babd99Dae398E877C474201F1a5),
            basicRedeemHook: BasicRedeemHook(0x00000001D757B0554F564d88C6855ccD9BaB5B6c),
            redirectingDepositHook: RedirectingDepositHook(0x0000000Ef1A84Ae7D455249D61d33e6397C46D72),
            lidoDepositHook: LidoDepositHook(address(0)),
            oracleHelper: OracleHelper(0x00000002449a991F159727e9AA64583a560e5efD)
        });
    }
}
