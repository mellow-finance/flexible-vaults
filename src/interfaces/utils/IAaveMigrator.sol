// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

import {ICallModule} from "../modules/ICallModule.sol";
import {IVaultModule} from "../modules/IVaultModule.sol";
import {IVerifier} from "../permissions/IVerifier.sol";

import {IAaveOracle} from "../external/aave/IAaveOracle.sol";
import {IAavePool} from "../external/aave/IAavePool.sol";

interface IAaveMigrator {
    /// @notice Migration has already been completed or permanently disabled.
    error AlreadyMigrated();

    /// @notice Total equity deviation after migration exceeds the allowed threshold.
    error CumulativeErrorTooHigh();

    /// @notice Account health factor is below the configured minimum.
    error HealthFactorIsTooLow();

    /// @notice Requested migration amount is too small.
    error InsufficientDebt();

    /// @notice Maximum target utilization must be in range (0, 1e18).
    error InvalidMaxUtilizationD18();

    /// @notice Migration percentage must be in range (0, 1e6].
    error InvalidPercentageD6();

    /// @notice Source position does not have enough collateral to support migration.
    error NotEnoughCollateral();

    /// @notice Migration would require more iterations than allowed.
    /// @param iterations Calculated number of required migration steps.
    error TooManyIterations(uint256 iterations);

    /// @notice Remaining debt after migration exceeds the allowed tolerance.
    error DebtTooHigh();

    /**
     * @notice Validates account health factor and returns current equity.
     * @dev Reverts if the account health factor is below the specified threshold.
     *      Equity is calculated using Aave account data as:
     *      collateralBase - debtBase.
     * @param holder Address of the account to check.
     * @param minAllowedHealthFactorD18 Minimum acceptable health factor (1e18 precision).
     * @return equity Account equity in Aave base currency units.
     */
    function checkHFAndGetEquity(address holder, uint256 minAllowedHealthFactorD18) external view returns (uint256);

    /**
     * @notice Calculates migration parameters for a given migration percentage.
     * @dev Determines the number of migration iterations required based on:
     *      - target subvault borrow capacity;
     *      - available debt liquidity;
     *      - configured utilization limit.
     * @param maxUtilizationD18 Maximum allowed utilization of target borrowing capacity (1e18 precision).
     * @param percentageD6 Percentage of source debt to migrate (1e6 precision).
     * @return iterations Number of migration loops required.
     * @return debtPerStep Debt amount migrated in each iteration.
     * @return collateralPerStep Collateral amount migrated in each iteration.
     * @return expectedDebtAfter Expected remaining debt on the source subvault.
     */
    function calculateSteps(uint256 maxUtilizationD18, uint256 percentageD6)
        external
        view
        returns (uint256 iterations, uint256 debtPerStep, uint256 collateralPerStep, uint256 expectedDebtAfter);

    /**
     * @notice Permanently disables further migrations.
     * @dev Can only be called by the contract owner.
     */
    function kill() external;

    /**
     * @notice Migrates a portion of an Aave position from the source subvault to the target subvault.
     * @dev For each iteration:
     *      1. Target borrows debt asset.
     *      2. Debt is transferred to source.
     *      3. Source repays debt.
     *      4. Source withdraws collateral.
     *      5. Target supplies received collateral.
     *
     *      Final state is validated using:
     *      - source and target health factors;
     *      - equity conservation checks;
     *      - expected remaining source debt.
     *
     * @param maxUtilizationD18 Maximum utilization of target borrow capacity (1e18 precision).
     * @param percentageD6 Percentage of source debt to migrate (1e6 precision).
     */
    function migrate(uint256 maxUtilizationD18, uint256 percentageD6) external;

    /// @notice Emitted when migration is permanently disabled.
    /// @param timestamp Block timestamp.
    /// @param caller Transaction sender.
    event Killed(uint256 indexed timestamp, address indexed caller);

    /// @notice Emitted when the entire debt position has been migrated.
    /// @param timestamp Block timestamp.
    /// @param caller Transaction sender.
    /// @param cumulativeError Total observed equity deviation.
    event Migrated(uint256 indexed timestamp, address indexed caller, uint256 indexed cumulativeError);

    /// @notice Emitted when only part of the debt position has been migrated.
    /// @param timestamp Block timestamp.
    /// @param caller Transaction sender.
    /// @param cumulativeError Total observed equity deviation.
    /// @param percentageD6 Percentage of debt migrated during this execution.
    event PartiallyMigrated(
        uint256 indexed timestamp, address indexed caller, uint256 indexed cumulativeError, uint256 percentageD6
    );
}
