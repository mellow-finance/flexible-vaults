// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../../src/vaults/Subvault.sol";
import "../../src/vaults/Vault.sol";

interface IAuthority {
    function canCall(address user, address target, bytes4 functionSig) external view returns (bool);
}

interface IGGV {
    function manage(address target, bytes calldata data, uint256 value) external returns (bytes memory result);

    function authority() external view returns (address);
}

interface IAaveV3Pool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;

    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256);

    function setUserEMode(uint8 categoryId) external;

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function getUserEMode(address user) external view returns (uint16);
}

contract Deploy is Script, Test {
    address curator = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;

    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address weeth = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address aweeth = 0xBdfa7b7893081B35Fb54027489e2Bc7A38275129;
    address aaveV3Pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    Vault strETH = Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5));
    IGGV ggv = IGGV(0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09);

    function run() external {
        Subvault subvault = Subvault(payable(strETH.subvaultAt(1)));

        {
            // grant required permissions in ggv authority
            address authority = ggv.authority();
            vm.mockCall(authority, abi.encodePacked(IAuthority.canCall.selector), abi.encode(true));

            // grant required permissions in strETH verifier
            IVerifier verifier = subvault.verifier();
            vm.mockCall(address(verifier), abi.encodePacked(IVerifier.verifyCall.selector), abi.encode());
        }

        vm.startPrank(curator);

        uint256 weethPrice = 1.093695 ether;

        IVerifier.VerificationPayload memory payload;

        uint256 balance = IERC20(wsteth).balanceOf(address(subvault));
        subvault.call(wsteth, 0, abi.encodeCall(IERC20.approve, (aaveV3Pool, balance)), payload);
        subvault.call(
            aaveV3Pool, 0, abi.encodeCall(IAaveV3Pool.supply, (wsteth, balance, address(subvault), 0)), payload
        );

        uint256 wethAmount = 15000 ether;
        uint256 weethAmount = wethAmount;

        for (uint256 i = 0; i < 4; i++) {
            console.log("borrow weth");
            // borrow WETH
            subvault.call(
                aaveV3Pool, 0, abi.encodeCall(IAaveV3Pool.borrow, (weth, wethAmount, 2, 0, address(subvault))), payload
            );
            // transfer WETH strETH -> GGV
            subvault.call(weth, 0, abi.encodeCall(IERC20.transfer, (address(ggv), wethAmount)), payload);

            // repay WETH
            ggv.manage(weth, abi.encodeCall(IERC20.approve, (aaveV3Pool, wethAmount)), 0);
            ggv.manage(aaveV3Pool, abi.encodeCall(IAaveV3Pool.repay, (weth, wethAmount, 2, address(ggv))), 0);
            console.log("withdraw aweeth ggv -> streth");
            ggv.manage(aaveV3Pool, abi.encodeCall(IAaveV3Pool.withdraw, (weeth, weethAmount, address(subvault))), 0);

            deal(address(weeth), address(subvault), 0);
            deal(address(wsteth), address(subvault), weethAmount);

            console.log("supply weeth streth");
            subvault.call(wsteth, 0, abi.encodeCall(IERC20.approve, (aaveV3Pool, weethAmount)), payload);
            subvault.call(
                aaveV3Pool, 0, abi.encodeCall(IAaveV3Pool.supply, (wsteth, weethAmount, address(subvault), 0)), payload
            );
        }

        vm.stopPrank();
    }
}
