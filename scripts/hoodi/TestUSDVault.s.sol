// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../src/oracles/OracleSubmitter.sol";
import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "./Constants.sol";

import "../common/ArraysLibrary.sol";

import "../common/interfaces/IAggregatorV3.sol";

contract FakeERC20 is ERC20, Ownable {
    constructor(address owner) ERC20("Fake USDC", "fakeUSDC") Ownable(owner) {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) external onlyOwner {
        _burn(to, amount);
    }
}

contract Deploy is Script, Test {
    // Actors
    address public proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public testAdmin = 0x201f28370f96DD379B8a4BB2aB05e3435324F97B;
    address public lazyVaultAdmin = testAdmin;
    address public activeVaultAdmin = testAdmin;
    address public curator = testAdmin;
    address public oracleUpdater = testAdmin;
    address public oracleAccepter = testAdmin;
    address public treasury = testAdmin;

    string public name = "Test USD";
    string public symbol = "testUSD";

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);
        if (true) {
            _acceptReports(OracleSubmitter(0xB5Fe768319539D3C0C849916124d7f9046d303f5), deployer);
            return;
        }

        address asset = address(new FakeERC20(deployer));
        console.log("Fake asset: %s", asset);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);

        {
            uint256 i = 0;

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, deployer);

            assembly {
                mstore(holders, i)
            }
        }

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 2,
            shareManagerParams: abi.encode(bytes32(0), name, symbol),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, treasury, uint24(0), uint24(0), uint24(0), uint24(0)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005e30,
                    suspiciousAbsoluteDeviation: 0.001e30,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 15 minutes,
                    depositInterval: 1 minutes,
                    redeemInterval: 5 minutes
                }),
                ArraysLibrary.makeAddressArray(abi.encode(asset))
            ),
            defaultDepositHook: address(0),
            defaultRedeemHook: address(0),
            queueLimit: 4,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        // queues setup

        vault.createQueue(0, true, proxyAdmin, asset, new bytes(0)); // async deposit queue
        vault.createQueue(2, true, proxyAdmin, asset, abi.encode(0, 168 hours)); // sync deposit queue

        vault.createQueue(0, false, proxyAdmin, asset, new bytes(0)); // async redeem queue
        vault.createQueue(2, false, proxyAdmin, asset, abi.encode(0, 168 hours, 24 hours * 1 ether)); // sync redeem queue

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), asset);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        console.log("Vault %s", address(vault));
        {
            string memory symbol_ = asset == Constants.ETH ? "ETH" : IERC20Metadata(asset).symbol();
            for (uint256 j = 0; j < vault.getQueueCount(asset); j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    try ISyncQueue(queue).name() returns (string memory) {
                        console.log("SyncDepositQueue (%s): %s", symbol_, queue);
                    } catch {
                        console.log("DepositQueue (%s): %s", symbol_, queue);
                    }
                } else {
                    try ISyncQueue(queue).name() returns (string memory) {
                        console.log("SyncRedeemQueue (%s): %s", symbol_, queue);
                    } catch {
                        console.log("RedeemQueue (%s): %s", symbol_, queue);
                    }
                }
            }
        }

        console.log("Oracle %s", address(vault.oracle()));
        console.log("ShareManager %s", address(vault.shareManager()));
        console.log("FeeManager %s", address(vault.feeManager()));
        console.log("RiskManager %s", address(vault.riskManager()));

        OracleSubmitter oracleSubmitter =
            new OracleSubmitter(deployer, oracleUpdater, oracleAccepter, address(vault.oracle()));
        oracleSubmitter.grantRole(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        oracleSubmitter.grantRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        oracleSubmitter.grantRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
        oracleSubmitter.renounceRole(Permissions.DEFAULT_ADMIN_ROLE, deployer);
        vault.grantRole(Permissions.SUBMIT_REPORTS_ROLE, address(oracleSubmitter));
        vault.grantRole(Permissions.ACCEPT_REPORT_ROLE, address(oracleSubmitter));

        console.log("OracleSubmitter: %s", address(oracleSubmitter));

        {
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0].asset = asset;
            reports[0].priceD18 = 10 ** 30;
            oracleSubmitter.submitReports(reports);
        }

        // _acceptReports(oracleSubmitter, deployer);

        // vm.stopBroadcast();
        // address[] memory queueAssets = ArraysLibrary.makeAddressArray(abi.encode(asset, asset));
        // AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        // AcceptanceLibrary.runVaultDeploymentChecks(
        //     Constants.protocolDeployment(),
        //     VaultDeployment({
        //         vault: vault,
        //         calls: new SubvaultCalls[](0),
        //         initParams: initParams,
        //         holders: _getExpectedHolders(address(oracleSubmitter), deployer),
        //         depositHook: address(0),
        //         redeemHook: address(0),
        //         assets: ArraysLibrary.makeAddressArray(abi.encode(asset)),
        //         depositQueueAssets: queueAssets,
        //         redeemQueueAssets: queueAssets,
        //         subvaultVerifiers: new address[](0),
        //         timelockControllers: new address[](0),
        //         timelockProposers: new address[](0),
        //         timelockExecutors: new address[](0)
        //     })
        // );

        // revert("ok");
    }

    function _acceptReports(OracleSubmitter oracleSubmitter, address deployer) internal {
        IOracle oracle = oracleSubmitter.oracle();
        uint256 n = oracle.supportedAssets();
        address[] memory assets = new address[](n);
        uint32[] memory timestamps = new uint32[](n);
        uint224[] memory prices = new uint224[](n);
        for (uint256 i = 0; i < n; i++) {
            address a = oracle.supportedAssetAt(i);
            IOracle.DetailedReport memory r = oracle.getReport(a);
            assets[i] = a;
            timestamps[i] = r.timestamp;
            prices[i] = r.priceD18;
        }
        oracleSubmitter.acceptReports(assets, prices, timestamps);
        oracleSubmitter.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        oracleSubmitter.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
    }

    function _getExpectedHolders(address oracleSubmitter, address deployer)
        internal
        view
        returns (Vault.RoleHolder[] memory holders)
    {
        holders = new Vault.RoleHolder[](50);
        uint256 i = 0;

        // lazyVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);

        // oracle updater roles:
        holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleSubmitter);
        holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, oracleSubmitter);

        holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, deployer);
        holders[i++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);

        assembly {
            mstore(holders, i)
        }
    }
}
