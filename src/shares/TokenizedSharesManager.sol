// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./SharesManager.sol";

contract TokenizedSharesManager is SharesManager, ERC20Upgradeable {
    using SharesManagerFlagLibrary for uint256;

    constructor(string memory name_, uint256 version_) SharesManager(name_, version_) {}

    // View functions

    function activeSharesOf(address account) public view override returns (uint256) {
        return balanceOf(account);
    }

    function activeShares() public view override returns (uint256) {
        return totalSupply();
    }

    // Mutable functions

    function initialize(bytes calldata data) external initializer {
        (
            address vault_,
            uint256 flags_,
            bytes32 whitelistMerkleRoot_,
            uint256 sharesLimit_,
            string memory name_,
            string memory symbol_
        ) = abi.decode(data, (address, uint256, bytes32, uint256, string, string));
        __ERC20_init(name_, symbol_);
        __SharesManager_init(vault_, flags_, whitelistMerkleRoot_, sharesLimit_);
    }

    // Internal functions

    function _mintShares(address account, uint256 value) internal override {
        _mint(account, value);
    }

    function _burnShares(address account, uint256 value) internal override {
        _burn(account, value);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0)) {
            claimShares(from);
        }
        if (to != address(0)) {
            claimShares(to);
        }
        updateChecks(from, to, value);
        super._update(from, to, value);
    }
}
