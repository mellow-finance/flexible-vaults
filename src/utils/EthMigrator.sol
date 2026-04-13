// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

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
    using SafeCast for uint256;
    using SignedMath for int256;

    error TooManyIterations();
    error NotEnoughWeETHCollateral();
    error CumulativeErrorTooHigh();
    error HealthFactorIsTooLow();

    IAaveV3Pool public constant POOL = IAaveV3Pool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IAaveV3Oracle public constant ORACLE = IAaveV3Oracle(0x54586bE62E3c3580375aE3723C145253060Ca0C2);

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

    uint256 public constant GGV_MIN_ALLOWED_HF = 1.01 ether; // 1.01
    uint256 public constant MELLOW_MIN_ALLOWED_HF = 1.1 ether; // 1.1

    Vault public constant strETH = Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5));
    IGGV public constant GGV = IGGV(0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09);

    constructor(address owner_) Ownable(owner_) {}

    function checkHFAndGetValue(address holder, uint256 minAllowedHealthFactory) public view returns (uint256) {
        (uint256 totalCollateralBase, uint256 totalDebtBase,,,, uint256 healthFactor) = POOL.getUserAccountData(holder);
        if (healthFactor < minAllowedHealthFactory) {
            revert HealthFactorIsTooLow();
        }

        return totalCollateralBase - totalDebtBase;
    }

    function migrate() external onlyOwner {
        uint256 wethDebt = IERC20(POOL.getReserveVariableDebtToken(WETH)).balanceOf(address(GGV));
        uint256 weethCollateral = IERC20(POOL.getReserveAToken(WEETH)).balanceOf(address(GGV));

        Subvault subvault = Subvault(payable(strETH.subvaultAt(1)));

        uint256 iterations;
        uint256 wethPerStep;
        uint256 weethPerStep;
        {
            (,, uint256 maxValueForBorrow,,,) = POOL.getUserAccountData(address(subvault));
            maxValueForBorrow -= maxValueForBorrow / 10; // reduce by 10% to handle max LTV

            uint256 wethPrice = ORACLE.getAssetPrice(WETH);
            uint256 maxWethBorrow = Math.mulDiv(maxValueForBorrow, 1 ether, wethPrice);
            iterations = Math.ceilDiv(wethDebt, maxWethBorrow);
            if (iterations > 10) {
                revert TooManyIterations();
            }

            wethPerStep = wethDebt / iterations;
            uint256 weethPrice = ORACLE.getAssetPrice(WEETH);
            weethPerStep = Math.mulDiv(wethPerStep, wethPrice, weethPrice);
        }

        if (weethPerStep * iterations > weethCollateral) {
            revert NotEnoughWeETHCollateral();
        }

        uint256 ggvValueBefore = checkHFAndGetValue(address(GGV), GGV_MIN_ALLOWED_HF);
        uint256 mellowValueBefore = checkHFAndGetValue(address(subvault), MELLOW_MIN_ALLOWED_HF);

        IVerifier.VerificationPayload memory payload;
        for (uint256 i = 0; i < iterations; i++) {
            subvault.call(
                address(POOL),
                0,
                abi.encodeCall(IAaveV3Pool.borrow, (WETH, wethPerStep, 2, 0, address(subvault))),
                payload
            );
            subvault.call(address(WETH), 0, abi.encodeCall(IERC20.transfer, (address(GGV), wethPerStep)), payload);

            GGV.manage(WETH, abi.encodeCall(IERC20.approve, (address(POOL), wethPerStep)), 0);
            GGV.manage(address(POOL), abi.encodeCall(IAaveV3Pool.repay, (WETH, wethPerStep, 2, address(GGV))), 0);
            GGV.manage(address(POOL), abi.encodeCall(IAaveV3Pool.withdraw, (WEETH, weethPerStep, address(subvault))), 0);

            subvault.call(WEETH, 0, abi.encodeCall(IERC20.approve, (address(POOL), weethPerStep)), payload);
            subvault.call(
                address(POOL),
                0,
                abi.encodeCall(IAaveV3Pool.supply, (WEETH, weethPerStep, address(subvault), 0)),
                payload
            );
        }

        uint256 ggvValueAfter = checkHFAndGetValue(address(GGV), GGV_MIN_ALLOWED_HF);
        uint256 mellowValueAfter = checkHFAndGetValue(address(subvault), MELLOW_MIN_ALLOWED_HF);
        uint256 cumulativeError = (ggvValueAfter.toInt256() - ggvValueBefore.toInt256()).abs()
            + (mellowValueAfter.toInt256() - mellowValueBefore.toInt256()).abs();
        if (cumulativeError > 1e8) {
            // require(|ggvDelta| + |mellowDelta| <= 1$)
            revert CumulativeErrorTooHigh();
        }
    }
}
