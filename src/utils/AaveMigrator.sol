// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IAaveMigrator.sol";

contract AaveMigrator is IAaveMigrator, Ownable, ReentrancyGuard {
    using SafeCast for uint256;
    using SignedMath for int256;

    uint256 public constant MAX_ALLOWED_ITERATIONS = 30;

    IAavePool public immutable pool;
    IAaveOracle public immutable oracle;

    ICallModule public immutable sourceSubvault;
    ICallModule public immutable targetSubvault;

    address public immutable collateral;
    address public immutable collateralAToken;
    address public immutable debt;
    address public immutable debtAToken;
    address public immutable debtVariableDebtToken;

    uint256 public immutable minAllowedSourceHFD18;
    uint256 public immutable minAllowedTargetHFD18;

    uint256 public immutable minAllowedMigrationAmount;
    uint256 public immutable maxAllowedError;

    bool public migrated = false;

    constructor(
        address owner_,
        address pool_,
        address oracle_,
        address sourceSubvault_,
        address targetSubvault_,
        address collateral_,
        address debt_,
        uint256 minAllowedSourceHFD18_,
        uint256 minAllowedTargetHFD18_,
        uint256 minAllowedMigrationAmount_,
        uint256 maxAllowedError_
    ) Ownable(owner_) {
        pool = IAavePool(pool_);
        oracle = IAaveOracle(oracle_);

        sourceSubvault = ICallModule(sourceSubvault_);
        targetSubvault = ICallModule(targetSubvault_);

        collateral = collateral_;
        collateralAToken = pool.getReserveAToken(collateral);
        debt = debt_;
        debtAToken = pool.getReserveAToken(debt);
        debtVariableDebtToken = pool.getReserveVariableDebtToken(debt);

        minAllowedSourceHFD18 = minAllowedSourceHFD18_;
        minAllowedTargetHFD18 = minAllowedTargetHFD18_;

        minAllowedMigrationAmount = minAllowedMigrationAmount_;
        maxAllowedError = maxAllowedError_;
    }

    /// @inheritdoc IAaveMigrator
    function checkHFAndGetEquity(address holder, uint256 minAllowedHealthFactorD18) public view returns (uint256) {
        (uint256 collateralBase, uint256 debtBase,,,, uint256 healthFactor) = pool.getUserAccountData(holder);

        if (healthFactor < minAllowedHealthFactorD18) {
            revert HealthFactorIsTooLow();
        }

        return collateralBase - debtBase;
    }

    /// @inheritdoc IAaveMigrator
    function calculateSteps(uint256 maxUtilizationD18, uint256 percentageD6)
        public
        view
        returns (uint256 iterations, uint256 debtPerStep, uint256 collateralPerStep, uint256 expectedDebtAfter)
    {
        uint256 debtAmount = IERC20(debtVariableDebtToken).balanceOf(address(sourceSubvault));
        uint256 debtToMigrate = debtAmount * percentageD6 / 1e6;
        expectedDebtAfter = debtAmount - debtToMigrate;

        if (
            debtToMigrate < minAllowedMigrationAmount
                || expectedDebtAfter > maxAllowedError && expectedDebtAfter < minAllowedMigrationAmount
        ) {
            revert InsufficientDebt();
        }

        (,, uint256 maxBorrowValue,,,) = pool.getUserAccountData(address(targetSubvault));
        maxBorrowValue = Math.mulDiv(maxBorrowValue, maxUtilizationD18, 1 ether);

        uint256 debtPrice = oracle.getAssetPrice(debt);
        uint256 maxBorrowDebt = Math.mulDiv(maxBorrowValue, 1 ether, debtPrice);

        maxBorrowDebt = Math.min(
            maxBorrowDebt,
            Math.saturatingSub(IERC20(debtAToken).totalSupply(), IERC20(debtVariableDebtToken).totalSupply())
        );

        if (maxBorrowDebt == 0) {
            revert TooManyIterations(type(uint256).max);
        }

        iterations = Math.ceilDiv(debtToMigrate, maxBorrowDebt);
        if (iterations > MAX_ALLOWED_ITERATIONS) {
            revert TooManyIterations(iterations);
        }

        debtPerStep = debtToMigrate / iterations;
        uint256 collateralPrice = oracle.getAssetPrice(collateral);
        collateralPerStep = Math.mulDiv(debtPerStep, debtPrice, collateralPrice);

        uint256 collateralAmount = IERC20(collateralAToken).balanceOf(address(sourceSubvault));
        if (collateralPerStep * iterations > collateralAmount) {
            revert NotEnoughCollateral();
        }
    }

    /// @inheritdoc IAaveMigrator
    function kill() external onlyOwner {
        migrated = true;
        emit Killed(block.timestamp, _msgSender());
    }

    /// @inheritdoc IAaveMigrator
    function migrate(uint256 maxUtilizationD18, uint256 percentageD6) external onlyOwner nonReentrant {
        if (maxUtilizationD18 == 0 || maxUtilizationD18 >= 1 ether) {
            revert InvalidMaxUtilizationD18();
        }

        if (percentageD6 == 0 || percentageD6 > 1e6) {
            revert InvalidPercentageD6();
        }

        if (migrated) {
            revert AlreadyMigrated();
        }

        IVerifier.VerificationPayload memory payload;

        (uint256 iterations, uint256 debtPerStep, uint256 collateralPerStep, uint256 expectedDebtAfter) =
            calculateSteps(maxUtilizationD18, percentageD6);

        uint256 sourceEquityBefore = checkHFAndGetEquity(address(sourceSubvault), minAllowedSourceHFD18);
        uint256 targetEquityBefore = checkHFAndGetEquity(address(targetSubvault), minAllowedTargetHFD18);

        for (uint256 i = 0; i < iterations; i++) {
            targetSubvault.call(
                address(pool),
                0,
                abi.encodeCall(IAavePool.borrow, (debt, debtPerStep, 2, 0, address(targetSubvault))),
                payload
            );
            targetSubvault.call(
                address(debt), 0, abi.encodeCall(IERC20.transfer, (address(sourceSubvault), debtPerStep)), payload
            );

            if (IERC20(debt).allowance(address(sourceSubvault), address(pool)) != 0) {
                sourceSubvault.call(debt, 0, abi.encodeCall(IERC20.approve, (address(pool), 0)), payload);
            }
            sourceSubvault.call(debt, 0, abi.encodeCall(IERC20.approve, (address(pool), debtPerStep)), payload);
            sourceSubvault.call(
                address(pool),
                0,
                abi.encodeCall(IAavePool.repay, (debt, debtPerStep, 2, address(sourceSubvault))),
                payload
            );
            sourceSubvault.call(
                address(pool),
                0,
                abi.encodeCall(IAavePool.withdraw, (collateral, collateralPerStep, address(targetSubvault))),
                payload
            );

            if (IERC20(collateral).allowance(address(targetSubvault), address(pool)) != 0) {
                targetSubvault.call(collateral, 0, abi.encodeCall(IERC20.approve, (address(pool), 0)), payload);
            }
            targetSubvault.call(
                collateral, 0, abi.encodeCall(IERC20.approve, (address(pool), collateralPerStep)), payload
            );
            targetSubvault.call(
                address(pool),
                0,
                abi.encodeCall(IAavePool.supply, (collateral, collateralPerStep, address(targetSubvault), 0)),
                payload
            );
        }

        uint256 cumulativeError;

        {
            uint256 sourceEquityAfter = checkHFAndGetEquity(address(sourceSubvault), minAllowedSourceHFD18);
            uint256 targetEquityAfter = checkHFAndGetEquity(address(targetSubvault), minAllowedTargetHFD18);
            cumulativeError = (sourceEquityAfter.toInt256() - sourceEquityBefore.toInt256()).abs()
                + (targetEquityAfter.toInt256() - targetEquityBefore.toInt256()).abs();
        }

        if (cumulativeError > maxAllowedError) {
            revert CumulativeErrorTooHigh();
        }

        uint256 sourceDebt = IERC20(debtVariableDebtToken).balanceOf(address(sourceSubvault));
        if (sourceDebt > maxAllowedError + expectedDebtAfter || sourceDebt + maxAllowedError < expectedDebtAfter) {
            revert DebtTooHigh();
        }

        if (sourceDebt <= maxAllowedError) {
            migrated = true;
            emit Migrated(block.timestamp, _msgSender(), cumulativeError);
        } else {
            emit PartiallyMigrated(block.timestamp, _msgSender(), cumulativeError, percentageD6);
        }
    }
}
