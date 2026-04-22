// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

import {ICallModule} from "../modules/ICallModule.sol";
import {IVaultModule} from "../modules/IVaultModule.sol";
import {IVerifier} from "../permissions/IVerifier.sol";

import {IAaveOracle} from "../external/aave/IAaveOracle.sol";
import {IAavePool} from "../external/aave/IAavePool.sol";

interface IGGV {
    function manage(address target, bytes calldata data, uint256 value) external returns (bytes memory result);
}

interface IGGVMigrator {
    error AlreadyMigrated();
    error CumulativeErrorTooHigh();
    error HealthFactorIsTooLow();
    error InsufficientWethDebt();
    error InvalidMaxUtilizationD18();
    error InvalidStrETHSubvault();
    error NotEnoughWeETHCollateral();
    error TooManyIterations(uint256 iterations);
    error WethDebtTooHigh();

    function checkHFAndGetEquity(address holder, uint256 minAllowedHealthFactorD18) external view returns (uint256);

    function calculateSteps(uint256 maxUtilizationD18)
        external
        view
        returns (uint256 iterations, uint256 wethPerStep, uint256 weethPerStep, address subvault);

    function migrate(uint256 maxUtilizationD18) external;

    event Killed(uint256 indexed timestamp, address indexed caller);

    event Migrated(uint256 indexed timestamp, address indexed caller, uint256 indexed cumulativeError);
}
