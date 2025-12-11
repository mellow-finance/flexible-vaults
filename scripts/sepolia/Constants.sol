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
    address public constant WETH = 0xf531B8F309Be94191af87605CfBf600D71C2cFe0;
    address public constant WSTETH = 0x9b87Ea90FDb55e1A0f17FBEdDcF7EB0ac4d50493;
    address public constant STETH = 0xF5465B70Af90AEb26Aa13b1000a8CbEA53a5f4cf;
    address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant USDT = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;

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
            factory: Factory(0xC00F84049e972E3A495e7EA0198D6E99Bd66f836),
            consensusFactory: Factory(0x0b240a3a699b96aa2c5d798e11157730DF5aE363),
            depositQueueFactory: Factory(0x42493D2521E5A936AFA7B980Ff8b686f191A0812),
            redeemQueueFactory: Factory(0x08Ad90AEC1c04d452dc587a1684590bd219dbA43),
            feeManagerFactory: Factory(0x3F56a1471132935c4C9590032B2d3fE626510691),
            oracleFactory: Factory(0xA8b7412CbfEc3DA99f82CbB67439fede2d375570),
            riskManagerFactory: Factory(0x6B2153814355F01Ab32D93eF7f118FE806865714),
            shareManagerFactory: Factory(0x383d8dB8453ea400C8d3A1F4D077D5Ce3c909358),
            subvaultFactory: Factory(0xB0e20537692997d91Ad9D1CA3348aA6152C7eFff),
            vaultFactory: Factory(0xb801f2Fae79122980e1F740D7e99686C538D02Ee),
            verifierFactory: Factory(0xa2cF6419a2544113936143C5808cFe55cB904f2E),
            erc20VerifierFactory: Factory(0x0691DF4Ab69051fBb553Da5F47ffcF5c20b31D96),
            symbioticVerifierFactory: Factory(0xeA88c57d2C58Ba53381B6a01Ca0674F8c99C65b4),
            eigenLayerVerifierFactory: Factory(0x3277Ecd21c0feF399Dfb37A7EDC2D7E55d61fFBd),
            swapModuleFactory: Factory(address(0)),
            consensusImplementation: Consensus(0x0000000167598d2C78E2313fD5328E16bD9A0b13),
            depositQueueImplementation: DepositQueue(payable(0x00000006dA9f179BFE250Dd1c51cD2d3581930c8)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x7914747E912d420e90a29D4D917c0435AEe6eDdc)),
            redeemQueueImplementation: RedeemQueue(payable(0x0000000285805eac535DADdb9648F1E10DfdC411)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0xF46d33D6c07214AA3DfD529013e3E2a71f3A5E0e)),
            feeManagerImplementation: FeeManager(0x0000000dE74e5D51651326E0A3e1ACA94bEAF6E1),
            oracleImplementation: Oracle(0x0000000F0d3D1c31b72368366A4049C05E291D58),
            riskManagerImplementation: RiskManager(0x0000000714cf2851baC1AE2f41871862e9D216fD),
            tokenizedShareManagerImplementation: TokenizedShareManager(0x0000000E8eb7173fA1a3ba60eCA325bcB6aaf378),
            basicShareManagerImplementation: BasicShareManager(0x00000005564AAE40D88e2F08dA71CBe156767977),
            subvaultImplementation: Subvault(payable(0x0000000E535B4E063f8372933A55470e67910a66)),
            verifierImplementation: Verifier(0x000000047Fc878662006E78D5174FB4285637966),
            vaultImplementation: Vault(payable(0xd4ca7b3fFD3284Bc7c36d29cd744a17FA849d730)),
            bitmaskVerifier: BitmaskVerifier(0x0000000263Fb29C3D6B0C5837883519eF05ea20A),
            eigenLayerVerifierImplementation: EigenLayerVerifier(0xcab8F8d3D808E14b01b8B91407402598F13515eC),
            erc20VerifierImplementation: ERC20Verifier(0x00000009207D366cBB8549837F8Ae4bf800Af2D6),
            symbioticVerifierImplementation: SymbioticVerifier(0xD25306C63E0eda289C45cdDbD7865d175F101E03),
            vaultConfigurator: VaultConfigurator(0x992AF00ebbA5B58D8777aD05205D72337372DEb7),
            basicRedeemHook: BasicRedeemHook(0x0000000637f1b1ccDA4Af2dB6CDDf5e5Ec45fd93),
            redirectingDepositHook: RedirectingDepositHook(0x00000004d3B17e5391eb571dDb8fDF95646ca827),
            lidoDepositHook: LidoDepositHook(0xd3b4a229c8074bcF596f6750e50147B5b4c46063),
            oracleHelper: OracleHelper(0x000000005F543c38d5ea6D0bF10A50974Eb55E35),
            swapModuleImplementation: SwapModule(payable(address(0)))
        });
    }
}
