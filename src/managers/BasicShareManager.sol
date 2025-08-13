// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./ShareManager.sol";

contract BasicShareManager is ShareManager {
    using ShareManagerFlagLibrary for uint256;

    bytes32 private constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    constructor(string memory name_, uint256 version_) ShareManager(name_, version_) {}

    // View functions

    /// @inheritdoc IShareManager
    function activeShares() public view override returns (uint256) {
        return _getERC20Storage()._totalSupply;
    }

    /// @inheritdoc IShareManager
    function activeSharesOf(address account) public view override returns (uint256) {
        return _getERC20Storage()._balances[account];
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        __ShareManager_init(abi.decode(data, (bytes32)));
        emit Initialized(data);
    }

    // Internal functions

    function _mintShares(address account, uint256 value) internal override {
        if (account == address(0)) {
            revert IERC20Errors.ERC20InvalidReceiver(address(0));
        }
        updateChecks(address(0), account);
        ERC20Upgradeable.ERC20Storage storage $ = _getERC20Storage();
        $._totalSupply += value;
        unchecked {
            $._balances[account] += value;
        }
        emit IERC20.Transfer(address(0), account, value);
    }

    function _burnShares(address account, uint256 value) internal override {
        if (account == address(0)) {
            revert IERC20Errors.ERC20InvalidSender(address(0));
        }
        updateChecks(account, address(0));
        ERC20Upgradeable.ERC20Storage storage $ = _getERC20Storage();
        uint256 balance = $._balances[account];
        if (balance < value) {
            revert IERC20Errors.ERC20InsufficientBalance(account, balance, value);
        }
        unchecked {
            $._balances[account] = balance - value;
            $._totalSupply -= value;
        }
        emit IERC20.Transfer(account, address(0), value);
    }

    function _getERC20Storage() private pure returns (ERC20Upgradeable.ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }
}
