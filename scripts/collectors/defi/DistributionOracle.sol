// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/libraries/TransferLibrary.sol";
import "../../../src/vaults/Vault.sol";
import "./ICustomOracle.sol";
import "./external/IAaveOracleV3.sol";
import "./protocols/IDistributionCollector.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@openzeppelin/contracts/proxy/Clones.sol";

contract DistributionOracle {
    uint256 public constant BUFFER_SIZE = 1024;

    struct Protocol {
        address collector;
        bool skipVault;
        bytes params;
    }

    function load() public view returns (Protocol[] memory protocols, address[] memory assets) {
        (protocols, assets) = abi.decode(Clones.fetchCloneArgs(address(this)), (Protocol[], address[]));
    }

    function getDistributions(address vault_, bytes[] calldata parameters_)
        public
        view
        returns (IDistributionCollector.Balance[] memory response)
    {
        Vault vault = Vault(payable(vault_));
        uint256 subvaults = vault.subvaults();
        address[] memory vaults = new address[](subvaults + 1);
        for (uint256 i = 0; i < subvaults; i++) {
            vaults[i] = vault.subvaultAt(i);
        }
        vaults[subvaults] = address(vault);

        uint256 iterator = 0;
        (Protocol[] memory protocols, address[] memory assets) = load();
        for (uint256 i = 0; i < protocols.length; i++) {
            if (parameters_[i].length > 0) {
                protocols[i].params = parameters_[i];
            }
        }

        response = new IDistributionCollector.Balance[](BUFFER_SIZE);
        IDistributionCollector.Balance[] memory balances;
        for (uint256 i = 0; i < protocols.length; i++) {
            for (uint256 j = 0; j < vaults.length - (protocols[i].skipVault ? 1 : 0); j++) {
                balances = IDistributionCollector(protocols[i].collector).getDistributions(
                    vaults[j], protocols[i].params, assets
                );
                for (uint256 k = 0; k < balances.length; k++) {
                    if (balances[k].balance != 0) {
                        response[iterator++] = balances[k];
                    }
                }
            }
        }
        assembly {
            mstore(response, iterator)
        }
    }
}
