// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/DeployVaultFactory.sol";
import "../common/DeployVaultFactoryRegistry.sol";
import "../common/OracleSubmitterFactory.sol";

import "./DeployAbstractScript.s.sol";

contract Deploy is DeployAbstractScript {
    function run() external {
        GAS_PER_TRANSACTION = 1.0e7;
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        deployVault = Constants.deployVaultFactory;

        /// @dev just on-chain simulation
        //_simulate();

        /// @dev on-chain transaction
        //  if vault == address(0) -> step one
        //  else -> step two
        /// @dev fill in Vault address to run stepTwo
        vault = Vault(payable(address(0x07AFFA6754458f88db83A72859948d9b794E131b)));
        testMerkle();
        return;

        //revert("ok");

        //_run();
        //revert("ok");
    }
    function testSafe() internal {
        bytes memory data = hex"6a76120200000000000000000000000040a2accbd92bca938b02010e17a5b8929b49130d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005c000000000000000000000000000000000000000000000000000000000000004448d80ff0a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000003f60007affa6754458f88db83a72859948d9b794e131b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000442f2ff15dfc199f685d023b44b528c5fcb9cebfe292e64340dd5729b20761da4ad1e93024000000000000000000000000c6174983e96d508054ce1dbd778be8f9f8007ab300955fbdd0d65d719a2f815ed55401997c863e12b4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000247cb647596c41e41ec87397b8254c42d049fbec95004d4c575e104bd866562864b2af408e0007affa6754458f88db83a72859948d9b794e131b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000442f2ff15d253eb39d0edc77da10bbc4bcaa23c44e40e3c67ed649fbecb18a3f7c51bfbb10000000000000000000000000c6174983e96d508054ce1dbd778be8f9f8007ab30007affa6754458f88db83a72859948d9b794e131b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000442f2ff15d4a899e3e648ea55418d9c99177e5c522df621b1953c0ad7e99da3711043ba1c1000000000000000000000000c6174983e96d508054ce1dbd778be8f9f8007ab3003ab2603982f120f27ee8c40d3299b8446a7bdc88000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c4ca3c9a420000000000000000000000006f05747cdfe61b998f928ce509547cb630a981a100000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000003000000000000000000000000dd468a1ddc392dcdbef6db6e34e89aa338f9f186000000000000000000000000eb5a5d39de4ea42c2aa6a57eca2894376683bb8e00000000000000000000000004671c72aab5ac02a03c1098314b1bb6b560c197003ab2603982f120f27ee8c40d3299b8446a7bdc88000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000449481241a0000000000000000000000006f05747cdfe61b998f928ce509547cb630a981a14000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c3cff07cd798e04aba89b1dce0a69765e5bc39dcb0435f7634a008483741dbf1f569b1aff0f8c25e6517e7112d646c03a538bc4de8ca855499e07c103b9448a3cc1c9e6db7222e0edbae8143f3c4c6bde343ba3a4a69b1b7c6d9b98d85badbb8e7782f5de9811118682ae0a24736a56e1ecf891df0e7271f402195d626c2e0bdf2ba1c01917d0c5fd1c46f37870a3879f01bfde4f8f5f5c4fd2e008065522ac3da301d6b1d03d37c1468f0e0459411d5db9ae650b05ede32b4db7058c722091e6769e11b0000000000000000000000000000000000000000000000000000000000";
        (bool success, ) = address(0xC6174983e96D508054cE1DBD778bE8F9f8007Ab3).call(data);
    }

    function testMerkle() internal {
        bytes32 merkleRoot = 0x6c41e41ec87397b8254c42d049fbec95004d4c575e104bd866562864b2af408e;
        Subvault subvault = Subvault(payable(vault.subvaultAt(0)));

        vm.startPrank(lazyVaultAdmin);
        subvault.verifier().setMerkleRoot(merkleRoot);
        vm.stopPrank();
        assertEq(subvault.verifier().merkleRoot(), merkleRoot, "merkle root mismatch");

        bytes memory approveCalldata = abi.encodeCall(IERC20.approve, (Constants.MEZO_ROUTER, 1 ether));
        IVerifier.VerificationPayload memory approvePayload;
        approvePayload.verificationData = hex"0000000000000000000000000000000819ba998e0dfe0dafdd6b23dbf103314d0d81072987fa60fa684610f8ee416a9ce2bedbd9bed9d4e79751e2c4b9ec4087000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        approvePayload.verificationType = IVerifier.VerificationType.CUSTOM_VERIFIER;
        approvePayload.proof = new bytes32[](4);
        approvePayload.proof[0] = 0xa6d042cca5cd47c658e5cf9e731bb76a4df74b6e730ea886ebcbb8f9639da3f5;
        approvePayload.proof[1] = 0xad8afa297794a5960b8135fcda9a75698712e5084b06801da3ce1c5737627310;
        approvePayload.proof[2] = 0x5db9a87494230e8659672a4de669b0932659776cc748429ed207d881dec8c111;
        approvePayload.proof[3] = 0x1c8685e54b7cd516573fe7a26acbe4cb050c47b373c88ae38d938d47f371a0f0;

        assertTrue(
            subvault.verifier().getVerificationResult(
                curator, Constants.MUSD, 0, approveCalldata, approvePayload
            ),
            "approve proof should be valid"
        );

        vm.startPrank(curator);
        subvault.call(Constants.MUSD, 0, approveCalldata, approvePayload);
        vm.stopPrank();
    }

    function setUp() public override {
        isEmptyVault = true;
        deployOracleSubmitter = false;
        /// @dev fill name and symbol
        vaultName = "Mezo Stable Vault";
        vaultSymbol = "msvUSD";

        /// @dev fill admin/operational addresses
        proxyAdmin = 0x76e5E9922DEF8A9DD7375856FCFE726904496C9C;
        lazyVaultAdmin = 0xC6174983e96D508054cE1DBD778bE8F9f8007Ab3;
        activeVaultAdmin = 0x3E04a2dB757788705144633c648d298a33Bc224E;
        oracleUpdater = 0x06E549DD8b63e2b6fA7b1C37E642FAd3AAF56d40;
        curator = 0x87D7b7E30f6335B23B545d70818Aa7efdf0faD4F;
        pauser = 0xc5143d6AD653e2401D9B4384660B98453Adb051f;

        feeManagerOwner = 0x76e5E9922DEF8A9DD7375856FCFE726904496C9C;

        timelockProposers = new address[](1);
        timelockProposers[0] = lazyVaultAdmin;
        timelockExecutors = new address[](2);
        timelockExecutors[0] = lazyVaultAdmin;
        timelockExecutors[1] = pauser;

        /// @dev fill fee parameters
        depositFeeD6 = 0;
        redeemFeeD6 = 0;
        performanceFeeD6 = 0;
        protocolFeeD6 = 0;

        /// @dev fill security params
        securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 1,
            suspiciousAbsoluteDeviation: 1,
            maxRelativeDeviationD18: 1,
            suspiciousRelativeDeviationD18: 1,
            timeout: 365 days, // no timeout
            depositInterval: 365 days, // does not affect sync deposit queue
            redeemInterval: 365 days // no redemptions allowed
        });

        ProtocolDeployment memory $ = Constants.protocolDeployment();

        /// @dev fill default hooks
        defaultDepositHook = address(0);
        defaultRedeemHook = address(0);

        /// @dev fill share manager params
        shareManagerWhitelistMerkleRoot = bytes32(0);

        /// @dev fill risk manager params
        riskManagerLimit = type(int256).max;

        /// @dev fill versions
        vaultVersion = 0;
        shareManagerVersion = 0; // TokenizedShareManager
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

        {
            subvaultParams[0].assets =
                ArraysLibrary.makeAddressArray(abi.encode(Constants.MUSD, Constants.mUSDC, Constants.mUSDT));
            subvaultParams[0].version = uint256(SubvaultVersion.DEFAULT);
            subvaultParams[0].verifierVersion = 0;
            subvaultParams[0].limit = type(int256).max;
        }
    }

    /// @dev fill in queue parameters
    function getQueues()
        internal
        pure
        override
        returns (IDeployVaultFactory.QueueParams[] memory queues, uint256 queueLimit)
    {}

    /// @dev fill in allowed assets/base asset and subvault assets
    function getAssetsWithPrices()
        internal
        pure
        override
        returns (address[] memory allowedAssets, uint224[] memory allowedAssetsPrices)
    {
        allowedAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.MUSD, Constants.mUSDC, Constants.mUSDT));
        allowedAssetsPrices = new uint224[](allowedAssets.length);
        allowedAssetsPrices[0] = 1e18; // MUSD price
        allowedAssetsPrices[1] = 1e24; // mUSDC price
        allowedAssetsPrices[2] = 1e24; // mUSDT price
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
        holders[index++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, lazyVaultAdmin);

        // activeVaultAdmin roles:

        // emergency pauser roles:
        if (timelockController != address(0)) {
            holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, timelockController);
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
}
