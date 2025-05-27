// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/SlotLibrary.sol";
import "../oracles/Oracle.sol";
import "../shares/SharesManager.sol";

import "./BaseModule.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract SharesModule is BaseModule {
    struct SharesModuleStorage {
        address sharesManager;
        address oracle;
        uint256 epochDuration;
        uint256 initTimestamp;
    }

    bytes32 private immutable _sharesModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _sharesModuleStorageSlot = SlotLibrary.getSlot("SharesModule", name_, version_);
    }

    function sharesManager() public view returns (SharesManager) {
        return SharesManager(_sharesModuleStorage().sharesManager);
    }

    function oracle() public view returns (Oracle) {
        return Oracle(_sharesModuleStorage().oracle);
    }

    function epochDuration() public view returns (uint256) {
        return _sharesModuleStorage().epochDuration;
    }

    function initTimestamp() public view returns (uint256) {
        return _sharesModuleStorage().initTimestamp;
    }

    function currentEpoch() public view returns (uint256) {
        SharesModuleStorage storage $ = _sharesModuleStorage();
        return (block.timestamp - $.initTimestamp) / $.epochDuration + 1;
    }

    function endTimestampOf(uint256 epoch) public view returns (uint256) {
        SharesModuleStorage storage $ = _sharesModuleStorage();
        return $.initTimestamp + epoch * $.epochDuration;
    }

    function __SharesModule_init(address sharesManager_, address oracle_, uint256 epochDuration_)
        internal
        onlyInitializing
    {
        if (sharesManager_ == address(0) || oracle_ == address(0)) {
            revert("SharesModule: zero address");
        }
        if (epochDuration_ == 0) {
            revert("SharesModule: zero duration");
        }
        SharesModuleStorage storage $ = _sharesModuleStorage();
        $.sharesManager = sharesManager_;
        $.oracle = oracle_;
        $.epochDuration = epochDuration_;
        $.initTimestamp = block.timestamp;
    }

    function _sharesModuleStorage() internal view returns (SharesModuleStorage storage $) {
        bytes32 slot = _sharesModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
