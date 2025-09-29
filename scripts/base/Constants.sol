// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";
import "../common/interfaces/Imports.sol";

import "./tqETHLibrary.sol";

library Constants {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant WSTETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;

    address public constant COWSWAP_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address public constant COWSWAP_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address public constant AAVE_CORE = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address public constant AAVE_V3_ORACLE = 0x2Cc0Fc26eD4563A5ce5e8bdcfe1A2878676Ae156;

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
            proxyAdmin: 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3,
            deployer: 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3,
            factoryImplementation: Factory(0x618d8f82Ad96f571a8F6b4Af7FD5018074496E31),
            factory: Factory(0xE43BcD5973AF1B8e53A7f5Ec0461579956fC9cFf),
            consensusFactory: Factory(0x21Af3393D57d0421659d4fe1C0ae8be12040f900),
            depositQueueFactory: Factory(0x186a70A81185cE70D70d2C832585Ef2a51019712),
            redeemQueueFactory: Factory(0xdAc930F1fe68E72b9a8FaA112FE4B225deD94551),
            feeManagerFactory: Factory(0x30FA5f2289304eADEf3E1F6a949c32e1A9771400),
            oracleFactory: Factory(0x2df6F863F1874e31063b02EcEd23CC1DEda4AFDe),
            riskManagerFactory: Factory(0xCaa7089D40B8BEd902f45cb0F3406A7102b8C22E),
            shareManagerFactory: Factory(0x99A0BCc1Db9236FdDda4D02D7F69e7c905295fC6),
            subvaultFactory: Factory(0xE3A7C69816f1337f65a25a4792CB87cb509E3bFB),
            vaultFactory: Factory(0xCA2902A4547E19e05430De5Fd5d6fD0E192416AD),
            verifierFactory: Factory(0x10B98695aBeeC98FADaeE5155819434670936206),
            erc20VerifierFactory: Factory(0x2fA2bAe90159105F03C3906D1B8640C2b48B2b19),
            symbioticVerifierFactory: Factory(address(0)),
            eigenLayerVerifierFactory: Factory(address(0)),
            consensusImplementation: Consensus(0x5529a8b7fDfc3084457798132f23867a2D6F543A),
            depositQueueImplementation: DepositQueue(payable(0x490490008e77Ee657F487a6317Ab36026bbC1014)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x734dc039278d36fE646DEc7000b07278c87eEE41)),
            redeemQueueImplementation: RedeemQueue(payable(0x0c982d59044EA2fDb7c21dc7AF8646c6E06d2193)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0xCca06fAF00aa2341969f8E09De5174Cf09e4D4f3)),
            feeManagerImplementation: FeeManager(0x2ff1c3052362d007D5224c984B2cB2b7D9f9c071),
            oracleImplementation: Oracle(0xF898c0f3961f1C37274688D57745c206F710c821),
            riskManagerImplementation: RiskManager(0xC8fb90dE1787B6647B65D4eF1085F72aD7a89F18),
            tokenizedShareManagerImplementation: TokenizedShareManager(0xF383422C80fF0387bdfBC929eaa606cA68E60c0E),
            basicShareManagerImplementation: BasicShareManager(0x7c559532d2911595f3b1d35E2D10dDaA4979931C),
            subvaultImplementation: Subvault(payable(0xCcE00F49f8de5D47A8C1732B1B3600B46Fe20029)),
            verifierImplementation: Verifier(0x9037D57EB9ea77584e199B3b0dB7d73AB688176e),
            vaultImplementation: Vault(payable(0xFf1EBB8c23fBFe141fCa42A12e5830abF94FE2b1)),
            bitmaskVerifier: BitmaskVerifier(0x5d7d52aB5897191D6EEecf25Ae53902287C8e527),
            eigenLayerVerifierImplementation: EigenLayerVerifier(address(0)),
            erc20VerifierImplementation: ERC20Verifier(0xd701DD7CC2e0e0bdc2bCCb71F04C14B1CB495217),
            symbioticVerifierImplementation: SymbioticVerifier(address(0)),
            vaultConfigurator: VaultConfigurator(0x9B626C849eaBe8486DDFeb439c97d327447e5996),
            basicRedeemHook: BasicRedeemHook(0x8fa635Fa8f63dAdEe19548654B6F3fafDA7d3597),
            redirectingDepositHook: RedirectingDepositHook(0x70DFA2c12e3D2100Ea3bd79086E07ddf2bd6B492),
            lidoDepositHook: LidoDepositHook(address(0)),
            oracleHelper: OracleHelper(0x9bB327889402AC19BF2D164eA79CcfE46c16a37B)
        });
    }
}
