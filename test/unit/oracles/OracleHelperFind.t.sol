// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "test/mocks/MockOracleHelper.sol";

contract OracleHelperTest is Test {
    MockOracleHelper private oracleHelper;
    MockFeeManager private feeManager;

    function setUp() public {
        oracleHelper = new MockOracleHelper();
        feeManager = new MockFeeManager();
    }

    function testFuzzNoFees(uint256 priceD18) public {
        vm.assume(priceD18 > 1 ether / 1000 && priceD18 < type(uint256).max / 1 ether);

        uint256 totalAssets = 1 ether;
        uint256 totalShares = Math.mulDiv(totalAssets, priceD18, 1 ether);

        feeManager.setMinPrice(priceD18);
        feeManager.setPerformanceFee(0);
        feeManager.setProtocolFee(0);
        feeManager.setTimestamp(block.timestamp);

        /// @dev recalculate right side of search interval
        priceD18 = Math.mulDiv(
            totalShares + feeManager.calculateFee(address(0), address(0), priceD18, totalShares), 1 ether, totalAssets
        );

        uint256 solutionD18 = priceD18 < feeManager.minPriceD18()
            ? oracleHelper.find(
                address(feeManager), address(0), priceD18, feeManager.minPriceD18(), address(0), totalShares, 0, totalAssets
            )
            : priceD18;

        assertEq(solutionD18, priceD18, "Price should not change when no fees are applied");

        _checkPriceSolutionD18(solutionD18, totalAssets, totalShares);
    }

    function testFuzzProtocolFee(uint256 priceD18, uint32 skipSeconds) public {
        vm.assume(priceD18 > 1 ether / 1000 && priceD18 < type(uint256).max / 1 ether);
        vm.assume(skipSeconds < 365 days * 10);

        uint256 totalAssets = 1 ether;
        uint256 totalShares = Math.mulDiv(totalAssets, priceD18, 1 ether);

        feeManager.setMinPrice(priceD18);
        feeManager.setPerformanceFee(0);
        feeManager.setProtocolFee(1e4); // 1%
        feeManager.setTimestamp(block.timestamp);

        skip(skipSeconds);

        /// @dev recalculate right side of search interval
        priceD18 = Math.mulDiv(
            totalShares + feeManager.calculateFee(address(0), address(0), priceD18, totalShares), 1 ether, totalAssets
        );
        uint256 solutionD18 = priceD18 < feeManager.minPriceD18()
            ? oracleHelper.find(
                address(feeManager), address(0), priceD18, feeManager.minPriceD18(), address(0), totalShares, 0, totalAssets
            )
            : priceD18;

        _checkPriceSolutionD18(solutionD18, totalAssets, totalShares);
    }

    function testFuzzPerformanceFee(uint256 priceD18, int32 priceDelta, uint16 performanceFee) public {
        vm.assume(priceD18 > 1 ether / 1000 && priceD18 < type(uint256).max / 1 ether);

        uint256 totalAssets = 1 ether;
        uint256 totalShares = Math.mulDiv(totalAssets, priceD18, 1 ether);
        feeManager.setMinPrice(priceD18);
        feeManager.setPerformanceFee(performanceFee);
        feeManager.setProtocolFee(0);
        feeManager.setTimestamp(block.timestamp);

        uint256 newPriceD18 =
            Math.mulDiv(priceD18, uint128(int128(type(int64).max) - int128(priceDelta)), uint64(type(int64).max));
        totalAssets = Math.mulDiv(totalShares, 1 ether, newPriceD18);

        /// @dev recalculate right side of search interval
        priceD18 = Math.mulDiv(
            totalShares + feeManager.calculateFee(address(0), address(0), priceD18, totalShares), 1 ether, totalAssets
        );

        uint256 solutionD18 = priceD18 < feeManager.minPriceD18()
            ? oracleHelper.find(
                address(feeManager), address(0), priceD18, feeManager.minPriceD18(), address(0), totalShares, 0, totalAssets
            )
            : priceD18;

        _checkPriceSolutionD18(solutionD18, totalAssets, totalShares);
    }

    function testFuzzBothFees(uint256 priceD18, int32 priceDelta, uint16 performanceFee, uint16 protocolFee) public {
        vm.assume(priceD18 > 1 ether / 1000 && priceD18 < type(uint256).max / 1 ether);

        uint256 totalAssets = 1 ether;
        uint256 totalShares = Math.mulDiv(totalAssets, priceD18, 1 ether);
        feeManager.setMinPrice(priceD18);
        feeManager.setPerformanceFee(performanceFee);
        feeManager.setProtocolFee(protocolFee);
        feeManager.setTimestamp(block.timestamp);

        uint256 newPriceD18 =
            Math.mulDiv(priceD18, uint128(int128(type(int64).max) - int128(priceDelta)), uint64(type(int64).max));
        totalAssets = Math.mulDiv(totalShares, 1 ether, newPriceD18);

        skip(1 days);

        /// @dev recalculate right side of search interval
        priceD18 = Math.mulDiv(
            totalShares + feeManager.calculateFee(address(0), address(0), priceD18, totalShares), 1 ether, totalAssets
        );

        uint256 solutionD18 = priceD18 < feeManager.minPriceD18()
            ? oracleHelper.find(
                address(feeManager), address(0), priceD18, feeManager.minPriceD18(), address(0), totalShares, 0, totalAssets
            )
            : priceD18;

        _checkPriceSolutionD18(solutionD18, totalAssets, totalShares);
    }

    /// @notice Check the solution for the price is correct:
    /// 1. calculate expected feeShares based on the solutionD18
    /// 2. assert that the feeShares is approximately equal to the calculated fee
    /// 3. calculate expectedPriceD18 based on the totalShares with included feeShares
    /// 4. assert that the solutionD18 is approximately equal to the expectedPriceD18
    function _checkPriceSolutionD18(uint256 solutionD18, uint256 totalAssets, uint256 totalSharesBefore)
        internal
        view
    {
        /// @dev a new expected totalShares, while totalAssets is unchanged
        uint256 totalShares = Math.mulDiv(totalAssets, solutionD18, 1 ether);

        if (totalShares > totalSharesBefore) {
            uint256 feeShares = totalShares - totalSharesBefore;
            uint256 feeSharesExpected =
                feeManager.calculateFee(address(0), address(0), solutionD18, totalShares - feeShares);

            uint256 feeSharesAbsDelta =
                feeShares > feeSharesExpected ? feeShares - feeSharesExpected : feeSharesExpected - feeShares;

            if (feeSharesAbsDelta > 1) {
                /// @dev 1e-18 precision
                assertApproxEqRel(feeShares, feeSharesExpected, 1, "Wrong feeShares");
            }
            uint256 expectedPriceD18 = Math.mulDiv(totalShares, 1 ether, totalAssets);
            /// @dev 1e-14 precision
            assertApproxEqRel(solutionD18, expectedPriceD18, 1e4, "Wrong price");
        }
    }
}
