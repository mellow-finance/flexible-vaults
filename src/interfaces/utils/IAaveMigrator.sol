// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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

    /// @notice Amount of debt selected for migration is below the minimum allowed threshold.
    error InsufficientDebt();

    /// @notice Maximum target utilization must be in range (0, 1e18).
    error InvalidMaxUtilizationD18();

    /// @notice Migration percentage must be in range (0, 1e6].
    error InvalidPercentageD6();

    /// @notice Source position does not have enough collateral to migrate the requested debt amount.
    error NotEnoughCollateral();

    /// @notice Migration would require more iterations than allowed or cannot be executed.
    /// @param iterations Calculated number of required migration steps.
    error TooManyIterations(uint256 iterations);

    /// @notice Remaining debt after migration would be below the minimum migration threshold
    ///         while still exceeding the tolerated residual value.
    error InvalidDebtAfterMigration();

    /// @notice Actual remaining source debt deviates from the expected value beyond the allowed tolerance.
    error TooHighDeviation();

    /// @notice ERC20 transfer operation returned false.
    error ERC20TransferFailed();

    /// @notice ERC20 approve operation returned false.
    error ERC20ApproveFailed();

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
     * @dev Simulates migration constraints using:
     *      - source debt size;
     *      - target subvault borrowing capacity;
     *      - available debt asset liquidity in Aave;
     *      - configured utilization limit.
     *
     *      Reverts if the migration is not feasible under the current conditions.
     *
     * @param maxUtilizationD18 Maximum allowed utilization of target borrowing capacity (1e18 precision).
     * @param percentageD6 Percentage of source debt to migrate (1e6 precision).
     * @return iterations Number of migration loops required.
     * @return debtPerStep Debt amount migrated during each iteration.
     * @return collateralPerStep Collateral amount migrated during each iteration.
     * @return expectedDebtAfter Expected remaining debt on the source subvault after migration.
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
     * @dev Migration is performed iteratively to avoid exceeding the target borrow capacity.
     *      For each iteration:
     *      1. Target subvault borrows the debt asset from Aave.
     *      2. Borrowed debt is transferred to the source subvault.
     *      3. Source subvault repays a portion of its debt.
     *      4. Source subvault withdraws proportional collateral.
     *      5. Target subvault supplies the received collateral back to Aave.
     *
     *      After all iterations complete, the migration validates:
     *      - source and target health factors;
     *      - cumulative equity preservation;
     *      - expected remaining debt on the source position.
     *
     *      Emits {Migrated} when the remaining debt is within the configured tolerance,
     *      otherwise emits {PartiallyMigrated}.
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
