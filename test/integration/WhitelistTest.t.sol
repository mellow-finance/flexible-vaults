// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/common/Permissions.sol";
import "../../scripts/ethereum/Constants.sol";
import "../Imports.sol";
import "forge-std/Test.sol";

contract Integration is Test {
    Vault vault = Vault(payable(0x9e065540891bc246F5EA961b6D91b2dF661913Ba));

    function getOrCreateHolder(string memory roleName, bytes32 role) internal returns (address holder) {
        if (vault.getRoleMemberCount(role) == 0) {
            holder = vm.createWallet(string.concat("role-holder:", roleName)).addr;
            address admin = getOrCreateHolder("", bytes32(0));
            vm.startPrank(admin);
            vault.grantRole(role, holder);
            vm.stopPrank();
        } else {
            holder = vault.getRoleMember(role, 0);
        }
    }

    function getDefaultReports() internal pure returns (IOracle.Report[] memory reports) {
        reports = new IOracle.Report[](3);
        reports[0].asset = Constants.ETH;
        reports[0].priceD18 = 1000000000000000000;
        reports[1].asset = Constants.WETH;
        reports[1].priceD18 = 1000000000000000000;
        reports[2].asset = Constants.WSTETH;
        reports[2].priceD18 = 1223682862755529629;
    }

    function testDepositTransferWhitelist_NO_CI() external {
        IShareManager shareManager = vault.shareManager();
        IOracle oracle = vault.oracle();
        {
            vm.startPrank(getOrCreateHolder("SET_FLAGS_ROLE", Permissions.SET_FLAGS_ROLE));
            shareManager.setFlags(
                IShareManager.Flags({
                    hasMintPause: false,
                    hasBurnPause: false,
                    hasTransferPause: false,
                    hasWhitelist: true,
                    hasTransferWhitelist: true,
                    globalLockup: 0
                })
            );
            vm.stopPrank();
        }

        vm.startPrank(Ownable(address(vault.feeManager())).owner());
        vault.feeManager().setFees(1e5, 1e5, 1e5, 1e5);
        vm.stopPrank();

        address user = vm.createWallet("user-1").addr;
        address nonWhitelistedUser = vm.createWallet("not-whitelisted-recipient").addr;
        address whitelistedUser = vm.createWallet("whitelisted-recipient").addr;

        vm.startPrank(getOrCreateHolder("SET_ACCOUNT_INFO", Permissions.SET_ACCOUNT_INFO_ROLE));
        shareManager.setAccountInfo(
            whitelistedUser, IShareManager.AccountInfo({canDeposit: false, canTransfer: true, isBlacklisted: false})
        );
        vm.stopPrank();

        vm.startPrank(user);

        deal(user, 10 ether);
        IDepositQueue depositQueue = IDepositQueue(vault.queueAt(Constants.ETH, 0));

        vm.expectRevert(abi.encodeWithSelector(IDepositQueue.DepositNotAllowed.selector));
        depositQueue.deposit{value: 10 ether}(10 ether, address(0), new bytes32[](0));
        vm.stopPrank();

        vm.startPrank(getOrCreateHolder("SET_ACCOUNT_INFO", Permissions.SET_ACCOUNT_INFO_ROLE));
        shareManager.setAccountInfo(
            user,
            IShareManager.AccountInfo({
                canDeposit: true,
                canTransfer: false, // for now - without transfer whitelist
                isBlacklisted: false
            })
        );
        vm.stopPrank();

        vm.startPrank(user);
        depositQueue.deposit{value: 10 ether}(10 ether, address(0), new bytes32[](0));
        vm.stopPrank();

        skip(1 hours);

        vm.startPrank(getOrCreateHolder("SUBMIT_REPORTS", Permissions.SUBMIT_REPORTS_ROLE));
        IOracle.Report[] memory reports = getDefaultReports();

        vm.expectRevert(
            abi.encodeWithSelector(IShareManager.NotWhitelisted.selector, vault.feeManager().feeRecipient())
        );

        oracle.submitReports(reports);

        vm.startPrank(getOrCreateHolder("SET_ACCOUNT_INFO", Permissions.SET_ACCOUNT_INFO_ROLE));

        shareManager.setAccountInfo(
            vault.feeManager().feeRecipient(),
            IShareManager.AccountInfo({canDeposit: true, canTransfer: false, isBlacklisted: false})
        );
        vm.stopPrank();

        vm.startPrank(getOrCreateHolder("SUBMIT_REPORTS", Permissions.SUBMIT_REPORTS_ROLE));
        oracle.submitReports(reports);
        vm.stopPrank();

        vm.startPrank(user);
        depositQueue.claim(user);

        {
            uint256 shares = shareManager.sharesOf(user);

            vm.expectRevert(abi.encodeWithSelector(IShareManager.TransferNotAllowed.selector, user, nonWhitelistedUser));
            IERC20(address(shareManager)).transfer(nonWhitelistedUser, shares);

            vm.expectRevert(abi.encodeWithSelector(IShareManager.TransferNotAllowed.selector, user, whitelistedUser));
            IERC20(address(shareManager)).transfer(whitelistedUser, shares);

            vm.stopPrank();
            vm.startPrank(getOrCreateHolder("SET_ACCOUNT_INFO", Permissions.SET_ACCOUNT_INFO_ROLE));

            shareManager.setAccountInfo(
                user, IShareManager.AccountInfo({canDeposit: true, canTransfer: true, isBlacklisted: false})
            );

            vm.stopPrank();
            vm.startPrank(user);

            vm.expectRevert(abi.encodeWithSelector(IShareManager.TransferNotAllowed.selector, user, nonWhitelistedUser));
            IERC20(address(shareManager)).transfer(nonWhitelistedUser, shares);

            // no revert
            IERC20(address(shareManager)).transfer(whitelistedUser, shares / 2);
            vm.stopPrank();
            vm.startPrank(getOrCreateHolder("SET_ACCOUNT_INFO", Permissions.SET_ACCOUNT_INFO_ROLE));
            shareManager.setAccountInfo(
                user, IShareManager.AccountInfo({canDeposit: true, canTransfer: false, isBlacklisted: false})
            );
            vm.stopPrank();
        }

        vm.startPrank(user);
        IRedeemQueue redeemQueue = IRedeemQueue(vault.queueAt(Constants.WSTETH, 1));
        redeemQueue.redeem(shareManager.sharesOf(user));
        vm.stopPrank();

        skip(1 hours);

        vm.startPrank(getOrCreateHolder("SUBMIT_REPORTS", Permissions.SUBMIT_REPORTS_ROLE));
        oracle.submitReports(getDefaultReports());
        vm.stopPrank();

        vm.startPrank(user);
        deal(Constants.WSTETH, address(vault), 10 ether);
        redeemQueue.handleBatches(1);
        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = uint32(block.timestamp - 1 hours);
        redeemQueue.claim(user, timestamps);

        vm.stopPrank();
    }
}
