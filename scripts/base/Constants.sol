// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";
import "../common/interfaces/Imports.sol";

library Constants {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant WSTETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;

    address public constant COWSWAP_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address public constant COWSWAP_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address public constant AAVE_CORE = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address public constant AAVE_V3_ORACLE = 0x2Cc0Fc26eD4563A5ce5e8bdcfe1A2878676Ae156;

    function protocolDeployment() internal pure returns (ProtocolDeployment memory) {
        // return ProtocolDeployment({
        //     deploymentName: DEPLOYMENT_NAME,
        //     deploymentVersion: DEPLOYMENT_VERSION,
        //     eigenLayerDelegationManager: address(0),
        //     eigenLayerStrategyManager: address(0),
        //     eigenLayerRewardsCoordinator: address(0),
        //     symbioticVaultFactory: address(0),
        //     symbioticFarmFactory: address(0),
        //     wsteth: WSTETH,
        //     weth: WETH,
        //     proxyAdmin: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
        //     deployer: 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3,
        //     factoryImplementation: Factory(0),
        //     factory: Factory(0),
        //     consensusFactory: Factory(0),
        //     depositQueueFactory: Factory(0),
        //     redeemQueueFactory: Factory(0),
        //     feeManagerFactory: Factory(0),
        //     oracleFactory: Factory(0),
        //     riskManagerFactory: Factory(0),
        //     shareManagerFactory: Factory(0),
        //     subvaultFactory: Factory(0),
        //     vaultFactory: Factory(0),
        //     verifierFactory: Factory(0),
        //     erc20VerifierFactory: Factory(0),
        //     symbioticVerifierFactory: Factory(address(0)),
        //     eigenLayerVerifierFactory: Factory(address(0)),
        //     consensusImplementation: Consensus(0x5529a8b7fDfc3084457798132f23867a2D6F543A),
        //     depositQueueImplementation: DepositQueue(payable(0x490490008e77Ee657F487a6317Ab36026bbC1014)),
        //     signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x734dc039278d36fE646DEc7000b07278c87eEE41)),
        //     redeemQueueImplementation: RedeemQueue(payable(0x0c982d59044EA2fDb7c21dc7AF8646c6E06d2193)),
        //     signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0xCca06fAF00aa2341969f8E09De5174Cf09e4D4f3)),
        //     feeManagerImplementation: FeeManager(0x2ff1c3052362d007D5224c984B2cB2b7D9f9c071),
        //     oracleImplementation: Oracle(0xF898c0f3961f1C37274688D57745c206F710c821),
        //     riskManagerImplementation: RiskManager(0xC8fb90dE1787B6647B65D4eF1085F72aD7a89F18),
        //     tokenizedShareManagerImplementation: TokenizedShareManager(0xF383422C80fF0387bdfBC929eaa606cA68E60c0E),
        //     basicShareManagerImplementation: BasicShareManager(0x7c559532d2911595f3b1d35E2D10dDaA4979931C),
        //     subvaultImplementation: Subvault(payable(0xCcE00F49f8de5D47A8C1732B1B3600B46Fe20029)),
        //     verifierImplementation: Verifier(0x9037D57EB9ea77584e199B3b0dB7d73AB688176e),
        //     vaultImplementation: Vault(payable(0xFf1EBB8c23fBFe141fCa42A12e5830abF94FE2b1)),
        //     bitmaskVerifier: BitmaskVerifier(0x5d7d52aB5897191D6EEecf25Ae53902287C8e527),
        //     eigenLayerVerifierImplementation: EigenLayerVerifier(address(0)),
        //     erc20VerifierImplementation: ERC20Verifier(0xd701DD7CC2e0e0bdc2bCCb71F04C14B1CB495217),
        //     symbioticVerifierImplementation: SymbioticVerifier(address(0)),
        //     vaultConfigurator: VaultConfigurator(0x9B626C849eaBe8486DDFeb439c97d327447e5996),
        //     basicRedeemHook: BasicRedeemHook(0x8fa635Fa8f63dAdEe19548654B6F3fafDA7d3597),
        //     redirectingDepositHook: RedirectingDepositHook(0x70DFA2c12e3D2100Ea3bd79086E07ddf2bd6B492),
        //     lidoDepositHook: LidoDepositHook(address(0)),
        //     oracleHelper: OracleHelper(0x9bB327889402AC19BF2D164eA79CcfE46c16a37B)
        // });
    }
}
