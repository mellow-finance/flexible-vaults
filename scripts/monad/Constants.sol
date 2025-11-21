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

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // MON
    address public constant WETH = 0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701; // WMON

    address public constant WBTC = 0xcf5a6076cfa32686c0Df13aBaDa2b40dec133F1d;
    address public constant USDC = 0xf817257fed379853cDe0fa4F97AB987181B1E5Ea;
    address public constant USDT = 0x88b8E2161DEDC77EF4ab7585569D2415a1C1055D;

    address public constant AAVE_CORE = 0x9861f6a26050e02Ff0C079657F5a3AFcD8D4af52;
    address public constant AAVE_V3_ORACLE = 0x58207F48394a02c933dec4Ee45feC8A55e9cdf38;

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
            weth: WETH,
            proxyAdmin: 0xEcA63DEc77E59EFB15196A610aefF3229Ecd44Ec,
            deployer: 0x4d551d74e851Bd93Ce44D5F588Ba14623249CDda,
            // --- factories ---
            factoryImplementation: Factory(0x883F7dDC499567c9F69f6571F068F948b1000f65),
            factory: Factory(0x24F8DB193AbBf35cdD7fA8f8B9c7CDa57FBdA6cb),
            consensusFactory: Factory(0x68e7318b0c6E5B3e159159eefA956efA3a531894),
            depositQueueFactory: Factory(0x8D90a1BA62038B0eD2Ee2d7079f371F98b8f286C),
            redeemQueueFactory: Factory(0x8772dc6F5d8979F700F06972aeCA28126b8f6D40),
            feeManagerFactory: Factory(0xD7C222Df98aeAc757C66B60E8e150F0C82Df419b),
            oracleFactory: Factory(0x90637d2Fe2BEE554b0BfeAaaB90066c8EdD04A21),
            riskManagerFactory: Factory(0xfA38a77C3dBD3Bbaf7458B41d4528A52a012b322),
            shareManagerFactory: Factory(0x65228e2A1ef99Ebf55F5B445E86B4e41D9134C30),
            subvaultFactory: Factory(0xb6B2d346E5C5F4654128cd0A6096301f2c1E5f58),
            vaultFactory: Factory(0x6122A87Dc95D7ef867235A1c9560402B713Db7Db),
            verifierFactory: Factory(0x20677cDa0d63dE8964DEFa2cc33081877C178574),
            erc20VerifierFactory: Factory(0xEFCA74C9e8010d2c3f4401f93d6F47bE7395DCB2),
            symbioticVerifierFactory: Factory(address(0)),
            eigenLayerVerifierFactory: Factory(address(0)),
            // --- implementations ---
            consensusImplementation: Consensus(0x488E16F9f1c2230Fac0984Adc72468b5B598e9A6),
            depositQueueImplementation: DepositQueue(payable(0x20fd179c46A0cc97b4F26d7397EE9C33E17F7A76)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x890b9b544b8e398eF83a9e44850dC26C928F07d8)),
            redeemQueueImplementation: RedeemQueue(payable(0x8705090340b934C6C54b65b59f25E8aeBa6FEB93)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0x92a4780547046aC7F49ec233BA47B17d8F2d1fdB)),
            feeManagerImplementation: FeeManager(0x50e155409F5E01E2655c2D82c983A1813813D205),
            oracleImplementation: Oracle(0x556d88d93ca699e7a7302969FEA722f1588aC2b2),
            riskManagerImplementation: RiskManager(0x98768d02F68661Cb50E8D382EB44b55534009C10),
            tokenizedShareManagerImplementation: TokenizedShareManager(0xf8bA91e88e799BEaFE201C16cD36bCd051E743e2),
            basicShareManagerImplementation: BasicShareManager(0xccB1289ee47E9C12F483406fB610a186b49ea8Ec),
            subvaultImplementation: Subvault(payable(0x02aF525aa34C7C24f029750EB4133a0b0e44CF86)),
            verifierImplementation: Verifier(0xA9792b6a5E81Eb3De60391d48f5037C02d2913d1),
            vaultImplementation: Vault(payable(0xb5CbBE856eFf518702B903D8DDfEff948b12192A)),
            bitmaskVerifier: BitmaskVerifier(0x7EBa8f20eBA1b62e894c6877dE5FA48AC85D6ee4),
            eigenLayerVerifierImplementation: EigenLayerVerifier(address(0)),
            erc20VerifierImplementation: ERC20Verifier(0x86419C7fd95cEAeb25596a596B5c12008938bFDb),
            symbioticVerifierImplementation: SymbioticVerifier(address(0)),
            // --- helpers / hooks ---
            vaultConfigurator: VaultConfigurator(0xB356b8150967FFea2f6Ab5fE3418F72266a33ee2),
            basicRedeemHook: BasicRedeemHook(0xCb238e06e5753316cbD7799486B5B47004Fa868D),
            redirectingDepositHook: RedirectingDepositHook(0x3E4d14CE26284CF8837a75f32c42EB476D5B4ae6),
            lidoDepositHook: LidoDepositHook(address(0)),
            oracleHelper: OracleHelper(0x4c8379699E5A0B404cE2ba111ab87eDB9C9De783)
        });
    }
}
