// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../../src/vaults/Subvault.sol";
import "../../src/vaults/Vault.sol";

import "../../src/utils/EthMigrator.sol";

interface IAuthority {
    function canCall(address user, address target, bytes4 functionSig) external view returns (bool);
}

interface IGGVAuthority {
    function authority() external view returns (address);
}

contract Deploy is Script, Test {
    address curator = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;

    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address weeth = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address aaveV3Pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    Vault strETH = Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5));
    IGGV ggv = IGGV(0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09);

    function logState(address holder, string memory name) public view {
        console.log("Aave position of %s", name);
        (uint256 totalCollateralBase, uint256 totalDebtBase,,,, uint256 healthFactor) =
            IAaveV3Pool(aaveV3Pool).getUserAccountData(holder);
        console.log("collateral - debt = %s, hf %s", totalCollateralBase - totalDebtBase, healthFactor);

        address aWeETH = IAaveV3Pool(aaveV3Pool).getReserveAToken(weeth);

        address aWETHDebt = IAaveV3Pool(aaveV3Pool).getReserveVariableDebtToken(weth);
        console.log("weeth collateral: %s", IERC20(aWeETH).balanceOf(holder));
        console.log("weth debt: %s", IERC20(aWETHDebt).balanceOf(holder));
    }

    function run() external {
        Subvault subvault = Subvault(payable(strETH.subvaultAt(1)));

        {
            // grant required permissions in ggv authority
            address authority = IGGVAuthority(address(ggv)).authority();
            vm.mockCall(authority, abi.encodePacked(IAuthority.canCall.selector), abi.encode(true));

            // grant required permissions in strETH verifier
            IVerifier verifier = subvault.verifier();
            vm.mockCall(address(verifier), abi.encodePacked(IVerifier.verifyCall.selector), abi.encode());
        }

        EthMigrator migrator = new EthMigrator(curator);

        vm.startPrank(curator);

        IVerifier.VerificationPayload memory payload;
        uint256 balance = IERC20(wsteth).balanceOf(address(subvault));
        console.log("streth: supply wsteth");
        subvault.call(wsteth, 0, abi.encodeCall(IERC20.approve, (aaveV3Pool, balance)), payload);
        subvault.call(
            aaveV3Pool, 0, abi.encodeCall(IAaveV3Pool.supply, (wsteth, balance, address(subvault), 0)), payload
        );

        logState(address(subvault), "strETH subvault0");
        logState(address(ggv), "ggv");

        uint256 g = gasleft();

        migrator.migrate();

        console.log("Gas used:", g - gasleft());

        logState(address(subvault), "strETH subvault0");
        logState(address(ggv), "ggv");

        vm.stopPrank();
    }
}
