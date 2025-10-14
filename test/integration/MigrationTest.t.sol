// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/common/ArraysLibrary.sol";
import "../../scripts/ethereum/Constants.sol";
import "../Imports.sol";

interface IMV {
    function rebalanceStrategy() external view returns (IMultiVaultStrategy);

    struct SubvaultData {
        uint256 protocol;
        address vault;
        address withdrawalQueue;
    }

    function defaultCollateral() external view returns (IERC20);

    function subvaultsCount() external view returns (uint256);

    function subvaultAt(uint256 index) external view returns (SubvaultData memory);

    function rebalance() external;
}

interface IMultiVaultStrategy {
    struct Ratio {
        uint64 minRatioD18;
        uint64 maxRatioD18;
    }

    function setRatios(address vault, address[] calldata subvaults, Ratio[] calldata ratios) external;
}

contract Integration is Test {
    struct State {
        uint256 totalSupply;
        uint256 totalAssets;
        uint256[] balances;
        string name;
        string symbol;
    }

    address public immutable curator = 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433;
    address public immutable owner = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public immutable vaultAdmin = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;
    address public immutable vault = 0x7a4EffD87C2f3C55CA251080b1343b605f327E3a;
    address public immutable collateral = 0xC329400492c6ff2438472D4651Ad17389fCb843a;
    ProxyAdmin public immutable proxyAdmin = ProxyAdmin(0x17AC6A90eD880F9cE54bB63DAb071F2BD3FE3772);

    function getParameters(address migrator) public view returns (Migrator.Params memory parameters) {
        address[] memory assets = new address[](3);
        assets[0] = Constants.ETH;
        assets[1] = Constants.WETH;
        assets[2] = Constants.WSTETH;

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](2);

        holders[0].holder = migrator;
        holders[0].role = Migrator(migrator).CREATE_QUEUE_ROLE();

        holders[1].holder = migrator;
        holders[1].role = Migrator(migrator).CREATE_SUBVAULT_ROLE();

        parameters = Migrator.Params({
            proxyAdmin: proxyAdmin,
            proxyAdminOwner: owner,
            vaultAdmin: vaultAdmin,
            feeManagerParams: abi.encode(vaultAdmin, vaultAdmin, uint24(0), uint24(0), uint24(1e5), uint24(1e4)),
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005 ether,
                    suspiciousAbsoluteDeviation: 0.001 ether,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 20 hours,
                    depositInterval: 1 hours,
                    redeemInterval: 2 days
                }),
                assets
            ),
            depositQueueAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH)),
            redeemQueueAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
            roleHolders: holders
        });
    }

    function getUsers() public pure returns (address[] memory) {
        return ArraysLibrary.makeAddressArray(
            abi.encode(
                0xCA482BA6ab136aF54a431C43A6815dFec7d884c6,
                0xC77a25E041B8A97847fE6AA71e373893a05c1bfD,
                0x10ceB903940C9bd67b0841A4f67Eb96261A6DA65,
                0x7C990b43565134C7858300073063Fd8806FE0855,
                0x5AF4D7ee85e847Bc7CEC643CcDdc0123F2E3f4c8,
                0xf690957C1B259abc27d21ea9fb48d8E191F9BEb7,
                0xF047ab4c75cebf0eB9ed34Ae2c186f3611aEAfa6,
                0xc8C4D16C5C088Cac946FaFcD5D354812B90F0a27,
                0xbA1333333333a1BA1108E8412f11850A5C319bA9,
                0x278108b227fc6890361BBD91c7416c51Fb756ab2,
                0xcAD586c43f174d0B04D79873ECa93B1Fb998EEf9,
                0x4a4c53905f01cc2D3E789bb13820A68fEE7584b6,
                0xC2381C4B0B40d25B3bd40403FBc9B2951368DC77
            )
        );
    }

    function getStateBefore() public view returns (State memory $) {
        $.totalSupply = IERC4626(vault).totalSupply();
        $.totalAssets = IERC4626(vault).totalAssets();
        address[] memory users = getUsers();
        $.balances = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            $.balances[i] = IERC20(vault).balanceOf(users[i]);
        }
        $.name = IERC20Metadata(vault).name();
        $.symbol = IERC20Metadata(vault).symbol();
    }

    function getStateAfter() public view returns (State memory $) {
        address coreVault = IShareManager(vault).vault();
        $.totalSupply = IShareManager(vault).totalShares();
        $.totalAssets = IERC20(collateral).balanceOf(coreVault) + IERC20(Constants.WSTETH).balanceOf(coreVault);
        address[] memory users = getUsers();
        $.balances = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            $.balances[i] = IERC20(vault).balanceOf(users[i]);
        }
        $.name = IERC20Metadata(vault).name();
        $.symbol = IERC20Metadata(vault).symbol();
    }

    function testMainnetMigration_NO_CI() external {
        Migrator migrator = new Migrator(owner);

        Migrator.Params memory parameters = getParameters(address(migrator));

        vm.expectRevert();
        migrator.migrate(vault, parameters);

        vm.startPrank(owner);
        vm.expectRevert("Migrator: invalid owner");
        migrator.migrate(vault, parameters);

        proxyAdmin.transferOwnership(address(migrator));

        vm.startPrank(owner);
        vm.expectRevert("Migrator: invalid state of MultiVault");
        migrator.migrate(vault, parameters);

        vm.stopPrank();

        // for testing
        vm.prank(address(migrator));
        proxyAdmin.transferOwnership(owner);

        // 1. withdraw liquidity from all symbiotic subvaults

        vm.startPrank(curator);
        IMultiVaultStrategy strategy = IMV(vault).rebalanceStrategy();
        {
            uint256 n = IMV(vault).subvaultsCount();
            address[] memory subvaults = new address[](n);
            for (uint256 i = 0; i < subvaults.length; i++) {
                subvaults[i] = IMV(vault).subvaultAt(i).vault;
            }
            strategy.setRatios(vault, subvaults, new IMultiVaultStrategy.Ratio[](2));
            IMV(vault).rebalance();
            skip(2 weeks);
            IMV(vault).rebalance();
        }
        vm.stopPrank();

        // 2. transfer ProxyAdmin ownership to migrator contract
        vm.startPrank(owner);
        proxyAdmin.transferOwnership(address(migrator));

        State memory stateBefore = getStateBefore();

        // 3. call migration
        migrator.migrate(vault, parameters);
        vm.stopPrank();

        State memory stateAfter = getStateAfter();
        assertEq(
            keccak256(abi.encode(stateBefore)), keccak256(abi.encode(stateAfter)), "MigrationTest: states are different"
        );
    }
}
