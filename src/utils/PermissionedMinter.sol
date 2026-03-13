// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ISyncDepositQueue} from "../interfaces/queues/ISyncDepositQueue.sol";

import {RiskManager} from "../managers/RiskManager.sol";
import "../vaults/Vault.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PermissionedMinter is ERC20 {
    using SafeERC20 for IERC20;

    Vault public immutable vault;
    address public immutable admin;
    address public immutable target;
    uint224 public immutable shares;
    uint256 public immutable syncDepositQueueVersion;

    bool public minted = false;

    struct State {
        uint256 queueLimit;
        int256 vaultLimit;
    }

    constructor(Vault vault_, address admin_, address target_, uint224 shares_, uint256 syncDepositQueueVersion_)
        ERC20("PhantomToken", "pt")
    {
        if (address(vault_) == address(0) || admin_ == address(0) || shares_ == 0 || target_ == address(0)) {
            revert("PermissionMinter: zero params");
        }
        if (!vault_.hasRole(vault_.DEFAULT_ADMIN_ROLE(), admin_)) {
            revert("PermissionedMinter: forbidden");
        }
        vault = vault_;
        admin = admin_;
        target = target_;
        shares = shares_;
        syncDepositQueueVersion = syncDepositQueueVersion_;
    }

    function getInitialState() public view returns (State memory state) {
        state.queueLimit = vault.queueLimit();

        IRiskManager riskManager = vault.riskManager();
        state.vaultLimit = riskManager.vaultState().limit;
    }

    function mint() external {
        if (msg.sender != admin) {
            revert("PermissionMinter: forbidden");
        }
        if (minted) {
            revert("PermissionMinter: already minted");
        }

        if (!vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), address(this))) {
            revert("PermissionMinter: not enough permissions");
        }

        if (vault.shareManager().totalShares() != 0) {
            revert("PermissionMinter: totalShares != 0");
        }

        if (vault.feeManager().depositFeeD6() != 0) {
            revert("PermissionedMinter: depositFeeD6 != 0");
        }

        State memory initialState = getInitialState();

        _mintShares();
        _revertToInitialState(initialState);

        minted = true;
    }

    function _grant(bytes32 role) internal {
        vault.grantRole(role, address(this));
    }

    function _mintShares() private {
        IOracle oracle = vault.oracle();
        RiskManager riskManager = RiskManager(address(vault.riskManager()));

        _grant(oracle.ADD_SUPPORTED_ASSETS_ROLE());
        _grant(oracle.SUBMIT_REPORTS_ROLE());
        _grant(oracle.ACCEPT_REPORT_ROLE());
        _grant(oracle.REMOVE_SUPPORTED_ASSETS_ROLE());
        _grant(vault.CREATE_QUEUE_ROLE());
        _grant(vault.REMOVE_QUEUE_ROLE());
        _grant(vault.SET_QUEUE_LIMIT_ROLE());
        _grant(riskManager.SET_VAULT_LIMIT_ROLE());

        {
            address[] memory assets = new address[](1);
            assets[0] = address(this);

            oracle.addSupportedAssets(assets);
        }
        {
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0].asset = address(this);
            reports[0].priceD18 = 1 ether;
            oracle.submitReports(reports);
        }
        oracle.acceptReport(address(this), 1 ether, uint32(block.timestamp));

        vault.setQueueLimit(type(uint256).max);
        riskManager.setVaultLimit(type(int256).max / 2);

        vault.createQueue(syncDepositQueueVersion, true, address(this), address(this), abi.encode(0, 1 seconds));
        address queue = vault.queueAt(address(this), 0);

        _mint(address(this), shares);
        _approve(address(this), queue, shares);

        IERC20 shareManager = IERC20(address(vault.shareManager()));
        if (shareManager.totalSupply() != 0 || shareManager.balanceOf(address(this)) != 0) {
            revert("PermissionMinter: invalid share balance before deposit");
        }

        ISyncDepositQueue(queue).deposit(shares, address(0), new bytes32[](0));

        if (shareManager.totalSupply() != shares || shareManager.balanceOf(address(this)) != shares) {
            revert("PermissionMinter: invalid share balance after deposit");
        }

        shareManager.safeTransfer(target, shares);
        if (
            shareManager.totalSupply() != shares || shareManager.balanceOf(target) != shares
                || shareManager.balanceOf(address(this)) != 0
        ) {
            revert("PermissionMinter: invalid share balance after transfer");
        }
    }

    function _revertToInitialState(State memory state) private {
        IRiskManager riskManager = vault.riskManager();
        riskManager.setVaultLimit(state.vaultLimit);

        vault.setQueueLimit(state.queueLimit);

        address queue = vault.queueAt(address(this), 0);
        vault.removeQueue(queue);

        address[] memory assets = new address[](1);
        assets[0] = address(this);

        vault.oracle().removeSupportedAssets(assets);

        // burn deposited phantom assets
        _burn(address(vault), shares);

        // renounce all roles
        bytes32[] memory roles = new bytes32[](vault.supportedRoles());
        uint256 iterator = 0;
        for (uint256 roleIndex = 0; roleIndex < roles.length; roleIndex++) {
            bytes32 role = vault.supportedRoleAt(roleIndex);
            if (vault.hasRole(role, address(this))) {
                roles[iterator++] = role;
            }
        }
        for (uint256 roleIndex = 0; roleIndex < iterator; roleIndex++) {
            vault.renounceRole(roles[roleIndex], address(this));
        }
    }
}
