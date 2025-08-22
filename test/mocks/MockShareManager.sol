// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

contract MockShareManager {
    address internal _whitelistedDepositor;
    bool internal _isWhitelistEnabled;

    function isDepositorWhitelisted(address depositor, bytes32[] calldata) external view returns (bool) {
        return !_isWhitelistEnabled || depositor == _whitelistedDepositor;
    }

    function allocateShares(uint256 /*shares*/ ) external {}

    function mintAllocatedShares(address, /* account */ uint256 /* shares */ ) external {}

    function mint(address, /* to */ uint256 /* amount */ ) external {}

    function burn(address, /* from */ uint256 /* amount */ ) external {}

    function lockSharesOf(address, /* account */ uint256 /* shares */ ) external {}

    /// -----------------------------------------------------------------------
    /// Custom functions, just for testing purposes.
    /// -----------------------------------------------------------------------

    function __setWhitelistedDepositor(address depositor) external {
        _whitelistedDepositor = depositor;
    }

    function __setWhitelistEnabled(bool isWhitelistEnabled) external {
        _isWhitelistEnabled = isWhitelistEnabled;
    }

    function test() external {}
}
