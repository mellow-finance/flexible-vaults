// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IFluidVault {
    function operate(uint256 nftId_, int256 newCol_, int256 newDebt_, address to_)
        external
        payable
        returns (uint256, int256, int256);

    struct ConstantViews {
        address liquidity;
        address factory;
        address adminImplementation;
        address secondaryImplementation;
        address supplyToken;
        address borrowToken;
        uint8 supplyDecimals;
        uint8 borrowDecimals;
        uint256 vaultId;
        bytes32 liquiditySupplyExchangePriceSlot;
        bytes32 liquidityBorrowExchangePriceSlot;
        bytes32 liquidityUserSupplySlot;
        bytes32 liquidityUserBorrowSlot;
    }

    function constantsView() external view returns (ConstantViews memory);
}
