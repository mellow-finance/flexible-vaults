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

    address public constant RBTC = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WRBTC = 0x967F8799aF07dF1534d48A95a5C9FEBE92c53AE0;

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
            weth: WRBTC,
            proxyAdmin: 0xf1549a73A3b088d8cD0144360b4Af1B2eAfE05b0,
            deployer: 0x4d551d74e851Bd93Ce44D5F588Ba14623249CDda,
            // --- factories ---
            factoryImplementation: Factory(0x00000004C12438f4593bb6C4047998020e60Fca8),
            factory: Factory(0x0000000013eC5b779Ee3997A005088BCecDa551D),
            erc20VerifierFactory: Factory(0x6D2416bc3A15EfF424577faD7914381DAA3172DE),
            symbioticVerifierFactory: Factory(address(0)),
            eigenLayerVerifierFactory: Factory(address(0)),
            riskManagerFactory: Factory(0x6e72a6F11D0aCA5Cb21F94Dd78727Feb6b78224b),
            subvaultFactory: Factory(0x2b49B9158640f576d50803868cB39C39c111b236),
            verifierFactory: Factory(0x318aec5cBf813eE085c7F5bc9285945d0cF97064),
            vaultFactory: Factory(0xf1d7BE794A16767CA4485ec419984779c3221680),
            shareManagerFactory: Factory(0xEd7d5E840c1567589f7354E278fcE3D549AC5a89),
            consensusFactory: Factory(0xc52C25a06d2c7fbd349C2AD838544A1cF953b8eb),
            depositQueueFactory: Factory(0x4176D4BD30a4AEF3F7ffcDD5Fe8997De807409a4),
            redeemQueueFactory: Factory(0x3C2190540f6Cea0CD81f94e84F91f51644603238),
            feeManagerFactory: Factory(0xcf41afeD6DE8A38F69235d414BB686f2847C19E0),
            oracleFactory: Factory(0x03D4FfC7fB7bfec79EfF121201eB567A4d8E3AbA),
            swapModuleFactory: Factory(address(0)),
            // --- implementations ---
            consensusImplementation: Consensus(0x0000000Ee53D9707851626b0E8485A8599bE95E7),
            depositQueueImplementation: DepositQueue(payable(0x0000000eED98Aca517473d134Cc1a79c5a23b591)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x00000009A6488c99272A1ae297b7f364A348ba55)),
            redeemQueueImplementation: RedeemQueue(payable(0x0000000A37A76557eAf5FF84D537C19aefb61c69)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0x00000009839691F13A8B2Bfb48a02338d5BB4282)),
            feeManagerImplementation: FeeManager(0x0000000852CF76C1c3dd8e74c817c442667f59D3),
            oracleImplementation: Oracle(0x00000000fd75e0935c7101432F07E7D949a3709A),
            riskManagerImplementation: RiskManager(0x00000009BC5616c655EB3931d15553645F79e163),
            tokenizedShareManagerImplementation: TokenizedShareManager(0x0000000Ef763C2e0Fd309DaB48Bb4d5502ebe9F2),
            basicShareManagerImplementation: BasicShareManager(0x00000000DAf16b90ee413672d0C7E51201A444a2),
            subvaultImplementation: Subvault(payable(0x0000000A9671be5CA72833D21A5A048Bb59140A7)),
            verifierImplementation: Verifier(0x00000008d3117169514077a7d3e5e8B7cf76d4EA),
            vaultImplementation: Vault(payable(0x0000000B84D4B6c47f975996CEdd67c475840CB0)),
            bitmaskVerifier: BitmaskVerifier(0x0000000022c92AC77562374F5e4617BF5fF7C2b5),
            erc20VerifierImplementation: ERC20Verifier(0x0000000dAb3d1f8724d96F8BECb864381a89C9C7),
            symbioticVerifierImplementation: SymbioticVerifier(address(0)),
            eigenLayerVerifierImplementation: EigenLayerVerifier(address(0)),
            swapModuleImplementation: SwapModule(payable(address(0))),
            // --- helpers / hooks ---
            vaultConfigurator: VaultConfigurator(0x0000000D0e993ACc4ba4B8EaEC809866C068A3C2),
            basicRedeemHook: BasicRedeemHook(0x00000007A95AcE65df0d6F71660152c196f6330d),
            redirectingDepositHook: RedirectingDepositHook(0x0000000b0bFE39B38d95be646921D9E3756D27ee),
            lidoDepositHook: LidoDepositHook(address(0)),
            oracleHelper: OracleHelper(0x0000000e1a96d9abAb10F19b966F960efc8Ca989)
        });
    }
}
