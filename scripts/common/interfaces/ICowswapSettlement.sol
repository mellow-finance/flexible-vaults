// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ICowswapSettlement {
    struct InteractionData {
        address target;
        uint256 value;
        bytes callData;
    }

    struct TradeData {
        uint256 sellTokenIndex;
        uint256 buyTokenIndex;
        address receiver;
        uint256 sellAmount;
        uint256 buyAmount;
        uint32 validTo;
        bytes32 appData;
        uint256 feeAmount;
        uint256 flags;
        uint256 executedAmount;
        bytes signature;
    }

    function setPreSignature(bytes calldata orderUid, bool signed) external;

    function invalidateOrder(bytes calldata orderUid) external;

    function domainSeparator() external view returns (bytes32);

    function vault() external view returns (address);

    function settle(
        address[] calldata tokens,
        uint256[] calldata clearingPrices,
        TradeData[] calldata trades,
        InteractionData[][3] calldata interactions
    ) external;
}
