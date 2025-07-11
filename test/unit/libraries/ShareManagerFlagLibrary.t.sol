// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract ShareManagerFlagLibraryTest is Test {
    using ShareManagerFlagLibrary for uint256;

    uint256 constant BIT_0 = 1 << 0;
    uint256 constant BIT_1 = 1 << 1;
    uint256 constant BIT_2 = 1 << 2;
    uint256 constant BIT_3 = 1 << 3;
    uint256 constant BIT_4 = 1 << 4;
    uint256 constant BIT_5 = 1 << 5;

    uint256 constant GLOBAL_LOCKUP_START_BIT = 5;
    uint256 constant GLOBAL_LOCKUP_END_BIT = 36;

    uint256 constant TARGETED_LOCKUP_START_BIT = 37;
    uint256 constant TARGETED_LOCKUP_END_BIT = 68;

    /// @notice Tests that `hasMintPause` returns correct values for bit 0 .
    function testHasMintPause(uint256 value) public pure {
        assertEq(BIT_0.hasMintPause(), true);
        assertEq(BIT_1.hasMintPause(), false);
        assertEq(BIT_2.hasMintPause(), false);
        assertEq(BIT_3.hasMintPause(), false);
        assertEq(BIT_4.hasMintPause(), false);
        assertEq(BIT_5.hasMintPause(), false);

        bool hasBitSet = _isBitSet(value, 0);
        assertEq(value.hasMintPause(), hasBitSet);
    }

    /// @notice Tests that `hasBurnPause` returns correct values for bit 1.
    function testHasBurnPause(uint256 value) public pure {
        assertEq(BIT_0.hasBurnPause(), false);
        assertEq(BIT_1.hasBurnPause(), true);
        assertEq(BIT_2.hasBurnPause(), false);
        assertEq(BIT_3.hasBurnPause(), false);
        assertEq(BIT_4.hasBurnPause(), false);
        assertEq(BIT_5.hasBurnPause(), false);

        bool hasBitSet = _isBitSet(value, 1);
        assertEq(value.hasBurnPause(), hasBitSet);
    }

    /// @notice Tests that `hasTransferPause` returns correct values for bit 2.
    function testHasTransferPause(uint256 value) public pure {
        assertEq(BIT_0.hasTransferPause(), false);
        assertEq(BIT_1.hasTransferPause(), false);
        assertEq(BIT_2.hasTransferPause(), true);
        assertEq(BIT_3.hasTransferPause(), false);
        assertEq(BIT_4.hasTransferPause(), false);
        assertEq(BIT_5.hasTransferPause(), false);

        bool hasBitSet = _isBitSet(value, 2);
        assertEq(value.hasTransferPause(), hasBitSet);
    }

    /// @notice Tests that `hasWhitelist` returns correct values for bit 3.
    function testHasWhitelist(uint256 value) public pure {
        assertEq(BIT_0.hasWhitelist(), false);
        assertEq(BIT_1.hasWhitelist(), false);
        assertEq(BIT_2.hasWhitelist(), false);
        assertEq(BIT_3.hasWhitelist(), true);
        assertEq(BIT_4.hasWhitelist(), false);
        assertEq(BIT_5.hasWhitelist(), false);

        bool hasBitSet = _isBitSet(value, 3);
        assertEq(value.hasWhitelist(), hasBitSet);
    }

    /// @notice Tests that `hasTransferWhitelist` returns correct values for bit 4.
    function testHasTransferWhitelist(uint256 value) public pure {
        assertEq(BIT_0.hasTransferWhitelist(), false);
        assertEq(BIT_1.hasTransferWhitelist(), false);
        assertEq(BIT_2.hasTransferWhitelist(), false);
        assertEq(BIT_3.hasTransferWhitelist(), false);
        assertEq(BIT_4.hasTransferWhitelist(), true);
        assertEq(BIT_5.hasTransferWhitelist(), false);

        bool hasBitSet = _isBitSet(value, 4);
        assertEq(value.hasTransferWhitelist(), hasBitSet);
    }

    /**
     * Global lockup extraction tests
     */

    /// @notice Tests that `getGlobalLockup` returns zero for zero input.
    function testGetGlobalLockupZero() public pure {
        assertEq(uint256(0).getGlobalLockup(), 0);
    }

    /// @notice Tests that `getGlobalLockup` returns zero when only flags are set.
    function testGetGlobalLockupOnlyFlags() public pure {
        uint256 value = BIT_0 | BIT_1 | BIT_2 | BIT_3 | BIT_4;
        assertEq(value.getGlobalLockup(), 0);
    }

    /// @notice Tests that `getGlobalLockup` correctly extracts small lockup value.
    function testGetGlobalLockupSimpleValue() public pure {
        uint256 value = uint256(42) << GLOBAL_LOCKUP_START_BIT;
        assertEq(value.getGlobalLockup(), 42);
    }

    /// @notice Tests that `getGlobalLockup` handles maximum uint32 values.
    function testGetGlobalLockupMaxValue() public pure {
        uint256 value = uint256(type(uint32).max) << GLOBAL_LOCKUP_START_BIT;
        assertEq(value.getGlobalLockup(), type(uint32).max);
    }

    /// @notice Tests that `getGlobalLockup` ignores higher bits beyond bit 36.
    function testGetGlobalLockupIgnoreHigherBits() public pure {
        uint256 value = (uint256(42) << 5) | (uint256(0xFFFFFFFF) << (GLOBAL_LOCKUP_END_BIT + 1));
        assertEq(value.getGlobalLockup(), 42);
    }

    /// @notice Tests that `getGlobalLockup` works with combined flags and lockup.
    function testGetGlobalLockupCombinedWithFlags() public pure {
        uint256 everyFlag = BIT_0 | BIT_1 | BIT_2 | BIT_3 | BIT_4;
        uint256 value = everyFlag | (uint256(123) << GLOBAL_LOCKUP_START_BIT); // All flags set + lockup value 123
        assertEq(value.getGlobalLockup(), 123);
    }

    /// @notice Tests that `getGlobalLockup` correctly extracts values from bits 5-36 for any input.
    function testGetGlobalLockupFuzzed(uint256 value) public pure {
        uint32 expected = uint32(value >> GLOBAL_LOCKUP_START_BIT);
        assertEq(value.getGlobalLockup(), expected);
    }

    /**
     * Targeted lockup extraction tests
     */

    /// @notice Tests that `getTargetedLockup` returns zero for zero input.
    function testGetTargetedLockupZero() public pure {
        assertEq(uint256(0).getTargetedLockup(), 0);
    }

    /// @notice Tests that `getTargetedLockup` returns zero when only flags are set.
    function testGetTargetedLockupOnlyFlags() public pure {
        uint256 value = BIT_0 | BIT_1 | BIT_2 | BIT_3 | BIT_4;
        assertEq(value.getTargetedLockup(), 0);
    }

    /// @notice Tests that `getTargetedLockup` returns zero when only global lockup is set.
    function testGetTargetedLockupOnlyGlobalLockup() public pure {
        uint256 value = uint256(42) << GLOBAL_LOCKUP_START_BIT;
        assertEq(value.getTargetedLockup(), 0);
    }

    /// @notice Tests that `getTargetedLockup` correctly extracts small lockup value.
    function testGetTargetedLockupSimpleValue() public pure {
        uint256 value = uint256(42) << TARGETED_LOCKUP_START_BIT;
        assertEq(value.getTargetedLockup(), 42);
    }

    /// @notice Tests that `getTargetedLockup` handles maximum uint32 values.
    function testGetTargetedLockupMaxValue() public pure {
        uint256 value = uint256(type(uint32).max) << TARGETED_LOCKUP_START_BIT;
        assertEq(value.getTargetedLockup(), type(uint32).max);
    }

    /// @notice Tests that `getTargetedLockup` ignores higher bits beyond bit 68.
    function testGetTargetedLockupIgnoreHigherBits() public pure {
        uint256 value =
            (uint256(42) << TARGETED_LOCKUP_START_BIT) | (uint256(0xFFFFFFFF) << (TARGETED_LOCKUP_END_BIT + 1));
        assertEq(value.getTargetedLockup(), 42);
    }

    /// @notice Tests that `getTargetedLockup` works with combined flags and lockup.
    function testGetTargetedLockupCombinedWithFlags() public pure {
        uint256 everyFlag = BIT_0 | BIT_1 | BIT_2 | BIT_3 | BIT_4;
        uint256 value = everyFlag | (uint256(123) << TARGETED_LOCKUP_START_BIT); // All flags set + lockup value 123
        assertEq(value.getTargetedLockup(), 123);
    }

    /// @notice Tests that `getTargetedLockup` works with combined flags, global lockup, and targeted lockup.
    function testGetTargetedLockupCombinedWithFlagsAndGlobalLockup() public pure {
        uint256 everyFlag = BIT_0 | BIT_1 | BIT_2 | BIT_3 | BIT_4;
        uint256 globalLockup = uint256(456) << GLOBAL_LOCKUP_START_BIT;
        uint256 targetedLockup = uint256(789) << TARGETED_LOCKUP_START_BIT;
        uint256 value = everyFlag | globalLockup | targetedLockup;
        assertEq(value.getTargetedLockup(), 789);
    }

    /// @notice Tests that `getTargetedLockup` correctly extracts values from bits 37-68 for any input.
    function testGetTargetedLockupFuzzed(uint256 value) public pure {
        uint32 expected = uint32(value >> TARGETED_LOCKUP_START_BIT);
        assertEq(value.getTargetedLockup(), expected);
    }

    /**
     * Mask creation tests
     */

    /// @notice Tests that `createMask` returns zero when all flags are false and lockups are zero.
    function testCreateMaskAllZero() public view {
        uint256 mask = _createMask(false, false, false, false, false, 0, 0);
        assertEq(mask, 0);
    }

    /// @notice Tests that `createMask` correctly handles all boolean flags being true.
    function testCreateMaskAllBooleanFlags() public view {
        uint256 mask = _createMask(true, true, true, true, true, 0, 0);
        assertEq(mask, BIT_0 | BIT_1 | BIT_2 | BIT_3 | BIT_4);
    }

    /// @notice Tests that `createMask` correctly handles lockup values.
    function testCreateMaskWithLockups() public view {
        uint256 mask = _createMask(true, true, true, true, true, 123, 456);
        uint256 globalLockup = uint256(123) << GLOBAL_LOCKUP_START_BIT;
        uint256 targetedLockup = uint256(456) << TARGETED_LOCKUP_START_BIT;
        assertEq(mask, BIT_0 | BIT_1 | BIT_2 | BIT_3 | BIT_4 | globalLockup | targetedLockup);
    }

    /// @notice Tests that the mask creation and retrieval work correctly for any valid input.
    function testMaskApplicationFuzzed(
        bool hasMintPause,
        bool hasBurnPause,
        bool hasTransferPause,
        bool hasWhitelist,
        bool hasTransferWhitelist,
        uint32 globalLockup,
        uint32 targetedLockup
    ) public view {
        uint256 mask = _createMask(
            hasMintPause,
            hasBurnPause,
            hasTransferPause,
            hasWhitelist,
            hasTransferWhitelist,
            globalLockup,
            targetedLockup
        );
        assertEq(mask.hasMintPause(), hasMintPause);
        assertEq(mask.hasBurnPause(), hasBurnPause);
        assertEq(mask.hasTransferPause(), hasTransferPause);
        assertEq(mask.hasWhitelist(), hasWhitelist);
        assertEq(mask.hasTransferWhitelist(), hasTransferWhitelist);
        assertEq(mask.getGlobalLockup(), globalLockup);
        assertEq(mask.getTargetedLockup(), targetedLockup);
    }

    /**
     * Helper functions
     */
    function _createMask(
        bool hasMintPause,
        bool hasBurnPause,
        bool hasTransferPause,
        bool hasWhitelist,
        bool hasTransferWhitelist,
        uint32 globalLockup,
        uint32 targetedLockup
    ) private view returns (uint256) {
        return this.createMaskHelper(
            IShareManager.Flags({
                hasMintPause: hasMintPause,
                hasBurnPause: hasBurnPause,
                hasTransferPause: hasTransferPause,
                hasWhitelist: hasWhitelist,
                hasTransferWhitelist: hasTransferWhitelist,
                globalLockup: globalLockup,
                targetedLockup: targetedLockup
            })
        );
    }

    /// @dev Used to cast memory to calldata for the createMask function.
    function createMaskHelper(IShareManager.Flags calldata f) external pure returns (uint256) {
        return ShareManagerFlagLibrary.createMask(f);
    }

    function _isBitSet(uint256 value, uint8 n) private pure returns (bool) {
        return ((value >> n) & 1) == 1;
    }
}
