// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

struct SendParam {
    uint32 dstEid;
    bytes32 to;
    uint256 amountLD;
    uint256 minAmountLD;
    bytes extraOptions;
    bytes composeMsg;
    bytes oftCmd;
}

struct OFTReceipt {
    uint256 amountSentLD;
    uint256 amountReceivedLD;
}

interface IOFT {
    function quoteSend(SendParam calldata _sendParam, bool _payInLzToken) external view returns (MessagingFee memory);

    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        returns (MessagingReceipt memory, OFTReceipt memory);

    function oftVersion() external view returns (bytes4 interfaceId, uint64 version);

    function token() external view returns (address);
}
