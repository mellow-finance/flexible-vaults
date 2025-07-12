// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./ShareManager.sol";

contract TokenizedShareManager is ShareManager, ERC20Upgradeable {
    using ShareManagerFlagLibrary for uint256;

    constructor(string memory name_, uint256 version_) ShareManager(name_, version_) {}

    // View functions

    /// @inheritdoc IShareManager
    function activeSharesOf(address account) public view override returns (uint256) {
        return balanceOf(account);
    }

    /// @inheritdoc IShareManager
    function activeShares() public view override returns (uint256) {
        return totalSupply();
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        (bytes32 whitelistMerkleRoot_, string memory name_, string memory symbol_) =
            abi.decode(data, (bytes32, string, string));
        __ERC20_init(name_, symbol_);
        __ShareManager_init(whitelistMerkleRoot_);
        emit Initialized(data);
    }

    // Internal functions

    function _mintShares(address account, uint256 value) internal override {
        _mint(account, value);
    }

    function _burnShares(address account, uint256 value) internal override {
        _burn(account, value);
    }

    function _update(address from, address to, uint256 value) internal override {
        updateChecks(from, to);
        if (from != address(0)) {
            claimShares(from);
        }
        if (to != address(0)) {
            claimShares(to);
        }
        super._update(from, to, value);
    }
}
