// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IVerifier, Subvault} from "../vaults/Subvault.sol";
import {Vault} from "../vaults/Vault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IGGV {
    function manage(address target, bytes calldata data, uint256 value) external returns (bytes memory result);
}

interface IAaveV3Pool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;

    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256);

    function getUserAccountData(address user)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256);

    function getReserveAToken(address asset) external view returns (address);

    function getReserveVariableDebtToken(address asset) external view returns (address);
}

interface IAaveV3Oracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

contract EthMigrator is Ownable {
    IAaveV3Pool public constant POOL = IAaveV3Pool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IAaveV3Oracle public constant ORACLE = IAaveV3Oracle(0x54586bE62E3c3580375aE3723C145253060Ca0C2);

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

    Vault public constant strETH = Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5));
    IGGV public constant GGV = IGGV(0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09);

    constructor(address owner_) Ownable(owner_) {}

    function migrate() external onlyOwner {
        uint256 wethPrice = ORACLE.getAssetPrice(WETH);
        uint256 weethPrice = ORACLE.getAssetPrice(WEETH);

        address aWEETH = POOL.getReserveAToken(WEETH);
        address aWETHDebt = POOL.getReserveVariableDebtToken(WETH);
        uint256 wethDebt = IERC20(aWETHDebt).balanceOf(address(GGV));

        Subvault subvault = Subvault(payable(strETH.subvaultAt(1)));

        (,, uint256 valueToBorrowInBase,,,) = POOL.getUserAccountData(address(subvault));

        uint256 wethAmountPerStep = valueToBorrowInBase * 1 ether / wethPrice;
        uint256 weethAmountPerStep = valueToBorrowInBase * 1 ether / weethPrice;
        uint256 iterations = Math.ceilDiv(wethDebt, wethAmountPerStep);
        if (iterations > 10) {
            revert("Too many iterations");
        }

        IVerifier.VerificationPayload memory payload;
        for (uint256 i = 0; i < iterations; i++) {
            subvault.call(
                address(POOL),
                0,
                abi.encodeCall(IAaveV3Pool.borrow, (WETH, wethAmountPerStep, 2, 0, address(subvault))),
                payload
            );
            subvault.call(address(WETH), 0, abi.encodeCall(IERC20.transfer, (address(GGV), wethAmountPerStep)), payload);

            GGV.manage(WETH, abi.encodeCall(IERC20.approve, (address(POOL), wethAmountPerStep)), 0);
            GGV.manage(address(POOL), abi.encodeCall(IAaveV3Pool.repay, (WETH, wethAmountPerStep, 2, address(GGV))), 0);

            weethAmountPerStep = Math.min(weethAmountPerStep, IERC20(aWEETH).balanceOf(address(GGV)));
            GGV.manage(
                address(POOL), abi.encodeCall(IAaveV3Pool.withdraw, (WEETH, weethAmountPerStep, address(subvault))), 0
            );
        }
    }
}
