// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

contract Integration is Test {
    using ShareManagerFlagLibrary for uint256;

    address public vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    Vm.Wallet public vaultAdminWallet = vm.createWallet("vaultAdmin");
    address public vaultAdmin = vaultAdminWallet.addr;
    address public user = vm.createWallet("user").addr;

    Factory factoryImplementation;

    Factory riskManagerFactory;
    Factory subvaultFactory;
    Factory depositQueueFactory;
    Factory redeemQueueFactory;
    Factory verifierFactory;

    Vault vaultImplementation;
    TokenizedShareManager shareManagerImplementation;
    FeeManager feeManagerImplementation;
    Oracle oracleImplementation;

    MockERC20 asset = new MockERC20();

    function testVault() external {
        factoryImplementation = new Factory("Mellow", 1);

        verifierFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        verifierFactory.initialize(abi.encode(vaultAdmin));

        subvaultFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        subvaultFactory.initialize(abi.encode(vaultAdmin));

        depositQueueFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        depositQueueFactory.initialize(abi.encode(vaultAdmin));

        redeemQueueFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        redeemQueueFactory.initialize(abi.encode(vaultAdmin));

        riskManagerFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        riskManagerFactory.initialize(abi.encode(vaultAdmin));

        vaultImplementation = new Vault(
            "Mellow",
            1,
            address(depositQueueFactory),
            address(redeemQueueFactory),
            address(subvaultFactory),
            address(verifierFactory)
        );
        shareManagerImplementation = new TokenizedShareManager("Mellow", 1);
        feeManagerImplementation = new FeeManager("Mellow", 1);
        oracleImplementation = new Oracle("Mellow", 1);

        Vault vault =
            Vault(payable(new TransparentUpgradeableProxy(address(vaultImplementation), vaultProxyAdmin, new bytes(0))));

        vm.startPrank(vaultAdmin);
        {
            address depositQueueImplementation = address(new DepositQueue("Mellow", 1));
            depositQueueFactory.proposeImplementation(depositQueueImplementation);
            depositQueueFactory.acceptProposedImplementation(depositQueueImplementation);
            address signatureDepositQueueImplementation = address(new SignatureDepositQueue("Mellow", 1));
            depositQueueFactory.proposeImplementation(signatureDepositQueueImplementation);
            depositQueueFactory.acceptProposedImplementation(signatureDepositQueueImplementation);

            address redeemQueueImplementation = address(new RedeemQueue("Mellow", 1));
            redeemQueueFactory.proposeImplementation(redeemQueueImplementation);
            redeemQueueFactory.acceptProposedImplementation(redeemQueueImplementation);
            address signatureRedeemQueueImplementation = address(new SignatureRedeemQueue("Mellow", 1));
            redeemQueueFactory.proposeImplementation(signatureRedeemQueueImplementation);
            redeemQueueFactory.acceptProposedImplementation(signatureRedeemQueueImplementation);

            address verifierImplementation = address(new Verifier("Mellow", 1));
            verifierFactory.proposeImplementation(verifierImplementation);
            verifierFactory.acceptProposedImplementation(verifierImplementation);

            address subvaultImplementation = address(new Subvault("Mellow", 1));
            subvaultFactory.proposeImplementation(subvaultImplementation);
            subvaultFactory.acceptProposedImplementation(subvaultImplementation);

            address riskManagerImplementation = address(new RiskManager("Mellow", 1));
            riskManagerFactory.proposeImplementation(riskManagerImplementation);
            riskManagerFactory.acceptProposedImplementation(riskManagerImplementation);
        }
        vm.stopPrank();

        TokenizedShareManager shareManager = TokenizedShareManager(
            address(new TransparentUpgradeableProxy(address(shareManagerImplementation), vaultProxyAdmin, new bytes(0)))
        );

        shareManager.initialize(abi.encode(vault, bytes32(0), string("VaultERC20Name"), string("VaultERC20Symbol")));

        FeeManager feeManager = FeeManager(
            address(new TransparentUpgradeableProxy(address(feeManagerImplementation), vaultProxyAdmin, new bytes(0)))
        );
        feeManager.initialize(
            abi.encode(
                vaultAdmin,
                vaultAdmin, // feeRecipient
                0, // depositFeeD6
                1e4, // redeemFeeD6
                0, // performanceFeeD6
                0 // protocolFeeD6
            )
        );

        Oracle oracle = Oracle(
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
            oracle.initialize(oracleInitParams);
        }

        RiskManager riskManager =
            RiskManager(riskManagerFactory.create(0, vaultProxyAdmin, abi.encode(address(vault), int256(100 ether))));

        vault.initialize(
            abi.encode(
                vaultAdmin,
                address(shareManager),
                address(feeManager),
                address(riskManager),
                address(oracle),
                address(new RedirectingDepositHook()),
                address(new BasicRedeemHook()),
                new Vault.RoleHolder[](0)
            ) // redeem module params
        );

        Verifier verifier = Verifier(verifierFactory.create(0, vaultProxyAdmin, abi.encode(address(vault), bytes32(0))));
        vm.startPrank(vaultAdmin);
        vault.grantFundamentalRole(IACLModule.FundamentalRole.PROXY_OWNER, vaultProxyAdmin);

        bytes32[24] memory roles = [
            vault.SET_CUSTOM_HOOK_ROLE(),
            vault.CREATE_DEPOSIT_QUEUE_ROLE(),
            vault.CREATE_REDEEM_QUEUE_ROLE(),
            oracle.SUBMIT_REPORT_ROLE(),
            oracle.ACCEPT_REPORT_ROLE(),
            oracle.SET_SECURITY_PARAMS_ROLE(),
            oracle.ADD_SUPPORTED_ASSETS_ROLE(),
            oracle.REMOVE_SUPPORTED_ASSETS_ROLE(),
            verifier.SET_MERKLE_ROOT_ROLE(),
            verifier.CALL_ROLE(),
            // verifier.ADD_ALLOWED_CALLS_ROLE(),
            // verifier.REMOVE_ALLOWED_CALLS_ROLE(),
            shareManager.SET_FLAGS_ROLE(),
            shareManager.SET_ACCOUNT_INFO_ROLE(),
            vault.CREATE_SUBVAULT_ROLE(),
            vault.DISCONNECT_SUBVAULT_ROLE(),
            vault.RECONNECT_SUBVAULT_ROLE(),
            vault.PULL_LIQUIDITY_ROLE(),
            vault.PUSH_LIQUIDITY_ROLE(),
            riskManager.SET_VAULT_LIMIT_ROLE(),
            riskManager.SET_SUBVAULT_LIMIT_ROLE(),
            riskManager.MODIFY_PENDING_ASSETS_ROLE(),
            riskManager.MODIFY_VAULT_BALANCE_ROLE(),
            riskManager.MODIFY_SUBVAULT_BALANCE_ROLE(),
            riskManager.ALLOW_SUBVAULT_ASSETS_ROLE(),
            riskManager.DISALLOW_SUBVAULT_ASSETS_ROLE()
        ];
        for (uint256 i = 0; i < roles.length; i++) {
            vault.grantRole(roles[i], vaultAdmin);
        }
        vault.grantRole(vault.PUSH_LIQUIDITY_ROLE(), address(vault));
        vault.grantRole(vault.PULL_LIQUIDITY_ROLE(), address(vault));

        Consensus consensusImplementation = new Consensus("Consensus", 1);
        Consensus consensus = Consensus(
            address(new TransparentUpgradeableProxy(address(consensusImplementation), vaultProxyAdmin, new bytes(0)))
        );
        consensus.initialize(vaultAdmin);
        consensus.addSigner(vaultAdmin, 1, IConsensus.SignatureType.EIP712);

        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        vault.createRedeemQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        vault.createDepositQueue(
            1, vaultProxyAdmin, address(asset), abi.encode(address(consensus), string("x"), string("y"))
        );
        vault.createRedeemQueue(
            1, vaultProxyAdmin, address(asset), abi.encode(address(consensus), string("x"), string("y"))
        );

        skip(1 hours);
        {
            IOracle.Report[] memory report = new IOracle.Report[](1);
            report[0] = IOracle.Report({asset: address(asset), priceD18: 1 ether});
            oracle.submitReports(report);
            oracle.acceptReport(address(asset), uint32(block.timestamp));
            skip(1 days);
        }

        {
            address subvault = vault.createSubvault(0, vaultProxyAdmin, address(verifier));
            address[] memory assets = new address[](1);
            assets[0] = address(asset);
            riskManager.allowSubvaultAssets(subvault, assets);
            riskManager.setSubvaultLimit(subvault, 100 ether);
        }
        vm.stopPrank();
        vm.startPrank(user);
        {
            address depositQueue = vault.queueAt(address(asset), 0);
            asset.mint(user, 1 ether);
            asset.approve(depositQueue, 1 ether);
            IDepositQueue(depositQueue).deposit(1 ether, address(0), new bytes32[](0));
            skip(1 days);
        }
        vm.stopPrank();
        vm.startPrank(vaultAdmin);
        {
            IOracle.Report[] memory report = new IOracle.Report[](1);
            report[0] = IOracle.Report({asset: address(asset), priceD18: 1 ether});
            oracle.submitReports(report);
        }
        vm.stopPrank();
        vm.startPrank(user);

        console2.log(shareManager.activeSharesOf(user));
        console2.log(shareManager.claimableSharesOf(user));

        IDepositQueue(vault.queueAt(address(asset), 0)).claim(user);

        console2.log(shareManager.activeSharesOf(user));
        console2.log(shareManager.claimableSharesOf(user));

        IRedeemQueue(vault.queueAt(address(asset), 1)).redeem(1 ether * (1e6 - 2e4 + uint256(1e4) / 365) / 1e6);
        vm.stopPrank();

        skip(1 days);

        vm.startPrank(vaultAdmin);
        {
            IOracle.Report[] memory report = new IOracle.Report[](1);
            report[0] = IOracle.Report({asset: address(asset), priceD18: 1 ether});
            oracle.submitReports(report);
        }
        vm.stopPrank();

        skip(1 days);

        vm.startPrank(user);
        {
            uint256[] memory timestamps = new uint256[](1);
            timestamps[0] = block.timestamp - 2 days;

            IRedeemQueue(vault.queueAt(address(asset), 1)).handleReports(1);
            IRedeemQueue(vault.queueAt(address(asset), 1)).claim(user, timestamps);
        }
        vm.stopPrank();

        console2.log(
            asset.balanceOf(address(vault)), asset.balanceOf(user), asset.balanceOf(vault.queueAt(address(asset), 1))
        );

        {
            SignatureDepositQueue q = SignatureDepositQueue(vault.queueAt(address(asset), 2));
            ISignatureQueue.Order memory order = ISignatureQueue.Order({
                orderId: 0,
                queue: address(q),
                asset: address(asset),
                caller: user,
                recipient: user,
                ordered: 1 ether,
                requested: 1 ether,
                deadline: block.timestamp + 1 days,
                nonce: q.nonces(user)
            });
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(vaultAdminWallet, q.hashOrder(order));

            vm.startPrank(user);

            deal(address(asset), user, 1 ether);
            asset.approve(address(q), 1 ether);

            IConsensus.Signature[] memory signatures = new IConsensus.Signature[](1);
            signatures[0] = IConsensus.Signature({signer: vaultAdmin, signature: abi.encodePacked(r, s, v)});

            q.deposit(order, signatures);

            vm.stopPrank();
        }

        console2.log(shareManager.activeSharesOf(user), asset.balanceOf(user));

        {
            SignatureRedeemQueue q = SignatureRedeemQueue(vault.queueAt(address(asset), 3));
            ISignatureQueue.Order memory order = ISignatureQueue.Order({
                orderId: 0,
                queue: address(q),
                asset: address(asset),
                caller: user,
                recipient: user,
                ordered: 1 ether,
                requested: 1 ether,
                deadline: block.timestamp + 1 days,
                nonce: q.nonces(user)
            });
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(vaultAdminWallet, q.hashOrder(order));

            vm.startPrank(user);
            asset.approve(address(q), 1 ether);

            IConsensus.Signature[] memory signatures = new IConsensus.Signature[](1);
            signatures[0] = IConsensus.Signature({signer: vaultAdmin, signature: abi.encodePacked(r, s, v)});
            q.redeem(order, signatures);

            vm.stopPrank();
        }
        console2.log(shareManager.activeSharesOf(user), asset.balanceOf(user));
    }
}
