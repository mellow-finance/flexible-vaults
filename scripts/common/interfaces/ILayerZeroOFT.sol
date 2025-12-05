// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ILayerZeroOFT {
    struct SendParam {
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    struct OFTReceipt {
        uint256 amountSentLD;
        uint256 amountReceivedLD;
    }

    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        returns (MessagingReceipt memory, OFTReceipt memory);
}
