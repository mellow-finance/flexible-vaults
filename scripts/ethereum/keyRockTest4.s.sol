// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/ArraysLibrary.sol";

import "../common/DeployVaultFactory.sol";
import "../common/DeployVaultFactoryRegistry.sol";
import "../common/OracleSubmitterFactory.sol";
import "../common/ProofLibrary.sol";
import "./DeployAbstractScript.s.sol";

contract Deploy is DeployAbstractScript {
    function run() external {
        _simulateXReserveDepositToRemote();
        return;
        deployVault = IDeployVaultFactory(0x9cbD8a4033fDa06809B5e0056287b512Bbf579Ef); //deployNewDeployVault();//

        /// @dev just on-chain simulation
       // _simulate();
       // revert("ok");

        /// @dev on-chain transaction
        //  if vault == address(0) -> step one
        //  else -> step two
        /// @dev fill in Vault address to run stepTwo
        vault = Vault(payable(address(0xb93AEac27E82eb2A8555F7fEf3984CfACEB20275)));
        //_run();
        //deposit(Constants.USDC, address(0xaD0F7fE1264baECF2b3102cF2514285FCb1BdC41));
        // swap module - skip
        //_deploySwapModule(vault.subvaultAt(0));
        // xReserve test tx (simulation only)
        //revert("ok");
    }

    function deployNewDeployVault() internal returns (IDeployVaultFactory deployVault) {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        vm.startBroadcast(deployerPk);
        DeployVaultFactoryRegistry deployVaultFactoryRegistry = new DeployVaultFactoryRegistry();
        address oracleSubmitterFactory = 0x00000009918c4BC0829C93312b059E7F7Ba8C273;
        deployVault = new DeployVaultFactory(
            address($.vaultConfigurator),
            address($.verifierFactory),
            oracleSubmitterFactory,
            address(deployVaultFactoryRegistry)
        );
        vm.stopBroadcast();
    }

    function deposit(address asset, address queue) internal {
        string memory symbol;
        IDepositQueue depositQueue = IDepositQueue(queue);
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);
        uint224 amount;
        uint256 value;
        if (asset == Constants.ETH) {
            symbol = "ETH";
            value = 1 gwei;
            amount = uint224(value);
        } else {
            symbol = IERC20Metadata(asset).symbol();
            amount = uint224(IERC20(asset).balanceOf(deployer)) / 100;
            IERC20(asset).approve(address(depositQueue), amount);
        }
        depositQueue.deposit{value: value}(amount, address(0), new bytes32[](0));
        IShareManager shareManager = vault.shareManager();
        console.log("%s %s deposited, shares received:", symbol, amount, shareManager.sharesOf(deployer));
        vm.stopBroadcast();
    }

    function deployMellowAccount(address proxyOwner, address owner, string memory name) internal returns (address mellowAccount) {
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        mellowAccount = address($.accountFactory.create(0, proxyOwner, abi.encode(owner)));
        console.log("MellowAccount deployed at %s (%s)", mellowAccount, name);
        vm.stopBroadcast();
    }

    function setUp() public override {
        /// @dev fill name and symbol
        vaultName = "test KeyRock Canton";
        vaultSymbol = "tKRC";
        address keyrokFordefi = 0xf1a9676B03Dd3B2066214D2aD8B4B59ED6642C53;
        address mellowTempAdmin = 0x2B0c1b06f098E024AAA2c8f73CAEa44Ae5585467; // deployer + keyrokFordefi 1/2

        /// @dev fill admin/operational addresses
        proxyAdmin = mellowTempAdmin;
        lazyVaultAdmin = mellowTempAdmin;
        activeVaultAdmin = mellowTempAdmin;
        oracleUpdater = mellowTempAdmin;
        curator = mellowTempAdmin;
        feeManagerOwner = mellowTempAdmin;
        pauser = mellowTempAdmin;

        timelockProposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));
        timelockExecutors = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, pauser));

        /// @dev fill fee parameters
        depositFeeD6 = 0;
        redeemFeeD6 = 0;
        performanceFeeD6 = 0; // 0%
        protocolFeeD6 = 0; // 0%

        /// @dev fill security params
        securityParams = IOracle.SecurityParams({
            // strict params to avoid price deviations
            maxAbsoluteDeviation: 1,
            suspiciousAbsoluteDeviation: 1,
            maxRelativeDeviationD18: 1,
            suspiciousRelativeDeviationD18: 1,
            timeout: 1 seconds,
            depositInterval: 1 seconds, // does not affect sync deposit queue
            redeemInterval: 1 seconds // almost all redeems will be handled in the same report as they are not delayed, so redeem interval can be the same as timeout
        });

        ProtocolDeployment memory $ = Constants.protocolDeployment();

        /// @dev fill default hooks
        defaultDepositHook = address($.redirectingDepositHook);
        defaultRedeemHook = address($.basicRedeemHook);

        /// @dev fill share manager params
        shareManagerWhitelistMerkleRoot = bytes32(0);

        /// @dev fill risk manager params
        riskManagerLimit = 1e8 ether; // 100M USDC

        /// @dev fill versions
        vaultVersion = 0;
        shareManagerVersion = 0; // TokenizedShareManager, impl: 0x0000000E8eb7173fA1a3ba60eCA325bcB6aaf378
        feeManagerVersion = 0;
        riskManagerVersion = 0;
        oracleVersion = 0;
    }

    /// @dev fill in subvault parameters
    function getSubvaultParams()
        internal
        pure
        override
        returns (IDeployVaultFactory.SubvaultParams[] memory subvaultParams)
    {
        subvaultParams = new IDeployVaultFactory.SubvaultParams[](1);

        subvaultParams[0].assets =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC));
        subvaultParams[0].version = uint256(SubvaultVersion.DEFAULT);
        subvaultParams[0].verifierVersion = 0;
        subvaultParams[0].limit = 1e8 ether; // 100M USDC
    }

    /// @dev fill in queue parameters
    function getQueues()
        internal
        pure
        override
        returns (IDeployVaultFactory.QueueParams[] memory queues, uint256 queueLimit)
    {
        queues = new IDeployVaultFactory.QueueParams[](2);

        queues[0] = IDeployVaultFactory.QueueParams({
            version: uint256(3),
            isDeposit: true,
            asset: Constants.USDC,
            data: abi.encode(uint256(0), uint32(365 days)) // penaltyD6, maxAge for SyncDepositQueue
        });

        queues[1] =
            IDeployVaultFactory.QueueParams({version: uint256(2), isDeposit: false, asset: Constants.USDC, data: ""});

        queueLimit = 2;
    }

    /// @dev fill in allowed assets/base asset and subvault assets
    function getAssetsWithPrices()
        internal
        pure
        override
        returns (address[] memory allowedAssets, uint224[] memory allowedAssetsPrices)
    {
        allowedAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC));
        allowedAssetsPrices = new uint224[](allowedAssets.length);
        allowedAssetsPrices[0] = uint224(1e30); // USDC 6 decimals
    }

    /// @dev fill in vault role holders
    function getVaultRoleHolders(address timelockController, address oracleSubmitter)
        internal
        view
        override
        returns (Vault.RoleHolder[] memory holders)
    {
        uint256 index;
        holders = new Vault.RoleHolder[](50);

        // lazyVaultAdmin roles:
        holders[index++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_SECURITY_PARAMS_ROLE, lazyVaultAdmin);

        // activeVaultAdmin roles:
        holders[index++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, activeVaultAdmin);

        // emergency pauser roles:
        if (timelockController != address(0)) {
            holders[index++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, timelockController);
            holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, timelockController);
            holders[index++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, timelockController);
        }

        // oracle submitter roles:
        if (oracleSubmitter != address(0)) {
            holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, oracleSubmitter);
            holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleSubmitter);
        } else {
            holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
            holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleUpdater);
        }

        // curator roles:
        holders[index++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
        holders[index++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
        holders[index++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

        assembly {
            mstore(holders, index)
        }
    }

    /// @dev fill in merkle roots
    function getSubvaultMerkleRoot(uint256 index)
        internal
        override
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {}

    /// @dev test transaction for src/permission_builder/protocols/xReserve.yaml using the proofs in
    ///      scripts/jsons/ethereum:tKRC:subvault0.json: USDC.approve(xReserve) [merkle_proofs[0]]
    ///      followed by IxReserve.depositToRemote [merkle_proofs[1]]. Simulation only — no broadcast.
    function _simulateXReserveDepositToRemote() internal {
        string memory json = vm.readFile("./scripts/jsons/ethereum:tKRC:subvault0.json");

        Subvault subvault = Subvault(payable(vm.parseJsonAddress(json, ".subvault")));
        address caller = vm.parseJsonAddress(json, ".merkle_proofs[0].description.parameters.caller");

        // deposit the subvault's whole USDC balance (value/amount are masked/"any" in the proofs)
        uint256 value = IERC20(Constants.USDC).balanceOf(address(subvault));
        console.log("subvault %s USDC balance used as value: %s", address(subvault), value);

        // 1) allowance call: USDC.approve(xReserve, value) via merkle_proofs[0]
        _subvaultCall(
            subvault,
            caller,
            vm.parseJsonAddress(json, ".merkle_proofs[0].description.parameters.target"),
            _buildApproveData(json, ".merkle_proofs[0]", value),
            _loadPayload(json, ".merkle_proofs[0]"),
            "approve"
        );

        // 2) xReserve.depositToRemote(...) via merkle_proofs[1]
        _subvaultCall(
            subvault,
            caller,
            vm.parseJsonAddress(json, ".merkle_proofs[1].description.parameters.target"),
            _buildDepositToRemoteData(json, ".merkle_proofs[1]", value),
            _loadPayload(json, ".merkle_proofs[1]"),
            "depositToRemote"
        );
    }

    /// @dev verifies the call against the subvault verifier, then simulates it via subvault.call
    function _subvaultCall(
        Subvault subvault,
        address caller,
        address target,
        bytes memory data,
        IVerifier.VerificationPayload memory payload,
        string memory label
    ) internal {
        require(
            subvault.verifier().getVerificationResult(caller, target, 0, data, payload),
            string.concat("xReserve: ", label, " not authorized by proof")
        );
        console.log("xReserve %s authorized | target: %s", label, target);

        // raw calldata for the outer subvault.call(where, value, data, payload) transaction
        console.log("xReserve %s subvault.call raw calldata | to: %s", label, address(subvault));
        console.logBytes(abi.encodeCall(subvault.call, (target, uint256(0), data, payload)));

        // forge simulates without --broadcast
        vm.prank(caller);
        try subvault.call(target, 0, data, payload) returns (bytes memory) {
            console.log("xReserve %s simulated successfully", label);
        } catch (bytes memory reason) {
            console.log("xReserve %s reverted during execution:", label);
            console.logBytes(reason);
        }
    }

    /// @dev builds the USDC approve calldata; spender comes from the proof, amount is masked ("any")
    function _buildApproveData(string memory json, string memory leaf, uint256 amount)
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodeWithSignature(
            "approve(address,uint256)",
            vm.parseJsonAddress(json, string.concat(leaf, ".description.innerParameters.spender")),
            amount
        );
    }

    /// @dev builds the depositToRemote calldata; fixed params come from the proof, `value` and
    ///      maxFee are masked ("any") so the balance / a sample fee are accepted by the verifier
    function _buildDepositToRemoteData(string memory json, string memory leaf, uint256 value)
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodeWithSignature(
            "depositToRemote(uint256,uint32,bytes32,address,uint256,bytes)",
            value,
            uint32(
                vm.parseUint(vm.parseJsonString(json, string.concat(leaf, ".description.innerParameters.remoteDomain")))
            ),
            vm.parseJsonBytes32(json, string.concat(leaf, ".description.innerParameters.remoteRecipient")),
            vm.parseJsonAddress(json, string.concat(leaf, ".description.innerParameters.localToken")),
            0, // maxFee (masked) — sample value
            vm.parseJsonBytes(json, string.concat(leaf, ".description.innerParameters.hookData"))
        );
    }

    /// @dev reconstructs the verification payload (including merkle proof) from the json
    function _loadPayload(string memory json, string memory leaf)
        internal
        pure
        returns (IVerifier.VerificationPayload memory payload)
    {
        payload = IVerifier.VerificationPayload({
            verificationType: IVerifier.VerificationType(
                uint8(vm.parseJsonUint(json, string.concat(leaf, ".verificationType")))
            ),
            verificationData: vm.parseJsonBytes(json, string.concat(leaf, ".verificationData")),
            proof: vm.parseJsonBytes32Array(json, string.concat(leaf, ".proof"))
        });
    }
}
