// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

contract Integration is Test {
    using SharesManagerFlagLibrary for uint256;

    address public vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address public vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address public user = vm.createWallet("user").addr;

    Factory factoryImplementation;

    Factory subvaultFactory;
    Factory depositQueueFactory;
    Factory redeemQueueFactory;

    RootVault rootVaultImplementation;
    TokenizedSharesManager sharesManagerImplementation;
    Oracle oracleImplementation;

    MockERC20 asset = new MockERC20();

    function testRootVault() external {
        factoryImplementation = new Factory("Mellow", 1);

        subvaultFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        subvaultFactory.initialize(vaultAdmin);

        depositQueueFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        depositQueueFactory.initialize(vaultAdmin);

        redeemQueueFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        redeemQueueFactory.initialize(vaultAdmin);

        rootVaultImplementation = new RootVault(
            "Mellow", 1, address(subvaultFactory), address(depositQueueFactory), address(redeemQueueFactory)
        );
        sharesManagerImplementation = new TokenizedSharesManager("Mellow", 1);
        oracleImplementation = new Oracle("Mellow", 1);

        RootVault vault = RootVault(
            payable(new TransparentUpgradeableProxy(address(rootVaultImplementation), vaultProxyAdmin, new bytes(0)))
        );

        TokenizedSharesManager sharesManager = TokenizedSharesManager(
            address(
                new TransparentUpgradeableProxy(address(sharesManagerImplementation), vaultProxyAdmin, new bytes(0))
            )
        );

        sharesManager.initialize(
            abi.encode(
                vault,
                uint256(0).setHasDepositQueues(true).setHasRedeemQueues(true),
                bytes32(0),
                100 ether,
                string("RootVaultERC20Name"),
                string("RootVaultERC20Symbol")
            )
        );

        Oracle depositOracle = Oracle(
            address(new TransparentUpgradeableProxy(address(oracleImplementation), vaultProxyAdmin, new bytes(0)))
        );

        Oracle redeemOracle = Oracle(
            address(new TransparentUpgradeableProxy(address(oracleImplementation), vaultProxyAdmin, new bytes(0)))
        );

        {
            address[] memory assets = new address[](1);
            assets[0] = address(asset);
            bytes memory oracleInitParams = abi.encode(
                vault,
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.05 ether,
                    suspiciousAbsoluteDeviation: 0.01 ether,
                    maxRelativeDeviationD18: 0.05 ether,
                    suspiciousRelativeDeviationD18: 0.01 ether,
                    timeout: 12 hours,
                    secureInterval: 1 hours
                }),
                assets
            );
            depositOracle.initialize(oracleInitParams);
            redeemOracle.initialize(oracleInitParams);
        }

        vault.initialize(
            vaultAdmin,
            abi.encode(new BasicDepositHook()),
            abi.encode(new BasicRedeemHook()), // redeem module params
            address(sharesManager),
            address(depositOracle),
            address(redeemOracle)
        );

        vm.startPrank(vaultAdmin);
        vault.grantFundamentalRole(vaultProxyAdmin, IACLModule.FundamentalRole.PROXY_OWNER);
        vault.grantFundamentalRole(vaultAdmin, IACLModule.FundamentalRole.SUBVAULT_ADMIN);

        bytes32[20] memory roles = [
            PermissionsLibrary.SET_DEPOSIT_HOOK_ROLE,
            PermissionsLibrary.CREATE_DEPOSIT_QUEUE_ROLE,
            PermissionsLibrary.SEND_REPORT_ROLE,
            PermissionsLibrary.ACCEPT_REPORT_ROLE,
            PermissionsLibrary.SET_SECURITY_PARAMS_ROLE,
            PermissionsLibrary.ADD_SUPPORTED_ASSETS_ROLE,
            PermissionsLibrary.REMOVE_SUPPORTED_ASSETS_ROLE,
            PermissionsLibrary.SET_MERKLE_ROOT_ROLE,
            PermissionsLibrary.CALL_ROLE,
            PermissionsLibrary.ADD_ALLOWED_CALLS_ROLE,
            PermissionsLibrary.REMOVE_ALLOWED_CALLS_ROLE,
            PermissionsLibrary.SET_FLAGS_ROLE,
            PermissionsLibrary.SET_ACCOUNT_INFO_ROLE,
            PermissionsLibrary.CREATE_SUBVAULT_ROLE,
            PermissionsLibrary.DISCONNECT_SUBVAULT_ROLE,
            PermissionsLibrary.RECONNECT_SUBVAULT_ROLE,
            PermissionsLibrary.PULL_LIQUIDITY_ROLE,
            PermissionsLibrary.PUSH_LIQUIDITY_ROLE,
            PermissionsLibrary.APPLY_CORRECTION_ROLE,
            PermissionsLibrary.SET_SUBVAULT_LIMIT_ROLE
        ];
        for (uint256 i = 0; i < roles.length; i++) {
            vault.grantRole(roles[i], vaultAdmin);
        }

        {
            address depositQueueImplementation = address(new DepositQueue("Mellow", 1));
            depositQueueFactory.proposeImplementation(depositQueueImplementation);
            depositQueueFactory.acceptProposedImplementation(depositQueueImplementation);
        }

        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), bytes32(0));
        vm.stopPrank();

        vm.startPrank(user);
        {
            address depositQueue = vault.getDepositQueues(address(asset))[0];
            asset.mint(user, 1 ether);
            asset.approve(depositQueue, 1 ether);
            IDepositQueue(depositQueue).deposit(1 ether, new bytes32[](0));
        }
        vm.stopPrank();

        skip(2 hours);

        vm.startPrank(vaultAdmin);
        {
            IOracle.Report[] memory report = new IOracle.Report[](1);
            report[0] = IOracle.Report({asset: address(asset), priceD18: 1 ether});
            depositOracle.sendReport(report);
            depositOracle.acceptReport(address(asset), uint32(block.timestamp));
        }
        vm.stopPrank();

        console2.log(sharesManager.activeSharesOf(user));
        console2.log(sharesManager.claimableSharesOf(user));

        IDepositQueue(vault.getDepositQueues(address(asset))[0]).claim(user);

        console2.log(sharesManager.activeSharesOf(user));
        console2.log(sharesManager.claimableSharesOf(user));
    }
}
