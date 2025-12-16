// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../../src/interfaces/factories/IFactory.sol";
import "../../../../src/interfaces/utils/ISwapModule.sol";
import "../../../../src/libraries/TransferLibrary.sol";
import "./IDistributionCollector.sol";

contract ERC20Collector is IDistributionCollector {
    address public immutable swapModuleFactory;

    constructor(address swapModuleFactory_) {
        swapModuleFactory = swapModuleFactory_;
    }

    function getSwapModule(address holder) public view returns (address) {
        if (swapModuleFactory == address(0)) {
            return address(0);
        }
        uint256 entities = IFactory(swapModuleFactory).entities();
        for (uint256 i = 0; i < entities; i++) {
            address swapModule = IFactory(swapModuleFactory).entityAt(i);
            if (ISwapModule(swapModule).subvault() == holder) {
                return swapModule;
            }
        }
        return address(0);
    }

    function getDistributions(address holder, bytes memory, /* deployment */ address[] memory assets)
        external
        view
        returns (Balance[] memory balances)
    {
        balances = new Balance[](assets.length);
        uint256 iterator = 0;
        address swapModule = getSwapModule(holder);
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 balance = TransferLibrary.balanceOf(assets[i], holder)
                + (swapModule == address(0) ? 0 : TransferLibrary.balanceOf(assets[i], swapModule));
            if (balance != 0) {
                balances[iterator++] =
                    Balance({asset: assets[i], balance: int256(balance), metadata: "ERC20", holder: holder});
            }
        }
        assembly {
            mstore(balances, iterator)
        }
    }
}
