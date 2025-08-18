// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "test/mocks/MockOracleHelper.sol";

contract OracleHelperFindTest is Test {
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
    /// 3. verify that the _find equation is satisfied: (totalSharesBefore + fee) * 1 ether / totalAssets <= solutionD18
    function _checkPriceSolutionD18(uint256 solutionD18, uint256 totalAssets, uint256 totalSharesBefore)
        internal
        view
    {
        /// @dev calculate the fee shares that should be generated at this price
        uint256 feeSharesExpected =
            feeManager.calculateFee(address(0), address(0), solutionD18, totalSharesBefore);

        /// @dev a new expected totalShares, while totalAssets is unchanged
        uint256 totalShares = Math.mulDiv(totalAssets, solutionD18, 1 ether);
        if (totalShares > totalSharesBefore) {
            uint256 feeShares = totalShares - totalSharesBefore;
            assertApproxEqAbs(feeShares, feeSharesExpected, 1, "Wrong fee shares");
        }

        if (feeSharesExpected > 0) {
            /// @dev verify the core equation that _find is solving:
            /// (totalSharesBefore + fee) * 1 ether / totalAssets <= solutionD18
            uint256 leftSideD18 = Math.mulDiv(totalSharesBefore + feeSharesExpected, 1 ether, totalAssets);
            assertLe(leftSideD18, solutionD18, "Solution doesn't satisfy the _find equation");
            
            /// @dev also verify that the solution is close to the boundary (within reasonable precision)
            /// This ensures we found the optimal solution, not just any solution that satisfies the inequality
            assertApproxEqAbs(leftSideD18, solutionD18, 1, "Solution should be close to the boundary");
        }
    }
}
