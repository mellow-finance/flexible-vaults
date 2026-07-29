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

    address public constant deployer = 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3;
    address public constant proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;

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
            wsteth: WSTETH,
            weth: WETH,
            proxyAdmin: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
            deployer: 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3,
            factoryImplementation: Factory(0x0000000072BAfCeAff1AD0237Ea58f06cfc4467F),
            factory: Factory(0x00000000741292C88f9fF5050b07051C4f592EBf),
            consensusFactory: Factory(0xAfef40968b5304135677f0C89203948e1A145105),
            depositQueueFactory: Factory(0xF429ba2a8437E7de85078CF7481E8Ad52df7E58c),
            redeemQueueFactory: Factory(0xe08dc488bD6756323F8bf478869529D03db627ef),
            feeManagerFactory: Factory(0x52d56c20B0C8d403888880d0A1610e5ed17addA8),
            oracleFactory: Factory(0x727c295b5D99b15280Ca8736b6F97ABA6aEd0E88),
            riskManagerFactory: Factory(0x9885215ef8DB25C87466E73018061e532784D716),
            shareManagerFactory: Factory(0xDA2a7aE07B6803feF9d95E47Ab83c8a5A09929F0),
            subvaultFactory: Factory(0xA64e324DFF04e3C0613ff0706867868C7b370a45),
            vaultFactory: Factory(0xBBCD2aC50aF2EA12Cc9cb7B16dBDa85859BeB3da),
            verifierFactory: Factory(0x9fBAF5AEB9F52bA57E1cC1D3050eac6d75Df8ae7),
            erc20VerifierFactory: Factory(0x711F6236e325634AA8c1F692b5312bfF3A8558D0),
            symbioticVerifierFactory: Factory(address(0)),
            eigenLayerVerifierFactory: Factory(address(0)),
            swapModuleFactory: Factory(0xC5a52E4bB718Dfe86938e5cB967362EdA1E62698),
            accountFactory: Factory(0x870DB41df0905cc5a790f6582a3dA99A4A33F923),
            consensusImplementation: Consensus(0x000000007e6b679B9196a1609e5Bc2405eDFd6Aa),
            depositQueueImplementation: DepositQueue(payable(0x00000000B2d2373aAF1C370cFE4e1Ee8BDE7C546)),
            syncDepositQueueImplementation: SyncDepositQueue(payable(0x000000001CC8c3E40856E956db870095EF6C98bd)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x000000000Af33501e5BDAF9B481Ad2712a024727)),
            redeemQueueImplementation: RedeemQueue(payable(0x0000000045d70ee8145135f08309fF5B1A63d43F)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0x000000008D14Ef3658805765107d9F12776f4138)),
            syncRedeemQueueImplementation: SyncRedeemQueue(payable(0x0000000091823b6654c7D724BCaca603Ff34bCd6)),
            feeManagerImplementation: FeeManager(0x00000000C18039E1F415fe07C33A316232238648),
            oracleImplementation: Oracle(0x000000009adE4dAE1f868775A3f087945983f062),
            riskManagerImplementation: RiskManager(0x00000000CC26BC741E75B181738Ac2B16156179b),
            tokenizedShareManagerImplementation: TokenizedShareManager(0x00000000861e8B90B81f35C18cA14858Cc91d1Df),
            burnableTokenizedShareManagerImplementation: BurnableTokenizedShareManager(
                0x00000000C534B8680e3aa7165DeDc3Ab8781f602
            ),
            basicShareManagerImplementation: BasicShareManager(0x00000000e5F0cddA56447b2a29e2847A52c8725D),
            subvaultImplementation: Subvault(payable(0x00000000CA30010B8417f791250AE221FdaD5920)),
            verifierImplementation: Verifier(0x000000007e86a96e279662108cc19bA4c32EdE3C),
            vaultImplementation: Vault(payable(0x0000000070f44289ec5ea3E5972f058f75B29801)),
            bitmaskVerifier: BitmaskVerifier(0x0000000009E9368ad21fc19DCE1cFcf9Af6dE339),
            eigenLayerVerifierImplementation: EigenLayerVerifier(address(0)),
            erc20VerifierImplementation: ERC20Verifier(0x00000000ACD80376E999Af8c424e5e33BD224A08),
            symbioticVerifierImplementation: SymbioticVerifier(address(0)),
            vaultConfigurator: VaultConfigurator(0x0000000005a67199ABE0f9C995EAB9DaDfA31Ccd),
            basicRedeemHook: BasicRedeemHook(0x00000000176dD23550c3845746b2036E90DC5912),
            redirectingDepositHook: RedirectingDepositHook(0x0000000024ABbd08686Abb2987831dEa88eF1180),
            lidoDepositHook: LidoDepositHook(address(0)),
            oracleHelper: OracleHelper(0x000000007d2552AD746Af5c13f91B5e72f97c2B7),
            swapModuleImplementation: SwapModule(payable(0x00000000FC6A2De3cfa4840fAA0Ae8B092c9CaA2)),
            mellowAccountV1Implementation: MellowAccountV1(0x00000000860913f37fab81ce8ce4E5BD1f664482)
        });
    }
}
