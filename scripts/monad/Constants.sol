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
    address public constant WETH = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A; // WMON

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
            weth: WETH,
            proxyAdmin: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
            deployer: 0x4d551d74e851Bd93Ce44D5F588Ba14623249CDda,
            // --- factories ---
            factoryImplementation: Factory(0x0000000834bD05fe8A94b5e0bFeC2A58A4C9171E),
            factory: Factory(0x000000049057E402f46800CDC08199b1358a7691),
            erc20VerifierFactory: Factory(0x95d92a89f3Da7E872Ce4fd387790251F32551833),
            symbioticVerifierFactory: Factory(address(0)),
            eigenLayerVerifierFactory: Factory(address(0)),
            riskManagerFactory: Factory(0xE9165b0A6cd7B0ecDb61824B84E8F41b6A8E1eEb),
            subvaultFactory: Factory(0x68098106703ffFb19E8eE8E5f9E351AAaeFEc030),
            verifierFactory: Factory(0x0E77e57b45f457ef4E361c7A0f0913Ea711e038e),
            vaultFactory: Factory(0xb160AE10331F8a21dDB254398F4619c687634371),
            shareManagerFactory: Factory(0x1b0E750CBEa45640622BC2F27885Fa6eD3B5BB3e),
            consensusFactory: Factory(0x416Ef6b7cD1949C3c441831A711D46DA9aF32E4d),
            depositQueueFactory: Factory(0xC51702dd4D3e57cf70411D630c6A7E05beC0D15E),
            redeemQueueFactory: Factory(0x4e8647d0381dE364322c7E6E26e78fbeCA3f646C),
            feeManagerFactory: Factory(0xd54D6CadEB9B8bBF99814f4bBF54424086Db41fE),
            oracleFactory: Factory(0x4226677696289D4c6713186a5815efA981Ac7445),
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
