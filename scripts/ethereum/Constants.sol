// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";
import "../common/interfaces/Imports.sol";

import "./strETHLibrary.sol";
import "./tqETHLibrary.sol";

library Constants {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address public constant USDU = 0xdde3eC717f220Fc6A29D6a4Be73F91DA5b718e55;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address public constant FLUID = 0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb;

    address public constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address public constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

    address public constant MUSD = 0xdD468A1DDc392dcdbEf6db6e34E89AA338F9F186;
    address public constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf; // 8 decimals
    address public constant TBTC = 0x18084fbA666a33d37592fA2633fD49a74DD93a88; // 18 decimals
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // 8 decimals

    address public constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address public constant RSETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;

    address public constant USR = 0x66a1E37c9b0eAddca17d3662D6c05F4DECf3e110;
    address public constant STUSR = 0x6c8984bc7DBBeDAf4F6b2FD766f16eBB7d10AAb4;
    address public constant WSTUSR = 0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055;
    address public constant USR_REQUEST_MANAGER = 0xAC85eF29192487E0a109b7f9E40C267a9ea95f2e;

    address public constant COWSWAP_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address public constant COWSWAP_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address public constant KYBERSWAP_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;

    address public constant AAVE_CORE = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant AAVE_PRIME = 0x4e033931ad43597d96D6bcc25c280717730B58B1;

    address public constant SPARK = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;

    address public constant AAVE_V3_ORACLE = 0x54586bE62E3c3580375aE3723C145253060Ca0C2;

    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 public constant MORPHO_WSTUSR_USDC_MARKET_ID =
        0xd9e34b1eed46d123ac1b69b224de1881dbc88798bc7b70f504920f62f58f28cc;

    address public constant EIGEN_LAYER_DELEGATION_MANAGER = 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A;
    address public constant EIGEN_LAYER_STRATEGY_MANAGER = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
    address public constant EIGEN_LAYER_REWARDS_COORDINATOR = 0x7750d328b314EfFa365A0402CcfD489B80B0adda;

    address public constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;
    address public constant SYMBIOTIC_FARM_FACTORY = 0xFEB871581C2ab2e1EEe6f7dDC7e6246cFa087A23;

    address public constant FE_ORACLE = 0x5250Ae8A29A19DF1A591cB1295ea9bF2B0232453;

    address public constant STRETH_ARBITRUM_SUBVAULT_0 = 0x222fa99C485a088564eb43fAA50Bc10b2497CDB2;
    address public constant ARBITRUM_L1_GATEWAY_ROUTER = 0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef;
    address public constant ARBITRUM_L1_TOKEN_GATEWAY_WSTETH = 0x0F25c1DC2a9922304f2eac71DCa9B07E310e8E5a;

    address public constant STRETH_PLASMA_SUBVAULT_0 = 0xbbF9400C09B0F649F3156989F1CCb9c016f943bb;

    address public constant CCIP_PLASMA_ROUTER = 0xcDca5D374e46A6DDDab50bD2D9acB8c796eC35C3;
    uint64 public constant CCIP_PLASMA_CHAIN_SELECTOR = 9335212494177455608;
    address public constant CCIP_ETHEREUM_ROUTER = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    uint64 public constant CCIP_ETHEREUM_CHAIN_SELECTOR = 5009297550715157269;

    address public constant CCTP_ETHEREUM_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d; // Ethereum TokenMessenger V2 deposit for burn
    address public constant CCTP_ETHEREUM_MESSAGE_TRANSMITTER = 0x0a992d191DEeC32aFe36203Ad87D7d289a738F81; // Ethereum MessageTransmitter receive message
    // https://developers.circle.com/cctp/concepts/supported-chains-and-domains
    uint32 public constant CCTP_ARBITRUM_DOMAIN = 3; // Arbitrum EID

    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    uint32 public constant LAYER_ZERO_PLASMA_EID = 30383;
    uint32 public constant LAYER_ZERO_ARBITRUM_EID = 30110;

    address public constant ETHEREUM_USDT_OFT_ADAPTER = 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee;
    address public constant PLASMA_USDT_OFT_ADAPTER = 0x02ca37966753bDdDf11216B73B16C1dE756A7CF9;
    address public constant ARBITRUM_USDT_OFT_ADAPTER = 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92;

    address public constant ETHEREUM_WSTUSR_OFT_ADAPTER = 0xab17c1fE647c37ceb9b96d1c27DD189bf8451978;
    address public constant PLASMA_WSTUSR_OFT_ADAPTER = 0x2a52B289bA68bBd02676640aA9F605700c9e5699;

    address public constant ETHEREUM_FLUID_USDC_FTOKEN = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
    address public constant ETHEREUM_FLUID_USDT_FTOKEN = 0x5C20B550819128074FD538Edf79791733ccEdd18;

    address public constant STRETH = 0x277C6A642564A91ff78b008022D65683cEE5CCC5;
    address public constant STRETH_DEPOSIT_QUEUE_ETH = 0xE707321B887b9da133AC5fCc5eDB78Ab177a152D;
    address public constant STRETH_DEPOSIT_QUEUE_WETH = 0x2eA268f1018a4767bF5da42D531Ea9e943942A36;
    address public constant STRETH_DEPOSIT_QUEUE_WSTETH = 0x614cb9E9D13712781DfD15aDC9F3DAde60E4eFAb;
    address public constant STRETH_REDEEM_QUEUE_WSTETH = 0x1ae8C006b5C97707aa074AaeD42BecAD2CF80Da2;
    address public constant STRETH_SHARE_MANAGER = 0xcd3c0F51798D1daA92Fb192E57844Ae6cEE8a6c7;

    address public constant GGV = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
    address public constant DVV = 0x5E362eb2c0706Bd1d134689eC75176018385430B;

    address public constant TQETH = 0xDbC81B33A23375A90c8Ba4039d5738CB6f56fE8d;

    address public constant CURVE_USDC_USDU_POOL = 0x771c91e699B4B23420de3F81dE2aA38C4041632b;
    address public constant CURVE_USDC_USDU_GAUGE = 0x0E2662672adC42Bb73d39196f9f557C11B4FCcf9;

    address public constant CURVE_USDC_USDT_POOL = 0x4f493B7dE8aAC7d55F71853688b1F7C8F0243C85;
    address public constant CURVE_USDC_USDT_GAUGE = 0x479dFB03cdDEa20dC4e8788B81Fd7C7A08FD3555;
    address public constant CURVE_USDC_USDT_REWARD_MINTER = 0xd061D61a4d941c39E5453435B6345Dc261C2fcE0;

    address public constant CURVE_TBTC_CBBTC_POOL = 0xAE6Ee608b297305AbF3EB609B81FEBbb8F6A0bb3;

    address public constant MORPHO_USDC_ALPHAPING = 0xb0f05E4De970A1aaf77f8C2F823953a367504BA9;
    address public constant MORPHO_WETH_ALPHAPING = 0x47fe8Ab9eE47DD65c24df52324181790b9F47EfC;

    address public constant BRACKET_FINANCE_WETH_VAULT = 0x3588e6Cb5DCa99E35bA2E2a5D42cdDb46365e71B;
    address public constant BRACKET_FINANCE_USDC_VAULT = 0xb8ca40E2c5d77F0Bc1Aa88B2689dddB279F7a5eb;

    address public constant RSTETH = 0x7a4EffD87C2f3C55CA251080b1343b605f327E3a;
    address public constant CAP_LENDER = 0x15622c3dbbc5614E6DFa9446603c1779647f01FC;
    address public constant CAP_NETWORK = 0x98e52Ea7578F2088c152E81b17A9a459bF089f2a;
    address public constant CAP_FACTORY = 0x0B92300C8494833E504Ad7d36a301eA80DbBAE2e;

    address public constant USDT_CHAINLINK_ORACLE = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
    address public constant USDC_CHAINLINK_ORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant USR_CHAINLINK_ORACLE = 0x34ad75691e25A8E9b681AAA85dbeB7ef6561B42c;

    address public constant UNISWAP_V3_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public constant UNISWAP_V4_POSITION_MANAGER = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;

    address public constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    // https://app.uniswap.org/explore/pools/ethereum/
    address public constant UNISWAP_V3_POOL_TBTC_WBTC_100 = 0x73A38006d23517a1d383C88929B2014F8835B38B;
    address public constant UNISWAP_V3_POOL_WBTC_CBBTC_100 = 0xe8f7c89C5eFa061e340f2d2F206EC78FD8f7e124;
    // 0x5459f9d1f649b9f1353a50fd0c8d796b4feb11926bec295cb0614a135febdf9a
    bytes25 public constant UNISWAP_V4_POOL_TBTC_CBBTC_100 = 0x5459f9d1f649b9f1353a50fd0c8d796b4feb11926bec295cb0;
    // 0x2f92b371aef58f0abe9c10c06423de083405991f2839638914a1031e91d9a723
    bytes25 public constant UNISWAP_V4_POOL_WBTC_CBBTC_100 = 0x2f92b371aef58f0abe9c10c06423de083405991f2839638914;

    address public constant ANGLE_PROTOCOL_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    address public constant YIELD_BASIS_ZAP = 0xE862bC39B8D5F12D8c4117d3e2D493Dc20051EC6;
    address public constant YIELD_BASIS_TBTC_TOKEN = 0xaC0a340C1644321D0BBc6404946d828c1EBfAC92;
    address public constant YIELD_BASIS_WBTC_TOKEN = 0xfBF3C16676055776Ab9B286492D8f13e30e2E763;
    address public constant YIELD_BASIS_CBBTC_TOKEN = 0xAC0cfa7742069a8af0c63e14FFD0fe6b3e1Bf8D2;

    function protocolDeployment() internal pure returns (ProtocolDeployment memory) {
        return ProtocolDeployment({
            deploymentName: DEPLOYMENT_NAME,
            deploymentVersion: DEPLOYMENT_VERSION,
            eigenLayerDelegationManager: EIGEN_LAYER_DELEGATION_MANAGER,
            eigenLayerStrategyManager: EIGEN_LAYER_STRATEGY_MANAGER,
            eigenLayerRewardsCoordinator: EIGEN_LAYER_REWARDS_COORDINATOR,
            symbioticVaultFactory: SYMBIOTIC_VAULT_FACTORY,
            symbioticFarmFactory: SYMBIOTIC_FARM_FACTORY,
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
            erc20VerifierFactory: Factory(0x2e234F4E1b7934d5F4bEAE3fF2FDC109f5C42F1d),
            symbioticVerifierFactory: Factory(0x41C443F10a92D597e6c9E271140BC94c10f5159F),
            eigenLayerVerifierFactory: Factory(0x77A83AcBf7A6df20f1D681b4810437d74AE790F8),
            swapModuleFactory: Factory(0xE3575055a24d8642DFA3a51ec766Ef2db2671659),
            consensusImplementation: Consensus(0x0000000167598d2C78E2313fD5328E16bD9A0b13),
            depositQueueImplementation: DepositQueue(payable(0x00000006dA9f179BFE250Dd1c51cD2d3581930c8)),
            syncDepositQueueImplementation: SyncDepositQueue(payable(0x000000002E2aeaC5Fe65AaB6fE2E6AE0e44F1A3A)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x00000003887dfBCEbD1e4097Ad89B690de7eFbf9)),
            redeemQueueImplementation: RedeemQueue(payable(0x000000000c139266BA06170Ed1DeacA6d11903c1)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0x0000000b2082667589A16c4cF18e9f923781c471)),
            feeManagerImplementation: FeeManager(0x0000000dE74e5D51651326E0A3e1ACA94bEAF6E1),
            oracleImplementation: Oracle(0x0000000F0d3D1c31b72368366A4049C05E291D58),
            riskManagerImplementation: RiskManager(0x0000000714cf2851baC1AE2f41871862e9D216fD),
            tokenizedShareManagerImplementation: TokenizedShareManager(0x0000000E8eb7173fA1a3ba60eCA325bcB6aaf378),
            burnableTokenizedShareManagerImplementation: BurnableTokenizedShareManager(
                0x000000000c79D2B5cD58AE545afc83030233D7B6
            ),
            basicShareManagerImplementation: BasicShareManager(0x00000005564AAE40D88e2F08dA71CBe156767977),
            subvaultImplementation: Subvault(payable(0x0000000E535B4E063f8372933A55470e67910a66)),
            verifierImplementation: Verifier(0x000000047Fc878662006E78D5174FB4285637966),
            vaultImplementation: Vault(payable(0x0000000615B2771511dAa693aC07BE5622869E01)),
            bitmaskVerifier: BitmaskVerifier(0x0000000263Fb29C3D6B0C5837883519eF05ea20A),
            eigenLayerVerifierImplementation: EigenLayerVerifier(0x00000003F82051A8B2F020B79e94C3DC94E89B81),
            erc20VerifierImplementation: ERC20Verifier(0x00000009207D366cBB8549837F8Ae4bf800Af2D6),
            symbioticVerifierImplementation: SymbioticVerifier(0x00000000cBC6f5d4348496FfA22Cf014b9DA394B),
            vaultConfigurator: VaultConfigurator(0x000000028be48f9E62E13403480B60C4822C5aa5),
            basicRedeemHook: BasicRedeemHook(0x0000000637f1b1ccDA4Af2dB6CDDf5e5Ec45fd93),
            redirectingDepositHook: RedirectingDepositHook(0x00000004d3B17e5391eb571dDb8fDF95646ca827),
            lidoDepositHook: LidoDepositHook(0x000000065d1A7bD71f52886910aaBE6555b7317c),
            oracleHelper: OracleHelper(0x000000005F543c38d5ea6D0bF10A50974Eb55E35),
            swapModuleImplementation: SwapModule(payable(0x00000000d681E85e5783588f87A9573Cb97Eda01))
        });
    }

    DeployVaultFactory public constant deployVaultFactory =
        DeployVaultFactory(0xdE0000006a45bfD6a310C51c42bBE256847bB6d5);

    function getTqETHPreProdDeployment() internal pure returns (VaultDeployment memory $) {
        address proxyAdmin = 0xC1211878475Cd017fecb922Ae63cc3815FA45652;
        address lazyVaultAdmin = 0xE8bEc6Fb52f01e487415D3Ed3797ab92cBfdF498;
        address activeVaultAdmin = 0x7885B30F0DC0d8e1aAf0Ed6580caC22d5D09ff4f;
        address oracleUpdater = 0x3F1C3Eb0bC499c1A091B635dEE73fF55E19cdCE9;
        address curator = 0x55666095cD083a92E368c0CBAA18d8a10D3b65Ec;
        address pauser1 = 0xFeCeb0255a4B7Cd05995A7d617c0D52c994099CF;
        address pauser2 = 0x8b7C1b52e2d606a526abD73f326c943c75e45Bd3;

        address timelockController = 0xFA4B93A6A482dE973cAcFd89e8CB7a425016Fb89;
        ProtocolDeployment memory pd = protocolDeployment();
        address deployer = pd.deployer;

        address[] memory assets_ = new address[](3);
        assets_[0] = Constants.ETH;
        assets_[1] = Constants.WETH;
        assets_[2] = Constants.WSTETH;

        {
            Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);

            uint256 i = 0;
            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, activeVaultAdmin);
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
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, deployer);
            assembly {
                mstore(holders, i)
            }

            $.initParams = VaultConfigurator.InitParams({
                version: 0,
                proxyAdmin: proxyAdmin,
                vaultAdmin: lazyVaultAdmin,
                shareManagerVersion: 0,
                shareManagerParams: abi.encode(bytes32(0), "Theoriq AlphaVault ETH", "tqETH"),
                feeManagerVersion: 0,
                feeManagerParams: abi.encode(deployer, lazyVaultAdmin, uint24(0), uint24(0), uint24(1e5), uint24(1e4)),
                riskManagerVersion: 0,
                riskManagerParams: abi.encode(type(int256).max),
                oracleVersion: 0,
                oracleParams: abi.encode(
                    IOracle.SecurityParams({
                        maxAbsoluteDeviation: 0.005 ether,
                        suspiciousAbsoluteDeviation: 0.001 ether,
                        maxRelativeDeviationD18: 0.005 ether,
                        suspiciousRelativeDeviationD18: 0.001 ether,
                        timeout: 1 hours,
                        depositInterval: 1 hours,
                        redeemInterval: 2 days
                    }),
                    assets_
                ),
                defaultDepositHook: address(pd.redirectingDepositHook),
                defaultRedeemHook: address(pd.basicRedeemHook),
                queueLimit: 6,
                roleHolders: holders
            });
        }

        $.vault = Vault(payable(0xf328463fb20d9265C612155F4d023f8cD79916C7));

        {
            Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](50);
            uint256 i = 0;

            // lazyVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, activeVaultAdmin);
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

            assembly {
                mstore(holders, i)
            }
            $.holders = holders;
        }

        $.depositHook = address(pd.redirectingDepositHook);
        $.redeemHook = address(pd.basicRedeemHook);
        $.assets = assets_;
        $.depositQueueAssets = assets_;
        $.redeemQueueAssets = assets_;
        $.subvaultVerifiers = new address[](1);
        $.subvaultVerifiers[0] = 0x972C2c6b0f11dC748635b00dAD36Bf0BdE08Aa82;
        $.timelockControllers = new address[](1);
        $.timelockControllers[0] = timelockController;

        $.timelockProposers = new address[](2);
        $.timelockProposers[0] = lazyVaultAdmin;
        $.timelockProposers[1] = deployer;

        $.timelockExecutors = new address[](2);
        $.timelockExecutors[0] = pauser1;
        $.timelockExecutors[1] = pauser2;
        $.calls = new SubvaultCalls[](1);
        // (, IVerifier.VerificationPayload[] memory leaves) = tqETHLibrary.getSubvault0Proofs(curator);
        // $.calls[0] = tqETHLibrary.getSubvault0SubvaultCalls(curator, leaves);
    }

    function getStrETHDeployment() internal pure returns (VaultDeployment memory $) {
        address proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
        address lazyVaultAdmin = 0xAbE20D266Ae54b9Ae30492dEa6B6407bF18fEeb5;
        address activeVaultAdmin = 0xeb1CaFBcC8923eCbc243ff251C385C201A6c734a;
        address oracleUpdater = 0xd27fFB15Dd00D5E52aC2BFE6d5AFD36caE850081;
        address curator = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;
        address lidoPauser = 0xA916fD5252160A7E56A6405741De76dc0Da5A0Cd;
        address mellowPauser = 0xa6278B726d4AA09D14f9E820D7785FAd82E7196F;
        address treasury = 0xb1E5a8F26C43d019f2883378548a350ecdD1423B;
        address timelockController = 0x8D8b65727729Fb484CB6dc1452D61608a5758596;

        ProtocolDeployment memory pd = protocolDeployment();
        address deployer = pd.deployer;

        address[] memory assets_ = new address[](6);
        assets_[0] = Constants.ETH;
        assets_[1] = Constants.WETH;
        assets_[2] = Constants.WSTETH;
        assets_[3] = Constants.USDC;
        assets_[4] = Constants.USDT;
        assets_[5] = Constants.USDS;

        {
            Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);

            uint256 i = 0;

            // lazyAdmin
            holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, activeVaultAdmin);
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
            assembly {
                mstore(holders, i)
            }

            $.initParams = VaultConfigurator.InitParams({
                version: 0,
                proxyAdmin: proxyAdmin,
                vaultAdmin: lazyVaultAdmin,
                shareManagerVersion: 0,
                shareManagerParams: abi.encode(bytes32(0), "Mellow stRATEGY", "strETH"),
                feeManagerVersion: 0,
                feeManagerParams: abi.encode(deployer, treasury, uint24(0), uint24(0), uint24(1e5), uint24(1e4)),
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
                        redeemInterval: 2 days
                    }),
                    assets_
                ),
                defaultDepositHook: address(pd.redirectingDepositHook),
                defaultRedeemHook: address(pd.basicRedeemHook),
                queueLimit: 4,
                roleHolders: holders
            });

            $.holders = holders;
        }

        $.vault = Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5));

        $.depositHook = address(pd.redirectingDepositHook);
        $.redeemHook = address(pd.basicRedeemHook);
        $.assets = assets_;
        $.depositQueueAssets =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH));
        $.redeemQueueAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH));
        $.subvaultVerifiers = ArraysLibrary.makeAddressArray(
            abi.encode(
                0xF4eA276361348b301Ba2296dB909a7c973A15451,
                0x02e1C91C4D82af454D892FBE2c5De2c4504b2675,
                0x1616d39a201D246cbD1B3B145234638f7719b53A,
                0xd662dF7C0FAF0Fe6446638651b05C287806AD1AE
            )
        );
        $.timelockControllers = ArraysLibrary.makeAddressArray(abi.encode(address(timelockController)));
        $.timelockProposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
        $.timelockExecutors = ArraysLibrary.makeAddressArray(abi.encode(lidoPauser, mellowPauser));

        // address[] memory subvaults = ArraysLibrary.makeAddressArray(
        //     abi.encode(
        //         0x90c983DC732e65DB6177638f0125914787b8Cb78,
        //         0x893aa69FBAA1ee81B536f0FbE3A3453e86290080,
        //         0x181cB55f872450D16aE858D532B4e35e50eaA76D,
        //         0x9938A09FeA37bA681A1Bd53D33ddDE2dEBEc1dA0
        //     )
        // );

        $.calls = new SubvaultCalls[](4);
        // {
        //     (, IVerifier.VerificationPayload[] memory leaves) = strETHLibrary.getSubvault0Proofs(curator, subvaults[0], swapModules[0]);
        //     $.calls[0] = strETHLibrary.getSubvault0SubvaultCalls(curator, leaves);
        // }
        // {
        //     (, IVerifier.VerificationPayload[] memory leaves) = strETHLibrary.getSubvault1Proofs(curator, subvaults[1], address(0));
        //     $.calls[1] = strETHLibrary.getSubvault1SubvaultCalls(curator, subvaults[1], leaves);
        // }
        // {
        //     (, IVerifier.VerificationPayload[] memory leaves) = strETHLibrary.getSubvault2Proofs(curator, subvaults[2], swapModules[3]);
        //     $.calls[2] = strETHLibrary.getSubvault2SubvaultCalls(curator, subvaults[2], leaves);
        // }
        // {
        //     (, IVerifier.VerificationPayload[] memory leaves) = strETHLibrary.getSubvault3Proofs(curator, subvaults[3], swapModules[4]);
        //     $.calls[3] = strETHLibrary.getSubvault3SubvaultCalls(curator, subvaults[3], leaves);
        // }
    }
}
