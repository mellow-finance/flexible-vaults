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
    address public constant WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address public constant WSTETH = 0xB82381A3fBD3FaFA77B3a7bE693342618240067b;
    address public constant STETH = 0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af;
    address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    address public constant EIGEN_LAYER_DELEGATION_MANAGER = 0xD4A7E1Bd8015057293f0D0A557088c286942e84b;
    address public constant EIGEN_LAYER_STRATEGY_MANAGER = 0x2E3D6c0744b10eb0A4e6F679F71554a39Ec47a5D;
    address public constant EIGEN_LAYER_REWARDS_COORDINATOR = 0x5ae8152fb88c26ff9ca5C014c94fca3c68029349;

    address public constant COWSWAP_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address public constant COWSWAP_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address public constant SYMBIOTIC_VAULT_FACTORY = 0x407A039D94948484D356eFB765b3c74382A050B4;
    address public constant SYMBIOTIC_FARM_FACTORY = 0xE6381EDA7444672da17Cd859e442aFFcE7e170F0;

    // circle bridge constants
    address public constant DESTINATION_SUBVAULT_HYPER = 0x5A22F6d9C2a735367C33D73530e2D70A72e6D558; // on purrsec
    address public constant DESTINATION_SUBVAULT_SEPOLIA = 0xFcE16317364EC44620F05528Ce170eDc1c6AD5fD; // on sepolia
    uint32 public constant DESTINATION_DOMAIN_HYPER = 19; // purrsec domain id
    uint32 public constant DESTINATION_DOMAIN_SEPOLIA = 0; // sepolia domain id
    address public constant TOKEN_MESSENGER_SEPOLIA = 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA; // on sepolia
    address public constant TOKEN_MESSENGER_HYPER = address(0); // on purrsec

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
            proxyAdmin: 0x12B6692F7240aCbC354cD48Dfc275EfdfB293b24,
            deployer: 0x4222723BCa5B66b29B26714AB5612434EE49C81c,
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
            oracleHelper: OracleHelper(0x000000005F543c38d5ea6D0bF10A50974Eb55E35)
        });
    }

    function getTqETHSepoliaDeployment() internal pure returns (VaultDeployment memory $) {
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

        address[] memory assets_ = new address[](3);
        assets_[0] = Constants.ETH;
        assets_[1] = Constants.WETH;
        assets_[2] = Constants.WSTETH;
        assets_[3] = Constants.USDC;

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
