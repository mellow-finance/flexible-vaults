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

    address public constant HYPE = 0x2222222222222222222222222222222222222222;
    address public constant CORE = 0x3333333333333333333333333333333333333333;
    address public constant USDC = 0x2B3370eE501B4a559b57D449569354196457D8Ab;

    // circle bridge constants
    address public constant TOKEN_MESSENGER_HYPER = 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA; // on purrsec
    address public constant DESTINATION_SUBVAULT_SEPOLIA = 0xFcE16317364EC44620F05528Ce170eDc1c6AD5fD; // on sepolia
    uint32 public constant DESTINATION_DOMAIN_SEPOLIA = 0; // sepolia domain id

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
            weth: address(0),
            proxyAdmin: 0x4632F2407f247217eE27c3699CbAa7F84584Cb58,
            deployer: 0x4222723BCa5B66b29B26714AB5612434EE49C81c,
            factoryImplementation: Factory(0x0000000397b71C8f3182Fd40D247330D218fdC72),
            factory: Factory(0x7Ac37D161401d849787ea8245EBDc1cFc97756F9),
            consensusFactory: Factory(0x961894e7489Ac6B663415138297844bFeD0e63F3),
            depositQueueFactory: Factory(0xab1a01Cb97Fe5894ba8779247fc7BF8DDa6180f8),
            redeemQueueFactory: Factory(0x83127bd90976cc1f429BaA3Eb42ae1F18cb690c5),
            feeManagerFactory: Factory(0xE6496c481E85B54499caeAF339FD855CF3f5e94C),
            oracleFactory: Factory(0x614BEF0fAcc82830f6E12249ddE8b3d47b7CE102),
            riskManagerFactory: Factory(0x7242de8D0e3dAF723b5AeF0C4B207f07c3F81aA5),
            shareManagerFactory: Factory(0xf54D8433603670334C6ad9D1b9CCa574A14C82c1),
            subvaultFactory: Factory(0x71deDd5787aCC3a6f35A88393dd2691b82F14b69),
            vaultFactory: Factory(0xb8F3988f8d81138c73A32302421c6E4532f6836F),
            verifierFactory: Factory(0x206f922aE23Dc359E01eF9b041A8F7d15E9DfD70),
            erc20VerifierFactory: Factory(0xa885243154F3249AeD2AF50979C8eAe836C7e4F0),
            symbioticVerifierFactory: Factory(0xeA88c57d2C58Ba53381B6a01Ca0674F8c99C65b4),
            eigenLayerVerifierFactory: Factory(0x3277Ecd21c0feF399Dfb37A7EDC2D7E55d61fFBd),
            consensusImplementation: Consensus(0x0000000167598d2C78E2313fD5328E16bD9A0b13),
            depositQueueImplementation: DepositQueue(payable(0x00000006dA9f179BFE250Dd1c51cD2d3581930c8)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0xEe77887e0D2E9574E99a4551b6cCE9adED2f76F3)),
            redeemQueueImplementation: RedeemQueue(payable(0x0000000285805eac535DADdb9648F1E10DfdC411)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0x1c716e04f9F2d6705339FbbE2209383E49be723a)),
            feeManagerImplementation: FeeManager(0x0000000dE74e5D51651326E0A3e1ACA94bEAF6E1),
            oracleImplementation: Oracle(0x0000000F0d3D1c31b72368366A4049C05E291D58),
            riskManagerImplementation: RiskManager(0x0000000714cf2851baC1AE2f41871862e9D216fD),
            tokenizedShareManagerImplementation: TokenizedShareManager(0x0000000E8eb7173fA1a3ba60eCA325bcB6aaf378),
            basicShareManagerImplementation: BasicShareManager(0x00000005564AAE40D88e2F08dA71CBe156767977),
            subvaultImplementation: Subvault(payable(0x0000000E535B4E063f8372933A55470e67910a66)),
            verifierImplementation: Verifier(0x000000047Fc878662006E78D5174FB4285637966),
            vaultImplementation: Vault(payable(0x5eC8936CEF729Ec88fC99a85B16701747A396688)),
            bitmaskVerifier: BitmaskVerifier(0x0000000263Fb29C3D6B0C5837883519eF05ea20A),
            eigenLayerVerifierImplementation: EigenLayerVerifier(0xcab8F8d3D808E14b01b8B91407402598F13515eC),
            erc20VerifierImplementation: ERC20Verifier(0x00000009207D366cBB8549837F8Ae4bf800Af2D6),
            symbioticVerifierImplementation: SymbioticVerifier(0xD25306C63E0eda289C45cdDbD7865d175F101E03),
            vaultConfigurator: VaultConfigurator(0x7A1C9938CE79F877E8a2164dB129d6Bff4BF72C7),
            basicRedeemHook: BasicRedeemHook(0x0000000637f1b1ccDA4Af2dB6CDDf5e5Ec45fd93),
            redirectingDepositHook: RedirectingDepositHook(0x00000004d3B17e5391eb571dDb8fDF95646ca827),
            lidoDepositHook: LidoDepositHook(0xd3b4a229c8074bcF596f6750e50147B5b4c46063),
            oracleHelper: OracleHelper(0x000000005F543c38d5ea6D0bF10A50974Eb55E35)
        });
    }

    function getTqETHHyperDeployment() internal view returns (VaultDeployment memory $) {
        /// @dev is not valid: update before deployment
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

        address[] memory assets_ = new address[](1);
        assets_[0] = Constants.USDC;

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
        (, IVerifier.VerificationPayload[] memory leaves) = tqETHLibrary.getSubvault0Proofs(curator);
        $.calls[0] = tqETHLibrary.getSubvault0SubvaultCalls(curator, leaves);
    }
}
