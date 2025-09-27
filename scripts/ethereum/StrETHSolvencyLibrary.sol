// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../collectors/defi/FEOracle.sol";
import "../collectors/defi/external/IAaveOracleV3.sol";
import "../common/ArraysLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "../common/RandomLib.sol";
import "../common/interfaces/Imports.sol";

import "./Constants.sol";

library StrETHSolvencyLibrary {
    using RandomLib for RandomLib.Storage;

    function _this() private pure returns (Vm) {
        return Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    }

    enum Transitions {
        CREATE_DEPOSIT_REQUEST,
        CANCEL_DEPOSIT_REQUEST,
        CREATE_REDEEM_REQUEST,
        HANDLE_BATCHES,
        ORACLE_REPORT,
        SUPPLY_AAVE,
        BORROW_AAVE,
        CREATE_COWSWAP_ORDER,
        EXECUTE_COWSWAP_ORDER,
        IGNORE_COWSWAP_ORDER,
        HANDLE_REDEEMS
    }

    struct State {
        address[] users;
    }

    function findRoleHolder(VaultDeployment memory d, bytes32 role) internal pure returns (address) {
        for (uint256 i = 0; i < d.initParams.roleHolders.length; i++) {
            if (d.initParams.roleHolders[i].role == role) {
                return d.initParams.roleHolders[i].holder;
            }
        }
        revert("Holder not found");
    }

    function findPayload(
        VaultDeployment memory d,
        uint256 subvaultIndex,
        address where,
        address who,
        uint256 value,
        bytes memory data
    ) internal view returns (IVerifier.VerificationPayload memory p) {
        IVerifier verifier = IVerifier(d.subvaultVerifiers[subvaultIndex]);
        for (uint256 i = 0; i < d.calls[subvaultIndex].payloads.length; i++) {
            p = d.calls[subvaultIndex].payloads[i];
            if (verifier.getVerificationResult(who, where, value, data, p)) {
                return p;
            }
        }
        revert("Valid payload not found");
    }

    function buildCowswapOrderUid(address who, address from, address to, uint256 amount, uint32 deadline)
        internal
        view
        returns (CowSwapLibrary.Data memory order, bytes memory orderUid)
    {
        uint256 buyAmount = from == Constants.WSTETH
            ? WSTETHInterface(Constants.WSTETH).getStETHByWstETH(amount)
            : WSTETHInterface(Constants.WSTETH).getWstETHByStETH(amount);
        order = CowSwapLibrary.Data({
            sellToken: IERC20(from),
            buyToken: IERC20(to),
            receiver: who,
            sellAmount: amount,
            buyAmount: buyAmount,
            validTo: deadline,
            appData: bytes32(0),
            feeAmount: 0,
            kind: CowSwapLibrary.KIND_SELL,
            partiallyFillable: false,
            sellTokenBalance: CowSwapLibrary.BALANCE_ERC20,
            buyTokenBalance: CowSwapLibrary.BALANCE_ERC20
        });
        bytes32 orderDigest =
            CowSwapLibrary.hash(order, ICowswapSettlement(Constants.COWSWAP_SETTLEMENT).domainSeparator());
        orderUid = new bytes(CowSwapLibrary.UID_LENGTH);
        CowSwapLibrary.packOrderUidParams(orderUid, orderDigest, who, deadline);
    }

    function executeCowswapOrder(CowSwapLibrary.Data memory order) internal {
        address solver = 0xC7899Ff6A3aC2FF59261bD960A8C880DF06E1041;
        _this().startPrank(solver); // random cowswap solver

        address[] memory tokens = new address[](2);
        tokens[0] = Constants.WSTETH;
        tokens[1] = Constants.WETH;

        uint256[] memory clearingPrices = new uint256[](2);
        clearingPrices[0] = order.buyAmount;
        clearingPrices[1] = order.sellAmount;
        if (tokens[0] != address(order.sellToken)) {
            (clearingPrices[0], clearingPrices[1]) = (clearingPrices[1], clearingPrices[0]);
        }

        uint256 flags = 3 << 5;
        ICowswapSettlement.TradeData[] memory trades = new ICowswapSettlement.TradeData[](1);
        trades[0] = ICowswapSettlement.TradeData({
            sellTokenIndex: tokens[0] == address(order.sellToken) ? 0 : 1,
            buyTokenIndex: tokens[0] == address(order.buyToken) ? 0 : 1,
            receiver: order.receiver,
            sellAmount: order.sellAmount,
            buyAmount: order.buyAmount,
            validTo: order.validTo,
            appData: order.appData,
            feeAmount: order.feeAmount,
            flags: flags,
            executedAmount: order.buyAmount,
            signature: abi.encodePacked(bytes20(order.receiver))
        });

        ICowswapSettlement.InteractionData[][3] memory interactions = [
            new ICowswapSettlement.InteractionData[](0),
            new ICowswapSettlement.InteractionData[](0),
            new ICowswapSettlement.InteractionData[](0)
        ];

        if (trades[0].buyTokenIndex == 0) {
            _this().deal(solver, order.buyAmount * 2);
            Address.sendValue(payable(Constants.WSTETH), order.buyAmount * 2);
            IERC20(Constants.WSTETH).transfer(Constants.COWSWAP_SETTLEMENT, order.buyAmount);
        } else {
            _this().deal(solver, order.buyAmount);
            Address.sendValue(payable(Constants.WETH), order.buyAmount);
            IERC20(Constants.WETH).transfer(Constants.COWSWAP_SETTLEMENT, order.buyAmount);
        }

        ICowswapSettlement(Constants.COWSWAP_SETTLEMENT).settle(tokens, clearingPrices, trades, interactions);

        _this().stopPrank();
    }

    function swapWETH(
        RandomLib.Storage storage rnd,
        State storage $,
        VaultDeployment memory d,
        uint256 subvaultIndex,
        uint256 maxWeth
    ) internal {
        address curator = findRoleHolder(d, Permissions.CALLER_ROLE);
        _this().startPrank(curator);
        address subvault = d.vault.subvaultAt(subvaultIndex);
        if (subvault.balance > 0) {
            uint256 balance = subvault.balance;
            bytes memory call = abi.encodeCall(WETHInterface.deposit, ());
            Subvault(payable(subvault)).call(
                Constants.WETH, balance, call, findPayload(d, subvaultIndex, Constants.WETH, curator, balance, call)
            );
        }

        uint256 wethBalance = IERC20(Constants.WETH).balanceOf(subvault);
        wethBalance = Math.min(maxWeth, wethBalance);
        if (wethBalance > 0) {
            bytes memory call = abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, wethBalance));
            Subvault(payable(subvault)).call(
                Constants.WETH, 0, call, findPayload(d, subvaultIndex, Constants.WETH, curator, 0, call)
            );

            (CowSwapLibrary.Data memory order, bytes memory orderUid) =
                buildCowswapOrderUid(subvault, Constants.WETH, Constants.WSTETH, wethBalance, type(uint32).max);

            call = abi.encodeCall(ICowswapSettlement.setPreSignature, (orderUid, true));
            Subvault(payable(subvault)).call(
                Constants.COWSWAP_SETTLEMENT,
                0,
                call,
                findPayload(d, subvaultIndex, Constants.COWSWAP_SETTLEMENT, curator, 0, call)
            );

            executeCowswapOrder(order);
        }

        _this().stopPrank();
    }

    function swapWSTETH(
        RandomLib.Storage storage rnd,
        State storage $,
        VaultDeployment memory d,
        uint256 subvaultIndex,
        uint256 maxWstETH
    ) internal {
        address curator = findRoleHolder(d, Permissions.CALLER_ROLE);
        _this().startPrank(curator);
        address subvault = d.vault.subvaultAt(subvaultIndex);

        uint256 wstethBalance = IERC20(Constants.WSTETH).balanceOf(subvault);
        wstethBalance = Math.min(maxWstETH, wstethBalance);
        if (wstethBalance > 0) {
            bytes memory call = abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, wstethBalance));

            Subvault(payable(subvault)).call(
                Constants.WSTETH, 0, call, findPayload(d, subvaultIndex, Constants.WSTETH, curator, 0, call)
            );

            (CowSwapLibrary.Data memory order, bytes memory orderUid) =
                buildCowswapOrderUid(subvault, Constants.WSTETH, Constants.WETH, wstethBalance, type(uint32).max);

            call = abi.encodeCall(ICowswapSettlement.setPreSignature, (orderUid, true));
            Subvault(payable(subvault)).call(
                Constants.COWSWAP_SETTLEMENT,
                0,
                call,
                findPayload(d, subvaultIndex, Constants.COWSWAP_SETTLEMENT, curator, 0, call)
            );

            executeCowswapOrder(order);
        }

        _this().stopPrank();
    }

    function aaveSupply(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d, uint256 maxValue)
        internal
    {
        address subvault1 = d.vault.subvaultAt(1);
        address curator = findRoleHolder(d, Permissions.CALLER_ROLE);

        swapWETH(rnd, $, d, 0, type(uint256).max);
        address subvault0 = d.vault.subvaultAt(0);
        uint256 wstethBalance = IERC20(Constants.WSTETH).balanceOf(subvault0);
        if (wstethBalance != 0) {
            _this().startPrank(curator);
            d.vault.pullAssets(subvault0, Constants.WSTETH, wstethBalance);
            d.vault.pushAssets(subvault1, Constants.WSTETH, wstethBalance);
            _this().stopPrank();
        }

        wstethBalance = IERC20(Constants.WSTETH).balanceOf(subvault1);
        wstethBalance = Math.min(maxValue, wstethBalance);
        if (wstethBalance == 0) {
            return;
        }
        _this().startPrank(curator);
        bytes memory call = abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, wstethBalance));
        Subvault(payable(subvault1)).call(
            Constants.WSTETH, 0, call, findPayload(d, 1, Constants.WSTETH, curator, 0, call)
        );
        call = abi.encodeCall(IAavePoolV3.supply, (Constants.WSTETH, wstethBalance, subvault1, 0));
        Subvault(payable(subvault1)).call(
            Constants.AAVE_PRIME, 0, call, findPayload(d, 1, Constants.AAVE_PRIME, curator, 0, call)
        );
        _this().stopPrank();
    }

    function aaveWithdraw(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d, uint256 maxValue)
        internal
    {
        address subvault = d.vault.subvaultAt(1);
        address curator = findRoleHolder(d, Permissions.CALLER_ROLE);
        (,, uint256 availableBorrowsBase,, uint256 ltv,) =
            IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
        uint256 wstethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WSTETH);

        uint256 withdrawAmount =
            Math.min(maxValue, Math.mulDiv(availableBorrowsBase * 1e4 / ltv, 1 ether, wstethPriceD8));
        bytes memory call = abi.encodeCall(IAavePoolV3.withdraw, (Constants.WSTETH, withdrawAmount, subvault));
        _this().startPrank(curator);
        Subvault(payable(subvault)).call(
            Constants.AAVE_PRIME, 0, call, findPayload(d, 1, Constants.AAVE_PRIME, curator, 0, call)
        );
        _this().stopPrank();
    }

    function aaveRepay(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d, uint256 maxValue)
        internal
    {
        address subvault = d.vault.subvaultAt(1);
        address curator = findRoleHolder(d, Permissions.CALLER_ROLE);

        (, uint256 debt,,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
        uint256 wethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        uint256 wethDebt = debt * 1 ether / wethPriceD8; // round-up ?
        uint256 wethAmount = Math.min(IERC20(Constants.WETH).balanceOf(subvault), wethDebt);
        wethAmount = Math.min(wethAmount, maxValue);

        if (wethAmount == 0) {
            return;
        }

        _this().startPrank(curator);
        bytes memory call = abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, wethAmount));
        Subvault(payable(subvault)).call(Constants.WETH, 0, call, findPayload(d, 1, Constants.WETH, curator, 0, call));

        call = abi.encodeCall(IAavePoolV3.repay, (Constants.WETH, wethAmount, 2, subvault));
        Subvault(payable(subvault)).call(
            Constants.AAVE_PRIME, 0, call, findPayload(d, 1, Constants.AAVE_PRIME, curator, 0, call)
        );
        _this().stopPrank();
    }

    function aaveBorrow(
        RandomLib.Storage storage, /* rnd */
        State storage, /* $ */
        VaultDeployment memory d,
        uint256 maxValue
    ) internal {
        address subvault = d.vault.subvaultAt(1);
        address curator = findRoleHolder(d, Permissions.CALLER_ROLE);

        (,, uint256 availableBorrowsBase,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
        uint256 priceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        uint256 borrowAmount = Math.mulDiv(availableBorrowsBase, 1 ether - 1 gwei, priceD8);

        borrowAmount = Math.min(maxValue, borrowAmount);
        if (borrowAmount == 0) {
            return;
        }
        _this().startPrank(curator);

        bytes memory call;
        if (IAavePoolV3(Constants.AAVE_PRIME).getUserEMode(subvault) == 0) {
            call = abi.encodeCall(IAavePoolV3.setUserEMode, (1));
            Subvault(payable(subvault)).call(
                Constants.AAVE_PRIME, 0, call, findPayload(d, 1, Constants.AAVE_PRIME, curator, 0, call)
            );
        }

        call = abi.encodeCall(IAavePoolV3.borrow, (Constants.WETH, borrowAmount, 2, 0, subvault));
        Subvault(payable(subvault)).call(
            Constants.AAVE_PRIME, 0, call, findPayload(d, 1, Constants.AAVE_PRIME, curator, 0, call)
        );

        _this().stopPrank();
    }

    function aaveIncreaseLeverage(
        RandomLib.Storage storage rnd,
        State storage $,
        VaultDeployment memory d,
        uint256 targetCollateral
    ) internal {
        address subvault = d.vault.subvaultAt(1);
        swapWETH(rnd, $, d, 1, IERC20(Constants.WETH).balanceOf(subvault));
        (uint256 currentCollateral,,,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
        uint256 wstethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WSTETH);
        uint256 wethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        for (uint256 i = 0; i < 20 && currentCollateral < targetCollateral; i++) {
            uint256 supplyAmount = (targetCollateral - currentCollateral) * 1 ether / wstethPriceD8;
            aaveSupply(rnd, $, d, supplyAmount);
            (currentCollateral,,,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
            uint256 borrowAmount = (targetCollateral - currentCollateral) * 1 ether / wethPriceD8;
            aaveBorrow(rnd, $, d, borrowAmount);
            swapWETH(rnd, $, d, 1, type(uint256).max);
        }
    }

    function aaveDecreaseLeverage(
        RandomLib.Storage storage rnd,
        State storage $,
        VaultDeployment memory d,
        uint256 targetCollateral
    ) internal {
        address subvault = d.vault.subvaultAt(1);
        swapWETH(rnd, $, d, 1, IERC20(Constants.WETH).balanceOf(subvault));
        (uint256 currentCollateral,,,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
        uint256 wstethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WSTETH);
        uint256 wethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        for (uint256 i = 0; i < 20 && targetCollateral < currentCollateral; i++) {
            uint256 leftover = currentCollateral - targetCollateral;
            uint256 wstethAmount = leftover * 1 ether / wstethPriceD8;
            aaveWithdraw(rnd, $, d, wstethAmount);

            (currentCollateral,,,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
            leftover = currentCollateral - targetCollateral;
            swapWSTETH(rnd, $, d, 1, type(uint256).max);

            uint256 wethAmount = leftover * 1 ether / wethPriceD8;
            aaveRepay(rnd, $, d, Math.min(wethAmount, IERC20(Constants.WETH).balanceOf(subvault)));
        }
    }

    // Transitions

    function createDepositRequest(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        address asset = rnd.randBool() ? Constants.WSTETH : (rnd.randBool() ? Constants.WETH : Constants.ETH); // 50% - wsteth, 25% - weth, 25% - eth
        address user;
        if ($.users.length == 0 || rnd.randBool()) {
            user = rnd.randAddress();
            $.users.push(user);
        } else {
            user = $.users[rnd.randInt($.users.length - 1)];
        }

        IDepositQueue queue = IDepositQueue(d.vault.queueAt(asset, 0));
        uint256 amount = rnd.randAmountD18();

        _this().startPrank(user);
        if (asset != Constants.ETH) {
            _this().deal(user, amount);
            uint256 balanceBefore = IERC20(asset).balanceOf(user);
            Address.sendValue(payable(asset), amount);
            amount = IERC20(asset).balanceOf(user) - balanceBefore;
            IERC20(asset).approve(address(queue), type(uint256).max);
            (uint256 t,) = queue.requestOf(user);
            if (t != 0 && queue.claimableOf(user) == 0) {
                _this().expectRevert(abi.encodeWithSignature("PendingRequestExists()"));
                queue.deposit(uint224(amount), address(0), new bytes32[](0));
                _this().stopPrank();
                return;
            } else {
                queue.deposit(uint224(amount), address(0), new bytes32[](0));
            }
        } else {
            _this().deal(user, amount);
            (uint256 t,) = queue.requestOf(user);
            if (t != 0 && queue.claimableOf(user) == 0) {
                _this().expectRevert(abi.encodeWithSignature("PendingRequestExists()"));
                queue.deposit{value: amount}(uint224(amount), address(0), new bytes32[](0));
                _this().stopPrank();
                return;
            } else {
                queue.deposit{value: amount}(uint224(amount), address(0), new bytes32[](0));
            }
        }
        _this().stopPrank();
    }

    function createRedeemRequest(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        address[] memory users = new address[]($.users.length);
        IShareManager shareManager = d.vault.shareManager();

        {
            uint256 j = 0;
            for (uint256 i = 0; i < users.length; i++) {
                if (shareManager.sharesOf($.users[i]) == 0) {
                    continue;
                }
                users[j++] = $.users[i];
            }
            assembly {
                mstore(users, j)
            }
        }

        if (users.length == 0) {
            return;
        }
        address user = users[rnd.randInt(users.length - 1)];
        uint256 shares = shareManager.sharesOf(user);

        if (shares == 0) {
            revert("Invalid state (shares=0)");
        }

        if (rnd.randBool()) {
            shares = rnd.randInt(1, shares);
        }

        IRedeemQueue queue = IRedeemQueue(d.vault.queueAt(Constants.WSTETH, 1));

        _this().startPrank(user);
        queue.redeem(shares);
        _this().stopPrank();
    }

    function handleWithdrawals(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        swapWETH(rnd, $, d, 0, type(uint256).max);
        IRedeemQueue(d.vault.queueAt(Constants.WSTETH, 1)).handleBatches(type(uint256).max);
    }

    function submitReports(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        if (rnd.randBool()) {
            _this().warp(block.timestamp + 2 days);
        } else {
            _this().warp(block.timestamp + 1 days);
        }

        OracleHelper oracleHelper = OracleHelper(Constants.protocolDeployment().oracleHelper);
        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](3);
        assetPrices[0].asset = Constants.WSTETH;
        assetPrices[0].priceD18 = WSTETHInterface(Constants.WSTETH).getStETHByWstETH(1 ether);

        assetPrices[1].asset = Constants.WETH;
        assetPrices[1].priceD18 = 1 ether;

        assetPrices[2].asset = Constants.ETH;

        uint256[] memory prices =
            oracleHelper.getPricesD18(d.vault, FEOracle(Constants.FE_ORACLE).tvl(address(d.vault)), assetPrices);

        IOracle.Report[] memory reports = new IOracle.Report[](3);
        for (uint256 i = 0; i < 3; i++) {
            reports[i].asset = assetPrices[i].asset;
            reports[i].priceD18 = uint224(prices[i]);
        }

        IOracle oracle = d.vault.oracle();
        address oracleSubmitter = findRoleHolder(d, oracle.SUBMIT_REPORTS_ROLE());
        _this().startPrank(oracleSubmitter);
        oracle.submitReports(reports);
        _this().stopPrank();
    }

    function aaveIncreaseLeverage(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        uint256 tvl = FEOracle(Constants.FE_ORACLE).tvl(address(d.vault));
        uint256 priceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        uint256 tvlBase = Math.mulDiv(tvl, priceD8, 1 ether);
        uint256 targetCollateral = rnd.randInt(1, tvlBase);
        aaveIncreaseLeverage(rnd, $, d, targetCollateral);
    }

    function aaveDecreaseLeverage(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        uint256 tvl = FEOracle(Constants.FE_ORACLE).tvl(address(d.vault));
        uint256 priceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        uint256 tvlBase = Math.mulDiv(tvl, priceD8, 1 ether);
        uint256 targetCollateral = rnd.randInt(1, tvlBase);
        aaveDecreaseLeverage(rnd, $, d, targetCollateral);
    }

    function finalize(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {}

    // Checks

    function checkState(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {}

    function checkFinalState(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {}
}
