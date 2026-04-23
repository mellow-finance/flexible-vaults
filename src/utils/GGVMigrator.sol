// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IGGVMigrator.sol";

contract GGVMigrator is IGGVMigrator, Ownable {
    using SafeCast for uint256;
    using SignedMath for int256;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

    IAavePool public constant AAVE = IAavePool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IAavePool public constant SPARK = IAavePool(0xC13e21B648A5Ee794902342038FF3aDAB66BE987);

    IAaveOracle public constant ORACLE = IAaveOracle(0x54586bE62E3c3580375aE3723C145253060Ca0C2);

    address public constant WETH_ATOKEN = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address public constant WETH_DEBT_TOKEN = 0xeA51d7853EEFb32b6ee06b1C12E6dcCA88Be0fFE;
    address public constant WEETH_ATOKEN = 0xBdfa7b7893081B35Fb54027489e2Bc7A38275129;

    IVaultModule public constant strETH = IVaultModule(0x277C6A642564A91ff78b008022D65683cEE5CCC5);
    IGGV public constant GGV = IGGV(0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09);

    uint256 public constant GGV_MIN_ALLOWED_HF_D18 = 1.01 ether;
    uint256 public constant MELLOW_MIN_ALLOWED_HF_D18 = 1.01 ether;

    uint256 public constant MAX_ALLOWED_CUMULATIVE_ERROR = 1e8; // 1$
    uint256 public constant MAX_ALLOWED_ITERATIONS = 30;

    uint256 public constant MIN_WETH_DEBT_BEFORE_MIGRATION = 1 ether;
    uint256 public constant MAX_WETH_DEBT_AFTER_MIGRATION = 1 gwei;

    address public constant SUBVAULT = 0x893aa69FBAA1ee81B536f0FbE3A3453e86290080;
    uint256 public constant SUBVAULT_INDEX = 1;

    bool public migrated = false;

    constructor(address owner_) Ownable(owner_) {}

    function checkHFAndGetEquity(address holder, uint256 minAllowedHealthFactorD18) public view returns (uint256) {
        (uint256 collateralBase, uint256 debtBase,,,, uint256 healthFactor) = AAVE.getUserAccountData(holder);

        if (healthFactor < minAllowedHealthFactorD18) {
            revert HealthFactorIsTooLow();
        }

        return collateralBase - debtBase;
    }

    function calculateSteps(uint256 maxUtilizationD18)
        public
        view
        returns (uint256 iterations, uint256 wethPerStep, uint256 weethPerStep)
    {
        uint256 wethDebt = IERC20(WETH_DEBT_TOKEN).balanceOf(address(GGV));
        if (wethDebt < MIN_WETH_DEBT_BEFORE_MIGRATION) {
            revert InsufficientWethDebt();
        }

        if (SUBVAULT != strETH.subvaultAt(SUBVAULT_INDEX)) {
            revert InvalidSubvault();
        }

        (,, uint256 maxBorrowValue,,,) = AAVE.getUserAccountData(SUBVAULT);
        maxBorrowValue = Math.mulDiv(maxBorrowValue, maxUtilizationD18, 1 ether);

        uint256 wethPrice = ORACLE.getAssetPrice(WETH);
        uint256 maxBorrowWeth = Math.mulDiv(maxBorrowValue, 1 ether, wethPrice);
        maxBorrowWeth = Math.min(
            maxBorrowWeth, Math.saturatingSub(IERC20(WETH_ATOKEN).totalSupply(), IERC20(WETH_DEBT_TOKEN).totalSupply())
        );

        if (maxBorrowWeth == 0) {
            revert TooManyIterations(type(uint256).max);
        }

        iterations = Math.ceilDiv(wethDebt, maxBorrowWeth);
        if (iterations > MAX_ALLOWED_ITERATIONS) {
            revert TooManyIterations(iterations);
        }

        wethPerStep = wethDebt / iterations;
        uint256 weethPrice = ORACLE.getAssetPrice(WEETH);
        weethPerStep = Math.mulDiv(wethPerStep, wethPrice, weethPrice);
        uint256 weethCollateral = IERC20(WEETH_ATOKEN).balanceOf(address(GGV));
        if (weethPerStep * iterations > weethCollateral) {
            revert NotEnoughWeETHCollateral();
        }
    }

    function kill() external onlyOwner {
        migrated = true;
        emit Killed(block.timestamp, _msgSender());
    }

    function migrate(uint256 maxUtilizationD18, uint256 wethToRepay, uint256 wethToBorrow) external onlyOwner {
        if (maxUtilizationD18 == 0 || maxUtilizationD18 >= 1 ether) {
            revert InvalidMaxUtilizationD18();
        }

        if (migrated) {
            revert AlreadyMigrated();
        } else {
            // prevent re-execution and theoretical reentrancy
            migrated = true;
        }

        IVerifier.VerificationPayload memory payload;
        if (wethToRepay != 0) {
            if (IERC20(WETH).balanceOf(SUBVAULT) < wethToRepay) {
                revert NotEnoughWETH();
            }
            ICallModule(SUBVAULT).call(
                address(WETH), 0, abi.encodeCall(IERC20.approve, (address(AAVE), wethToRepay)), payload
            );
            bytes memory response = ICallModule(SUBVAULT).call(
                address(AAVE), 0, abi.encodeCall(IAavePool.repay, (WETH, wethToRepay, 2, SUBVAULT)), payload
            );
            uint256 repayedAmount = abi.decode(response, (uint256));
            if (repayedAmount != wethToRepay) {
                revert InvalidRepayAmount();
            }
        }

        (uint256 iterations, uint256 wethPerStep, uint256 weethPerStep) = calculateSteps(maxUtilizationD18);

        uint256 ggvEquityBefore = checkHFAndGetEquity(address(GGV), GGV_MIN_ALLOWED_HF_D18);
        uint256 mellowEquityBefore = checkHFAndGetEquity(SUBVAULT, MELLOW_MIN_ALLOWED_HF_D18);

        for (uint256 i = 0; i < iterations; i++) {
            ICallModule(SUBVAULT).call(
                address(AAVE), 0, abi.encodeCall(IAavePool.borrow, (WETH, wethPerStep, 2, 0, SUBVAULT)), payload
            );
            ICallModule(SUBVAULT).call(
                address(WETH), 0, abi.encodeCall(IERC20.transfer, (address(GGV), wethPerStep)), payload
            );

            GGV.manage(WETH, abi.encodeCall(IERC20.approve, (address(AAVE), wethPerStep)), 0);
            GGV.manage(address(AAVE), abi.encodeCall(IAavePool.repay, (WETH, wethPerStep, 2, address(GGV))), 0);
            GGV.manage(address(AAVE), abi.encodeCall(IAavePool.withdraw, (WEETH, weethPerStep, SUBVAULT)), 0);

            ICallModule(SUBVAULT).call(WEETH, 0, abi.encodeCall(IERC20.approve, (address(AAVE), weethPerStep)), payload);
            ICallModule(SUBVAULT).call(
                address(AAVE), 0, abi.encodeCall(IAavePool.supply, (WEETH, weethPerStep, SUBVAULT, 0)), payload
            );
        }

        uint256 cumulativeError;

        {
            uint256 ggvEquityAfter = checkHFAndGetEquity(address(GGV), GGV_MIN_ALLOWED_HF_D18);
            uint256 mellowEquityAfter = checkHFAndGetEquity(SUBVAULT, MELLOW_MIN_ALLOWED_HF_D18);
            cumulativeError = (ggvEquityAfter.toInt256() - ggvEquityBefore.toInt256()).abs()
                + (mellowEquityAfter.toInt256() - mellowEquityBefore.toInt256()).abs();
        }

        if (cumulativeError > MAX_ALLOWED_CUMULATIVE_ERROR) {
            revert CumulativeErrorTooHigh();
        }

        if (IERC20(WETH_DEBT_TOKEN).balanceOf(address(GGV)) > MAX_WETH_DEBT_AFTER_MIGRATION) {
            revert WethDebtTooHigh();
        }

        if (wethToBorrow != 0) {
            if (wethToBorrow > wethToRepay) {
                revert InvalidBorrowAmount();
            }
            ICallModule(SUBVAULT).call(
                address(AAVE), 0, abi.encodeCall(IAavePool.borrow, (WETH, wethToBorrow, 2, 0, SUBVAULT)), payload
            );
            checkHFAndGetEquity(SUBVAULT, MELLOW_MIN_ALLOWED_HF_D18);
        }

        emit Migrated(block.timestamp, _msgSender(), cumulativeError);
    }
}
