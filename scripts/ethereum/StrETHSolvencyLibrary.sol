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

    uint256 public constant MAX_ERROR = 100 wei;

    function _this() private pure returns (Vm) {
        return Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    }

    enum Transitions {
        NONE,
        CREATE_DEPOSIT_REQUEST,
        CANCEL_DEPOSIT_REQUEST,
        CREATE_REDEEM_REQUEST,
        HANDLE_BATCHES,
        ORACLE_REPORTS,
        INCREASE_LEVERAGE,
        DECREASE_LEVERAGE,
        FINALIZE
    }

    struct Transition {
        Transitions t;
        bytes data;
    }

    struct State {
        uint256 timestamp;
        uint256 totalShares;
        uint256 totalAssets;
        address[] users;
        uint256[] shares;
        uint256[] pendingDeposits;
        uint256[] pendingWithdrawals;
        Transition latestTransition;
        uint256 iterator;
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
        uint256 wethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        uint256 wstethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WSTETH);
        uint256 buyAmount = from == Constants.WSTETH
            ? Math.mulDiv(amount, wstethPriceD8, wethPriceD8)
            : Math.mulDiv(amount, wethPriceD8, wstethPriceD8);
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

    function tvl(Vault vault) internal view returns (uint256) {
        return FEOracle(Constants.FE_ORACLE).tvl(address(vault));
    }

    function increaseStETHPrice(uint256 timespan) internal {
        _this().warp(block.timestamp + timespan);
        bytes32 slot = 0xa66d35f054e68143c18f32c990ed5cb972bb68a68f500cd2dd3a16bbf3686483;
        address steth = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        uint256 value = uint256(_this().load(steth, slot));
        uint256 yield = (IERC20(steth).totalSupply() * 27 * timespan) / (1000 * 365 days); // 2.7% apr
        _this().store(steth, slot, bytes32(value + yield));
    }

    function hasPendingDeposit(IOracle oracle, address queue, address user) internal view returns (bool) {
        (uint256 t,) = IDepositQueue(queue).requestOf(user);
        if (t == 0) {
            return false;
        }
        uint256 reportTimestamp = oracle.getReport(IQueue(queue).asset()).timestamp;
        uint256 depositInterval = oracle.securityParams().depositInterval;
        if (t + depositInterval <= reportTimestamp) {
            return false;
        }
        return true;
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

    function swapWETH(State storage $, VaultDeployment memory d, uint256 subvaultIndex, uint256 maxWeth) internal {
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

            uint32 deadline = type(uint32).max - uint32($.iterator++);
            (CowSwapLibrary.Data memory order, bytes memory orderUid) =
                buildCowswapOrderUid(subvault, Constants.WETH, Constants.WSTETH, wethBalance, deadline);

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

    function swapWSTETH(State storage $, VaultDeployment memory d, uint256 subvaultIndex, uint256 maxWstETH) internal {
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

            uint32 deadline = type(uint32).max - uint32($.iterator++);
            (CowSwapLibrary.Data memory order, bytes memory orderUid) =
                buildCowswapOrderUid(subvault, Constants.WSTETH, Constants.WETH, wstethBalance, deadline);

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

    function aaveSupply(State storage $, VaultDeployment memory d, uint256 maxValue) internal {
        address subvault1 = d.vault.subvaultAt(1);
        address curator = findRoleHolder(d, Permissions.CALLER_ROLE);

        swapWETH($, d, 0, type(uint256).max);
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

    function aaveWithdraw(VaultDeployment memory d, uint256 maxValue) internal {
        address subvault = d.vault.subvaultAt(1);
        address curator = findRoleHolder(d, Permissions.CALLER_ROLE);
        (,, uint256 availableBorrowsBase,, uint256 ltv,) =
            IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
        uint256 wstethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WSTETH);

        uint256 withdrawAmount =
            Math.min(maxValue, Math.mulDiv(availableBorrowsBase * 1e4 / ltv, 1 ether, wstethPriceD8));
        if (withdrawAmount == 0) {
            return;
        }
        bytes memory call = abi.encodeCall(IAavePoolV3.withdraw, (Constants.WSTETH, withdrawAmount, subvault));
        _this().startPrank(curator);
        Subvault(payable(subvault)).call(
            Constants.AAVE_PRIME, 0, call, findPayload(d, 1, Constants.AAVE_PRIME, curator, 0, call)
        );
        _this().stopPrank();
    }

    function aaveRepay(VaultDeployment memory d, uint256 maxValue) internal {
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

    function aaveBorrow(VaultDeployment memory d, uint256 maxValue) internal {
        address subvault = d.vault.subvaultAt(1);
        address curator = findRoleHolder(d, Permissions.CALLER_ROLE);

        (,, uint256 availableBorrowsBase,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
        uint256 priceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        uint256 borrowAmount = Math.mulDiv(availableBorrowsBase, 0.999 ether, priceD8);

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

    function aaveIncreaseLeverage(State storage $, VaultDeployment memory d, uint256 targetCollateral) internal {
        address subvault = d.vault.subvaultAt(1);
        swapWETH($, d, 1, IERC20(Constants.WETH).balanceOf(subvault));
        (uint256 currentCollateral,,,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
        uint256 wstethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WSTETH);
        uint256 wethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        for (uint256 i = 0; i < 20 && currentCollateral < targetCollateral; i++) {
            uint256 supplyAmount = (targetCollateral - currentCollateral) * 1 ether / wstethPriceD8;
            aaveSupply($, d, supplyAmount);
            (currentCollateral,,,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
            uint256 borrowAmount = (targetCollateral - currentCollateral) * 1 ether / wethPriceD8;
            aaveBorrow(d, borrowAmount);
            swapWETH($, d, 1, type(uint256).max);
        }
    }

    function aaveDecreaseLeverage(State storage $, VaultDeployment memory d, uint256 targetCollateral) internal {
        address subvault = d.vault.subvaultAt(1);
        swapWETH($, d, 1, IERC20(Constants.WETH).balanceOf(subvault));
        (uint256 currentCollateral,,,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
        uint256 wstethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WSTETH);
        uint256 wethPriceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        for (uint256 i = 0; i < 20 && targetCollateral < currentCollateral; i++) {
            uint256 wstethAmount = (currentCollateral - targetCollateral) * 1 ether / wstethPriceD8;
            aaveWithdraw(d, wstethAmount);
            (currentCollateral,,,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(subvault);
            swapWSTETH($, d, 1, type(uint256).max);
            uint256 wethAmount = (currentCollateral - targetCollateral) * 1 ether / wethPriceD8;
            aaveRepay(d, Math.min(wethAmount, IERC20(Constants.WETH).balanceOf(subvault)));
        }
    }

    function getDepositQueues(VaultDeployment memory d) internal view returns (address[] memory queues) {
        queues = new address[](3);
        queues[0] = d.vault.queueAt(Constants.ETH, 0);
        queues[1] = d.vault.queueAt(Constants.WETH, 0);
        queues[2] = d.vault.queueAt(Constants.WSTETH, 0);
    }

    function pendingDepositsOf(VaultDeployment memory d, address user) internal view returns (uint256 value) {
        address[] memory queues = getDepositQueues(d);
        for (uint256 i = 0; i < 3; i++) {
            if (IDepositQueue(queues[i]).claimableOf(user) > 0) {
                continue;
            }
            (, uint256 assets) = IDepositQueue(queues[i]).requestOf(user);
            if (IQueue(queues[i]).asset() == Constants.WSTETH) {
                value += WSTETHInterface(Constants.WSTETH).getStETHByWstETH(assets);
            } else {
                value += assets;
            }
        }
    }

    function pendingWithdrawalsOf(VaultDeployment memory d, address user) internal view returns (uint256 value) {
        IRedeemQueue queue = IRedeemQueue(d.vault.queueAt(Constants.WSTETH, 1));
        uint256 report = d.vault.oracle().getReport(Constants.WSTETH).priceD18;
        IRedeemQueue.Request[] memory requests = queue.requestsOf(user, 0, type(uint256).max);
        for (uint256 j = 0; j < requests.length; j++) {
            if (requests[j].isClaimable) {
                continue;
            }
            if (requests[j].assets == 0) {
                value += Math.mulDiv(requests[j].shares, 1 ether, report);
            } else {
                value += requests[j].assets;
            }
        }
    }

    function saveSnapshot(State storage $, VaultDeployment memory d) internal {
        IShareManager shareManager = d.vault.shareManager();
        $.timestamp = block.timestamp;
        $.totalShares = shareManager.totalShares();
        $.totalAssets = FEOracle(Constants.FE_ORACLE).tvl(address(d.vault));
        for (uint256 i = 0; i < $.users.length; i++) {
            address user = $.users[i];
            $.shares[i] = shareManager.sharesOf(user);
            $.pendingDeposits[i] = pendingDepositsOf(d, user);
            $.pendingWithdrawals[i] = pendingWithdrawalsOf(d, user);
        }
    }

    // Transitions

    function createDepositRequest(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        address asset = rnd.randBool() ? Constants.WSTETH : (rnd.randBool() ? Constants.WETH : Constants.ETH); // 50% - wsteth, 25% - weth, 25% - eth
        address user;
        if ($.users.length == 0 || rnd.randBool()) {
            user = rnd.randAddress();
            $.users.push(user);
            $.shares.push(0);
            $.pendingDeposits.push(0);
            $.pendingWithdrawals.push(0);
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
        $.latestTransition = Transition(Transitions.CREATE_DEPOSIT_REQUEST, abi.encode(user, asset, amount));
    }

    function cancelDepositRequest(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        address[] memory users = new address[]($.users.length);
        uint256 iterator = 0;
        address[] memory queues = getDepositQueues(d);
        IOracle oracle = d.vault.oracle();
        for (uint256 i = 0; i < users.length; i++) {
            address user_ = $.users[i];
            for (uint256 j = 0; j < 3; j++) {
                if (hasPendingDeposit(oracle, queues[j], user_)) {
                    users[iterator++] = user_;
                    break;
                }
            }
        }
        if (iterator == 0) {
            return;
        }
        assembly {
            mstore(users, iterator)
        }
        address user = users[iterator - 1];
        uint256 cnt = 0;
        for (uint256 i = 0; i < 3; i++) {
            if (hasPendingDeposit(oracle, queues[i], user)) {
                cnt++;
            }
        }

        address queue;
        uint256 index = rnd.randInt(cnt - 1);
        for (uint256 i = 0; i < 3; i++) {
            if (hasPendingDeposit(oracle, queues[i], user)) {
                if (index == 0) {
                    queue = queues[i];
                    break;
                }
                index--;
            }
        }

        (, uint256 amount) = IDepositQueue(queue).requestOf(user);

        _this().startPrank(user);
        IDepositQueue(queue).cancelDepositRequest();
        _this().stopPrank();

        $.latestTransition =
            Transition(Transitions.CANCEL_DEPOSIT_REQUEST, abi.encode(user, IQueue(queue).asset(), amount));
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

        $.latestTransition =
            Transition(Transitions.CREATE_REDEEM_REQUEST, abi.encode(user, IQueue(queue).asset(), shares));
    }

    function handleWithdrawals(State storage $, VaultDeployment memory d) internal {
        IRedeemQueue queue = IRedeemQueue(d.vault.queueAt(Constants.WSTETH, 1));

        (,, uint256 totalDemandAssets,) = queue.getState();

        uint256 fromTimestamp = 0;
        uint256 toTimestamp = 0;
        for (uint256 i = 0; i < $.users.length; i++) {
            IRedeemQueue.Request[] memory rs = queue.requestsOf($.users[i], 0, type(uint256).max);
            for (uint256 j = 0; j < rs.length; j++) {
                if (rs[j].isClaimable) {
                    fromTimestamp = Math.max(fromTimestamp, rs[j].timestamp);
                }
            }
        }

        (uint256 targetCollateral,,,,,) = IAavePoolV3(Constants.AAVE_PRIME).getUserAccountData(d.vault.subvaultAt(1));

        aaveDecreaseLeverage($, d, 0);

        swapWETH($, d, 0, type(uint256).max);
        swapWETH($, d, 1, type(uint256).max);

        queue.handleBatches(type(uint256).max);

        uint256 tvlWsteth = WSTETHInterface(Constants.WSTETH).getWstETHByStETH(tvl(d.vault));
        aaveIncreaseLeverage(
            $, d, Math.mulDiv(targetCollateral, tvlWsteth - Math.min(totalDemandAssets, tvlWsteth), tvlWsteth)
        );

        for (uint256 i = 0; i < $.users.length; i++) {
            IRedeemQueue.Request[] memory rs = queue.requestsOf($.users[i], 0, type(uint256).max);
            for (uint256 j = 0; j < rs.length; j++) {
                if (rs[j].isClaimable) {
                    toTimestamp = Math.max(toTimestamp, rs[j].timestamp);
                }
            }
        }

        $.latestTransition =
            Transition(Transitions.HANDLE_BATCHES, abi.encode(fromTimestamp, toTimestamp, totalDemandAssets));
    }

    function submitReports(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        uint256 timespan = rnd.randInt(1 days, 3 days);
        increaseStETHPrice(timespan);

        OracleHelper oracleHelper = OracleHelper(Constants.protocolDeployment().oracleHelper);
        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](3);
        assetPrices[0].asset = Constants.WSTETH;
        assetPrices[0].priceD18 = WSTETHInterface(Constants.WSTETH).getStETHByWstETH(1 ether);

        assetPrices[1].asset = Constants.WETH;
        assetPrices[1].priceD18 = 1 ether;

        assetPrices[2].asset = Constants.ETH;

        uint256 tvl_ = FEOracle(Constants.FE_ORACLE).tvl(address(d.vault));
        uint256[] memory prices = oracleHelper.getPricesD18(d.vault, tvl_, assetPrices);

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

        saveSnapshot($, d);
        handleWithdrawals($, d);
    }

    function aaveIncreaseLeverage(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        uint256 tvl_ = tvl(d.vault);
        uint256 priceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        uint256 tvlBase = Math.mulDiv(tvl_, priceD8, 1 ether);
        uint256 targetCollateral = rnd.randInt(1, tvlBase * 2);
        aaveIncreaseLeverage($, d, targetCollateral);

        $.latestTransition.t = Transitions.INCREASE_LEVERAGE;
    }

    function aaveDecreaseLeverage(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        uint256 tvl_ = FEOracle(Constants.FE_ORACLE).tvl(address(d.vault));
        uint256 priceD8 = IAaveOracleV3(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        uint256 tvlBase = Math.mulDiv(tvl_, priceD8, 1 ether);
        uint256 targetCollateral = rnd.randInt(1, tvlBase * 2);
        aaveDecreaseLeverage($, d, targetCollateral);

        $.latestTransition.t = Transitions.DECREASE_LEVERAGE;
    }

    function finalize(RandomLib.Storage storage rnd, State storage $, VaultDeployment memory d) internal {
        IShareManager shareManager = d.vault.shareManager();
        IRedeemQueue queue = IRedeemQueue(d.vault.queueAt(Constants.WSTETH, 1));

        // handle pending deposit requests
        submitReports(rnd, $, d);

        for (uint256 i = 0; i < $.users.length; i++) {
            uint256 shares = shareManager.sharesOf($.users[i]);
            if (shares == 0) {
                continue;
            }
            _this().startPrank($.users[i]);
            queue.redeem(shares);
            _this().stopPrank();
        }

        aaveDecreaseLeverage($, d, 0);
        swapWETH($, d, 0, type(uint256).max);
        swapWETH($, d, 1, type(uint256).max);

        _this().warp(block.timestamp + 2 days);

        submitReports(rnd, $, d);
        handleWithdrawals($, d);

        require(queue.canBeRemoved(), "Non-zereo shares");

        for (uint256 i = 0; i < $.users.length; i++) {
            IRedeemQueue.Request[] memory requests = queue.requestsOf($.users[i], 0, type(uint256).max);
            if (requests.length == 0) {
                continue;
            }
            uint32[] memory timestamps = new uint32[](requests.length);
            for (uint256 j = 0; j < timestamps.length; j++) {
                timestamps[j] = uint32(requests[j].timestamp);
            }
            _this().startPrank($.users[i]);
            queue.claim($.users[i], timestamps);
            _this().stopPrank();
        }

        $.latestTransition.t = Transitions.FINALIZE;
    }

    // Checks

    function checkState(State storage $, VaultDeployment memory d) internal {
        Transition memory t = $.latestTransition;

        if (t.t == Transitions.CREATE_DEPOSIT_REQUEST) {
            (address depositor, address asset, uint256 amount) = abi.decode(t.data, (address, address, uint256));
            uint256 ethAmount = asset == Constants.WSTETH ? WSTETHInterface(asset).getStETHByWstETH(amount) : amount;
            IShareManager shareManager = d.vault.shareManager();
            require($.timestamp == block.timestamp, "Invalid timestamp");
            require($.totalShares == shareManager.totalShares(), "Invalid totalShares");
            require($.totalAssets == FEOracle(Constants.FE_ORACLE).tvl(address(d.vault)), "Invalid totalAssets");
            for (uint256 i = 0; i < $.users.length; i++) {
                address user = $.users[i];
                if (user == depositor) {
                    require($.shares[i] == shareManager.sharesOf(user), "Invalid sharesOf");
                    require($.pendingDeposits[i] + ethAmount == pendingDepositsOf(d, user), "Invalid pendingDepositsOf");
                    require($.pendingWithdrawals[i] == pendingWithdrawalsOf(d, user), "Invalid pendingWithdrawalsOf");
                } else {
                    require($.shares[i] == shareManager.sharesOf(user), "Invalid sharesOf");
                    require($.pendingDeposits[i] == pendingDepositsOf(d, user), "Invalid pendingDepositsOf");
                    require($.pendingWithdrawals[i] == pendingWithdrawalsOf(d, user), "Invalid pendingWithdrawalsOf");
                }
            }
        } else if (t.t == Transitions.CANCEL_DEPOSIT_REQUEST) {
            (address depositor, address asset, uint256 amount) = abi.decode(t.data, (address, address, uint256));
            uint256 ethAmount = asset == Constants.WSTETH ? WSTETHInterface(asset).getStETHByWstETH(amount) : amount;
            IShareManager shareManager = d.vault.shareManager();
            require($.timestamp == block.timestamp, "Invalid timestamp");
            require($.totalShares == shareManager.totalShares(), "Invalid totalShares");
            require($.totalAssets == FEOracle(Constants.FE_ORACLE).tvl(address(d.vault)), "Invalid totalAssets");
            for (uint256 i = 0; i < $.users.length; i++) {
                address user = $.users[i];
                if (user == depositor) {
                    require($.shares[i] == shareManager.sharesOf(user), "Invalid sharesOf");
                    require($.pendingDeposits[i] - ethAmount == pendingDepositsOf(d, user), "Invalid pendingDepositsOf");
                    require($.pendingWithdrawals[i] == pendingWithdrawalsOf(d, user), "Invalid pendingWithdrawalsOf");
                } else {
                    require($.shares[i] == shareManager.sharesOf(user), "Invalid sharesOf");
                    require($.pendingDeposits[i] == pendingDepositsOf(d, user), "Invalid pendingDepositsOf");
                    require($.pendingWithdrawals[i] == pendingWithdrawalsOf(d, user), "Invalid pendingWithdrawalsOf");
                }
            }
        } else if (t.t == Transitions.CREATE_REDEEM_REQUEST) {
            (address withdrawer,, uint256 shares) = abi.decode(t.data, (address, address, uint256));
            uint256 ethAmount = Math.mulDiv(shares, 1 ether, d.vault.oracle().getReport(Constants.WSTETH).priceD18);
            IShareManager shareManager = d.vault.shareManager();
            require($.timestamp == block.timestamp, "Invalid timestamp");
            require($.totalShares == shareManager.totalShares(), "Invalid totalShares");
            require($.totalAssets == FEOracle(Constants.FE_ORACLE).tvl(address(d.vault)), "Invalid totalAssets");
            for (uint256 i = 0; i < $.users.length; i++) {
                address user = $.users[i];
                if (user == withdrawer) {
                    require($.shares[i] - shares == shareManager.sharesOf(user), "Invalid sharesOf");
                    require($.pendingDeposits[i] == pendingDepositsOf(d, user), "Invalid pendingDepositsOf");
                    uint256 delta = pendingWithdrawalsOf(d, user) - $.pendingWithdrawals[i] - ethAmount;
                    require(delta <= MAX_ERROR, "Invalid pendingWithdrawalsOf");
                } else {
                    require($.shares[i] == shareManager.sharesOf(user), "Invalid sharesOf");
                    require($.pendingDeposits[i] == pendingDepositsOf(d, user), "Invalid pendingDepositsOf");
                    require($.pendingWithdrawals[i] == pendingWithdrawalsOf(d, user), "Invalid pendingWithdrawalsOf");
                }
            }
        } else if (t.t == Transitions.HANDLE_BATCHES) {
            (uint256 fromTimestamp, uint256 toTimestamp, uint256 assets) =
                abi.decode(t.data, (uint256, uint256, uint256));

            IRedeemQueue queue = IRedeemQueue(d.vault.queueAt(Constants.WSTETH, 1));
            uint256 sum = 0;
            uint256 counter = 0;
            for (uint256 i = 0; i < $.users.length; i++) {
                address user = $.users[i];
                IRedeemQueue.Request[] memory requests = queue.requestsOf(user, 0, type(uint256).max);
                for (uint256 j = 0; j < requests.length; j++) {
                    if (fromTimestamp < requests[j].timestamp && requests[j].timestamp <= toTimestamp) {
                        if (requests[j].assets == 0) {
                            revert("Unexpected pending withdrawal request");
                        }
                        counter++;
                        sum += requests[j].assets;
                    }
                }
            }
            require(assets - sum <= MAX_ERROR, "Error overflow (handle batches)");
        } else if (t.t == Transitions.INCREASE_LEVERAGE || t.t == Transitions.DECREASE_LEVERAGE) {
            IShareManager shareManager = d.vault.shareManager();
            require($.timestamp == block.timestamp, "Invalid timestamp");
            require($.totalShares == shareManager.totalShares(), "Invalid totalShares");
            int256 diff = int256($.totalAssets) - int256(FEOracle(Constants.FE_ORACLE).tvl(address(d.vault)));
            if (diff < 0) {
                diff = -diff;
            }
            require(uint256(diff) <= MAX_ERROR, "Invalid totalAssets");
            for (uint256 i = 0; i < $.users.length; i++) {
                address user = $.users[i];
                require($.shares[i] == shareManager.sharesOf(user), "Invalid sharesOf");
                require($.pendingDeposits[i] == pendingDepositsOf(d, user), "Invalid pendingDepositsOf");
                require($.pendingWithdrawals[i] == pendingWithdrawalsOf(d, user), "Invalid pendingWithdrawalsOf");
            }
        } else if (t.t == Transitions.FINALIZE) {
            IShareManager shareManager = d.vault.shareManager();
            require(shareManager.totalShares() <= MAX_ERROR, "Non-dust total shares");
        } else {
            // do nothing
        }
        saveSnapshot($, d);
        $.latestTransition.t = Transitions.NONE;
    }
}
