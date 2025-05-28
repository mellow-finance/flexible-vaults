// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/TransferLibrary.sol";
import "../modules/SharesModule.sol";

abstract contract Queue is Initializable {
    using SafeERC20 for IERC20;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public asset;
    SharesModule public vault;

    uint256 public epochIterator = 1;
    mapping(uint256 epoch => uint256) public demandAt;

    function __Queue_init(address asset_, address sharesModule_) internal onlyInitializing {
        if (asset_ == address(0) || sharesModule_ == address(0)) {
            revert("Queue: zero address");
        }
        asset = asset_;
        vault = SharesModule(payable(sharesModule_));
    }

    function handleEpochs(uint256 limit) public returns (uint256 counter) {
        uint256 epochIterator_ = epochIterator;
        while (counter < limit && _handleEpoch(epochIterator_ + counter)) {
            unchecked {
                counter++;
            }
        }
        if (counter > 0) {
            unchecked {
                epochIterator = epochIterator_ + counter;
            }
        }
    }

    function handleEpoch() public returns (bool) {
        return _handleEpoch(epochIterator);
    }

    function _handleEpoch(uint256 epoch) internal virtual returns (bool);
}
