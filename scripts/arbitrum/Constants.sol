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

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant WSTETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address public constant WSTETH_ETHEREUM = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public constant MUSD = 0xdD468A1DDc392dcdbEf6db6e34E89AA338F9F186;
    address public constant CRV = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978;
    address public constant FLUID = 0x61E030A56D33e8260FdD81f03B162A79Fe3449Cd;

    address public constant USDAI = 0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF;
    address public constant SUSDAI = 0x0B2b2B2076d95dda7817e785989fE353fe955ef9;

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

    function protocolDeployment() internal pure returns (ProtocolDeployment memory $) {
        $.deploymentName = "Mellow";
        $.deploymentVersion = 1;
        $.cowswapSettlement = COWSWAP_SETTLEMENT;
        $.cowswapVaultRelayer = COWSWAP_VAULT_RELAYER;
        $.weth = WETH;
        $.proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
        $.deployer = 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3;

        $.factoryImplementation = Factory(0x0000000072BAfCeAff1AD0237Ea58f06cfc4467F);
        $.factory = Factory(0x00000000741292C88f9fF5050b07051C4f592EBf);
        $.consensusFactory = Factory(0xAfef40968b5304135677f0C89203948e1A145105);
        $.depositQueueFactory = Factory(0xF429ba2a8437E7de85078CF7481E8Ad52df7E58c);
        $.redeemQueueFactory = Factory(0xe08dc488bD6756323F8bf478869529D03db627ef);
        $.oracleFactory = Factory(0x727c295b5D99b15280Ca8736b6F97ABA6aEd0E88);
        $.feeManagerFactory = Factory(0x52d56c20B0C8d403888880d0A1610e5ed17addA8);
        $.riskManagerFactory = Factory(0x9885215ef8DB25C87466E73018061e532784D716);
        $.shareManagerFactory = Factory(0xDA2a7aE07B6803feF9d95E47Ab83c8a5A09929F0);
        $.subvaultFactory = Factory(0xA64e324DFF04e3C0613ff0706867868C7b370a45);
        $.vaultFactory = Factory(0xBBCD2aC50aF2EA12Cc9cb7B16dBDa85859BeB3da);
        $.verifierFactory = Factory(0x9fBAF5AEB9F52bA57E1cC1D3050eac6d75Df8ae7);
        $.erc20VerifierFactory = Factory(0x711F6236e325634AA8c1F692b5312bfF3A8558D0);

        $.accountFactory = Factory(0x870DB41df0905cc5a790f6582a3dA99A4A33F923);
        $.swapModuleFactory = Factory(0xC5a52E4bB718Dfe86938e5cB967362EdA1E62698);
        $.consensusImplementation = Consensus(0x000000007e6b679B9196a1609e5Bc2405eDFd6Aa);
        $.depositQueueImplementation = DepositQueue(payable(0x00000000B2d2373aAF1C370cFE4e1Ee8BDE7C546));
        $.signatureDepositQueueImplementation =
            SignatureDepositQueue(payable(0x000000000Af33501e5BDAF9B481Ad2712a024727));
        $.syncDepositQueueImplementation = SyncDepositQueue(payable(0x000000001CC8c3E40856E956db870095EF6C98bd));
        $.feeManagerImplementation = FeeManager(0x00000000C18039E1F415fe07C33A316232238648);
        $.oracleImplementation = Oracle(0x000000009adE4dAE1f868775A3f087945983f062);
        $.redeemQueueImplementation = RedeemQueue(payable(0x0000000045d70ee8145135f08309fF5B1A63d43F));
        $.signatureRedeemQueueImplementation = SignatureRedeemQueue(payable(0x000000008D14Ef3658805765107d9F12776f4138));
        $.riskManagerImplementation = RiskManager(0x00000000CC26BC741E75B181738Ac2B16156179b);
        $.tokenizedShareManagerImplementation = TokenizedShareManager(0x00000000861e8B90B81f35C18cA14858Cc91d1Df);
        $.basicShareManagerImplementation = BasicShareManager(0x00000000e5F0cddA56447b2a29e2847A52c8725D);
        $.burnableTokenizedShareManagerImplementation =
            BurnableTokenizedShareManager(0x00000000C534B8680e3aa7165DeDc3Ab8781f602);
        $.subvaultImplementation = Subvault(payable(0x00000000CA30010B8417f791250AE221FdaD5920));
        $.verifierImplementation = Verifier(0x000000007e86a96e279662108cc19bA4c32EdE3C);
        $.erc20VerifierImplementation = ERC20Verifier(0x00000000ACD80376E999Af8c424e5e33BD224A08);
        $.mellowAccountV1Implementation = MellowAccountV1(0x00000000860913f37fab81ce8ce4E5BD1f664482);
        $.swapModuleImplementation = SwapModule(payable(0x00000000c324E2d11EcCB03A061F69B5FE123645));
        $.vaultImplementation = Vault(payable(0x0000000070f44289ec5ea3E5972f058f75B29801));
        $.bitmaskVerifier = BitmaskVerifier(0x0000000009E9368ad21fc19DCE1cFcf9Af6dE339);
        $.vaultConfigurator = VaultConfigurator(0x0000000005a67199ABE0f9C995EAB9DaDfA31Ccd);
        $.basicRedeemHook = BasicRedeemHook(0x00000000176dD23550c3845746b2036E90DC5912);
        $.redirectingDepositHook = RedirectingDepositHook(0x0000000024ABbd08686Abb2987831dEa88eF1180);
        $.oracleHelper = OracleHelper(0x000000007d2552AD746Af5c13f91B5e72f97c2B7);
    }
}
