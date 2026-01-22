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

    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant WSTETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address public constant WSTETH_ETHEREUM = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public constant MUSD = 0xdD468A1DDc392dcdbEf6db6e34E89AA338F9F186;
    address public constant CRV = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978;
    address public constant FLUID = 0x61E030A56D33e8260FdD81f03B162A79Fe3449Cd;

    address public constant CCTP_ARBITRUM_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d; // Arbitrum TokenMessenger М2 deposit for burn
    address public constant CCTP_ARBITRUM_MESSAGE_TRANSMITTER = 0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca; // Arbitrum MessageTransmitter receive message
    // https://developers.circle.com/cctp/concepts/supported-chains-and-domains
    uint32 public constant CCTP_ETHEREUM_DOMAIN = 0; // Ethereum EID

    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    uint32 public constant LAYER_ZERO_ETHEREUM_EID = 30101;

    address public constant STRETH_ETHEREUM_SUBVAULT_0 = 0x90c983DC732e65DB6177638f0125914787b8Cb78;
    address public constant L2_GATEWAY_ROUTER = 0x5288c571Fd7aD117beA99bF60FE0846C4E84F933;

    address public constant COWSWAP_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address public constant COWSWAP_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address public constant KYBERSWAP_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;

    address public constant AAVE_CORE = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant AAVE_V3_ORACLE = 0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7;

    address public constant CURVE_USDC_USDT_POOL = 0x49b720F1Aab26260BEAec93A7BeB5BF2925b2A8F;
    address public constant CURVE_USDC_USDT_GAUGE = 0x2F8bcdF1824B91D420F8951A972eE988Ebd8544d;
    address public constant CURVE_USDC_USDT_REWARD_MINTER = 0xabC000d88f23Bb45525E447528DBF656A9D55bf5;

    address public constant USDT_OFT_ADAPTER = 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92;
    address public constant FLUID_USDT_FTOKEN = 0x4A03F37e7d3fC243e3f99341d36f4b829BEe5E03;
    address public constant FLUID_USDC_FTOKEN = 0x1A996cb54bb95462040408C06122D45D6Cdb6096;

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
            symbioticVerifierFactory: Factory(address(0)),
            eigenLayerVerifierFactory: Factory(address(0)),
            swapModuleFactory: Factory(0x1B6C06E8ff3E2DD310E20a70a6a2Be048Fa26Dbd),
            consensusImplementation: Consensus(0x0000000167598d2C78E2313fD5328E16bD9A0b13),
            depositQueueImplementation: DepositQueue(payable(0x00000006dA9f179BFE250Dd1c51cD2d3581930c8)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x00000003887dfBCEbD1e4097Ad89B690de7eFbf9)),
            redeemQueueImplementation: RedeemQueue(payable(0x0000000285805eac535DADdb9648F1E10DfdC411)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0x0000000b2082667589A16c4cF18e9f923781c471)),
            feeManagerImplementation: FeeManager(0x0000000dE74e5D51651326E0A3e1ACA94bEAF6E1),
            oracleImplementation: Oracle(0x0000000F0d3D1c31b72368366A4049C05E291D58),
            riskManagerImplementation: RiskManager(0x0000000714cf2851baC1AE2f41871862e9D216fD),
            tokenizedShareManagerImplementation: TokenizedShareManager(0x0000000E8eb7173fA1a3ba60eCA325bcB6aaf378),
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
            swapModuleImplementation: SwapModule(payable(0x0000000bb667353D37478ceEd142f4cEf51b9c9F))
        });
    }
}
