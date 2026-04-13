// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IGGVMigrator.sol";

contract GGVMigrator is IGGVMigrator, Ownable {
    using SafeCast for uint256;
    using SignedMath for int256;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

    IAavePool public constant POOL = IAavePool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IAaveOracle public constant ORACLE = IAaveOracle(0x54586bE62E3c3580375aE3723C145253060Ca0C2);

    address public constant WETH_DEBT_TOKEN = 0xeA51d7853EEFb32b6ee06b1C12E6dcCA88Be0fFE;
    address public constant WEETH_ATOKEN = 0xBdfa7b7893081B35Fb54027489e2Bc7A38275129;

    IVaultModule public constant strETH = IVaultModule(0x277C6A642564A91ff78b008022D65683cEE5CCC5);
    IGGV public constant GGV = IGGV(0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09);

    uint256 public constant GGV_MIN_ALLOWED_HF_D18 = 1.01 ether;
    uint256 public constant MELLOW_MIN_ALLOWED_HF_D18 = 1.07 ether;

    uint256 public constant MAX_ALLOWED_CUMULATIVE_ERROR = 1e8; // 1$
    uint256 public constant MAX_ALLOWED_ITERATIONS = 30;

    uint256 public constant MIN_WETH_DEBT_BEFORE_MIGRATION = 1 ether;
    uint256 public constant MAX_WETH_DEBT_AFTER_MIGRATION = 1 gwei;

    address public constant STRETH_SUBVAULT_ADDRESS = 0x893aa69FBAA1ee81B536f0FbE3A3453e86290080;
    uint256 public constant STRETH_SUBVAULT_INDEX = 1;

    bool public migrated = false;

    constructor(address owner_) Ownable(owner_) {}

    function checkHFAndGetEquity(address holder, uint256 minAllowedHealthFactorD18) public view returns (uint256) {
        (uint256 collateralBase, uint256 debtBase,,,, uint256 healthFactor) = POOL.getUserAccountData(holder);

        if (healthFactor < minAllowedHealthFactorD18) {
            revert HealthFactorIsTooLow();
        }

        return collateralBase - debtBase;
    }

    function calculateSteps(uint256 maxUtilizationD18)
        public
        view
        returns (uint256 iterations, uint256 wethPerStep, uint256 weethPerStep, address subvault)
    {
        uint256 wethDebt = IERC20(WETH_DEBT_TOKEN).balanceOf(address(GGV));
        if (wethDebt < MIN_WETH_DEBT_BEFORE_MIGRATION) {
            revert InsufficientWethDebt();
        }

        subvault = strETH.subvaultAt(STRETH_SUBVAULT_INDEX);
        if (STRETH_SUBVAULT_ADDRESS != subvault) {
            revert InvalidStrETHSubvault();
        }

        (,, uint256 maxBorrowValue,,,) = POOL.getUserAccountData(subvault);
        maxBorrowValue = Math.mulDiv(maxBorrowValue, maxUtilizationD18, 1 ether);

        uint256 wethPrice = ORACLE.getAssetPrice(WETH);
        uint256 maxBorrowWeth = Math.mulDiv(maxBorrowValue, 1 ether, wethPrice);
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

    function migrate(uint256 maxUtilizationD18) external onlyOwner {
        if (maxUtilizationD18 == 0 || maxUtilizationD18 >= 1 ether) {
            revert InvalidMaxUtilizationD18();
        }

        if (migrated) {
            revert AlreadyMigrated();
        }

        (uint256 iterations, uint256 wethPerStep, uint256 weethPerStep, address subvault) =
            calculateSteps(maxUtilizationD18);

        uint256 ggvEquityBefore = checkHFAndGetEquity(address(GGV), GGV_MIN_ALLOWED_HF_D18);
        uint256 mellowEquityBefore = checkHFAndGetEquity(subvault, MELLOW_MIN_ALLOWED_HF_D18);

        IVerifier.VerificationPayload memory payload;
        for (uint256 i = 0; i < iterations; i++) {
            ICallModule(subvault).call(
                address(POOL), 0, abi.encodeCall(IAavePool.borrow, (WETH, wethPerStep, 2, 0, subvault)), payload
            );
            ICallModule(subvault).call(
                address(WETH), 0, abi.encodeCall(IERC20.transfer, (address(GGV), wethPerStep)), payload
            );

            GGV.manage(WETH, abi.encodeCall(IERC20.approve, (address(POOL), wethPerStep)), 0);
            GGV.manage(address(POOL), abi.encodeCall(IAavePool.repay, (WETH, wethPerStep, 2, address(GGV))), 0);
            GGV.manage(address(POOL), abi.encodeCall(IAavePool.withdraw, (WEETH, weethPerStep, subvault)), 0);

            ICallModule(subvault).call(WEETH, 0, abi.encodeCall(IERC20.approve, (address(POOL), weethPerStep)), payload);
            ICallModule(subvault).call(
                address(POOL), 0, abi.encodeCall(IAavePool.supply, (WEETH, weethPerStep, subvault, 0)), payload
            );
        }

        uint256 ggvEquityAfter = checkHFAndGetEquity(address(GGV), GGV_MIN_ALLOWED_HF_D18);
        uint256 mellowEquityAfter = checkHFAndGetEquity(subvault, MELLOW_MIN_ALLOWED_HF_D18);
        uint256 cumulativeError = (ggvEquityAfter.toInt256() - ggvEquityBefore.toInt256()).abs()
            + (mellowEquityAfter.toInt256() - mellowEquityBefore.toInt256()).abs();

        if (cumulativeError > MAX_ALLOWED_CUMULATIVE_ERROR) {
            revert CumulativeErrorTooHigh();
        }

        if (IERC20(WETH_DEBT_TOKEN).balanceOf(address(GGV)) > MAX_WETH_DEBT_AFTER_MIGRATION) {
            revert WethDebtTooHigh();
        }

        migrated = true;
        emit Migrated(block.timestamp, _msgSender(), cumulativeError);
    }
}
