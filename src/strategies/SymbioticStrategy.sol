// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/modules/ICallModule.sol";

interface ISymbioticVault {
    function collateral() external view returns (address);
    function deposit(address onBehalfOf, uint256 amount)
        external
        returns (uint256 depositedAmount, uint256 mintedShares);
    function withdraw(address claimer, uint256 amount) external returns (uint256 burnedShares, uint256 mintedShares);
    function claim(address recipient, uint256 epoch) external returns (uint256 amount);
}

/// @notice Out of scope! Used as an example only.
contract SymbioticStrategy is Ownable {
    error ApproveCallFailed();

    constructor(address owner) Ownable(owner) {}

    function deposit(
        address subvault,
        address symbioticVault,
        uint256 assets,
        IVerifier.VerificationPayload[2] calldata verificationPayload
    ) external onlyOwner {
        address asset = ISymbioticVault(symbioticVault).collateral();
        bytes memory approveReponse = ICallModule(subvault).call(
            asset, 0, abi.encodeCall(IERC20.approve, (symbioticVault, assets)), verificationPayload[0]
        );
        if (!abi.decode(approveReponse, (bool))) {
            revert ApproveCallFailed();
        }
        ICallModule(subvault).call(
            symbioticVault, 0, abi.encodeCall(ISymbioticVault.deposit, (subvault, assets)), verificationPayload[1]
        );
    }

    function withdraw(
        address subvault,
        address symbioticVault,
        uint256 assets,
        IVerifier.VerificationPayload calldata verificationPayload
    ) external onlyOwner {
        ICallModule(subvault).call(
            symbioticVault, 0, abi.encodeCall(ISymbioticVault.withdraw, (subvault, assets)), verificationPayload
        );
    }

    function claim(
        address subvault,
        address symbioticVault,
        uint256 epoch,
        IVerifier.VerificationPayload calldata verificationPayload
    ) external onlyOwner {
        ICallModule(subvault).call(
            symbioticVault, 0, abi.encodeCall(ISymbioticVault.claim, (subvault, epoch)), verificationPayload
        );
    }

    function test() private pure {}
}
