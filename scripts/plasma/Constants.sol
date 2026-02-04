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

    address public constant XPL = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WXPL = 0x6100E367285b01F48D07953803A2d8dCA5D19873;
    address public constant WSTUSR = 0x2a52B289bA68bBd02676640aA9F605700c9e5699;
    address public constant USDT0 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    address public constant SYRUP_USDT = 0xC4374775489CB9C56003BF2C9b12495fC64F0771;
    address public constant WETH = 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB;
    address public constant WSTETH = 0xe48D935e6C9e735463ccCf29a7F11e32bC09136E;

    address public constant WSTETH_ETHEREUM = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address public constant FLUID_VAULT_T1_RESOLVER = 0x704625f79c83c3e1828fbb732642d30eBc8663e6;
    address public constant FLUID_WSTUSR_USDT0_EXCHANGE_ORACLE = 0x0eaA355bcD10ddDe3255911D1A234748a1043b0E;
    address public constant AAVE_V3_ORACLE = 0x33E0b3fc976DC9C516926BA48CfC0A9E10a2aAA5;
    uint256 public constant STRETH_FLUID_WSTUSR_USDT0_NFT_ID = 2048;

    address public constant STRETH_ETHEREUM_SUBVAULT_0 = 0x90c983DC732e65DB6177638f0125914787b8Cb78;
    address public constant STRETH_ETHEREUM_SUBVAULT_5 = 0xECf3BDE9f50F71edE67E05050123b64b519DF55C;

    address public constant CCIP_PLASMA_ROUTER = 0xcDca5D374e46A6DDDab50bD2D9acB8c796eC35C3;
    uint64 public constant CCIP_PLASMA_CHAIN_SELECTOR = 9335212494177455608;

    address public constant CCIP_ETHEREUM_ROUTER = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    uint64 public constant CCIP_ETHEREUM_CHAIN_SELECTOR = 5009297550715157269;

    uint256 public constant PLASMA_FLUID_WSTUSR_USDT_NFT_ID = 2048;
    address public constant PLASMA_FLUID_WSTUSR_USDT_VAULT = 0xBc345229C1b52e4c30530C614BB487323BA38Da5;

    uint32 public constant LAYER_ZERO_PLASMA_EID = 30383;
    uint32 public constant LAYER_ZERO_ETHEREUM_EID = 30101;

    address public constant ETHEREUM_USDT_OFT_ADAPTER = 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee;
    address public constant PLASMA_USDT_OFT_ADAPTER = 0x02ca37966753bDdDf11216B73B16C1dE756A7CF9;

    address public constant ETHEREUM_WSTUSR_OFT_ADAPTER = 0xab17c1fE647c37ceb9b96d1c27DD189bf8451978;
    address public constant PLASMA_WSTUSR_OFT_ADAPTER = 0x2a52B289bA68bBd02676640aA9F605700c9e5699;

    address public constant STRETH = 0x841e213864046111E43d237703d71FaBe91Ef9e0;

    address public constant COWSWAP_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address public constant COWSWAP_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address public constant KYBERSWAP_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;

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
            proxyAdmin: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
            deployer: 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3,
            factoryImplementation: Factory(0x0000000397b71C8f3182Fd40D247330D218fdC72),
            factory: Factory(0x0000000f9686896836C39cf721141922Ce42639f),
            consensusFactory: Factory(0xaEEB06CBd91A18b51a2D30b61477eAeE3a9633C3),
            depositQueueFactory: Factory(0xBB92A7B9695750e1234BaB18F83b73686dd09854),
            redeemQueueFactory: Factory(0xfe76b5fd238553D65Ce6dd0A572C0fda629F8421),
            feeManagerFactory: Factory(0xF7223356819Ea48f25880b6c2ab3e907CC336D45),
            oracleFactory: Factory(0x0CdFf250C7a071fdc72340D820C5C8e29507Aaad),
            riskManagerFactory: Factory(0xa51E4FA916b939Fa451520D2B7600c740d86E5A0),
            shareManagerFactory: Factory(0x952f39AA62E94db3Ad0d1C7D1E43C1a8519E45D8),
            subvaultFactory: Factory(0x75FE0d73d3C64cdC1C6449D9F977Be6857c4d011),
            vaultFactory: Factory(0x4E38F679e46B3216f0bd4B314E9C429AFfB1dEE3),
            verifierFactory: Factory(0x04B30b1e98950e6A13550d84e991bE0d734C2c61),
            erc20VerifierFactory: Factory(0x77A83AcBf7A6df20f1D681b4810437d74AE790F8),
            swapModuleFactory: Factory(0x8471a3BC64f14c5272368FDD8FdD197EeD964FEf),
            symbioticVerifierFactory: Factory(address(0)),
            eigenLayerVerifierFactory: Factory(address(0)),
            consensusImplementation: Consensus(0x0000000167598d2C78E2313fD5328E16bD9A0b13),
            depositQueueImplementation: DepositQueue(payable(0x00000006dA9f179BFE250Dd1c51cD2d3581930c8)),
            syncDepositQueueImplementation: SyncDepositQueue(payable(0)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x00000003887dfBCEbD1e4097Ad89B690de7eFbf9)),
            redeemQueueImplementation: RedeemQueue(payable(0x0000000285805eac535DADdb9648F1E10DfdC411)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0x0000000b2082667589A16c4cF18e9f923781c471)),
            feeManagerImplementation: FeeManager(0x0000000dE74e5D51651326E0A3e1ACA94bEAF6E1),
            oracleImplementation: Oracle(0x0000000F0d3D1c31b72368366A4049C05E291D58),
            riskManagerImplementation: RiskManager(0x0000000714cf2851baC1AE2f41871862e9D216fD),
            tokenizedShareManagerImplementation: TokenizedShareManager(0x0000000E8eb7173fA1a3ba60eCA325bcB6aaf378),
            burnableTokenizedShareManagerImplementation: BurnableTokenizedShareManager(address(0)),
            basicShareManagerImplementation: BasicShareManager(0x00000005564AAE40D88e2F08dA71CBe156767977),
            subvaultImplementation: Subvault(payable(0x0000000E535B4E063f8372933A55470e67910a66)),
            verifierImplementation: Verifier(0x000000047Fc878662006E78D5174FB4285637966),
            vaultImplementation: Vault(payable(0x0000000615B2771511dAa693aC07BE5622869E01)),
            bitmaskVerifier: BitmaskVerifier(0x0000000263Fb29C3D6B0C5837883519eF05ea20A),
            eigenLayerVerifierImplementation: EigenLayerVerifier(address(0)),
            erc20VerifierImplementation: ERC20Verifier(0x00000009207D366cBB8549837F8Ae4bf800Af2D6),
            symbioticVerifierImplementation: SymbioticVerifier(address(0)),
            vaultConfigurator: VaultConfigurator(0x000000028be48f9E62E13403480B60C4822C5aa5),
            basicRedeemHook: BasicRedeemHook(0x0000000637f1b1ccDA4Af2dB6CDDf5e5Ec45fd93),
            redirectingDepositHook: RedirectingDepositHook(0x00000004d3B17e5391eb571dDb8fDF95646ca827),
            lidoDepositHook: LidoDepositHook(address(0)),
            oracleHelper: OracleHelper(0x000000005F543c38d5ea6D0bF10A50974Eb55E35),
            swapModuleImplementation: SwapModule(payable(0x00000000fF13abe88Ff02DC80d53D1d3B89b2E0F))
        });
    }
}
