// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/libraries/TransferLibrary.sol";
import "../../../src/vaults/Vault.sol";
import "./ICustomOracle.sol";
import "./external/IAaveOracleV3.sol";
import "./protocols/IDistributionCollector.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@openzeppelin/contracts/proxy/Clones.sol";

contract CustomOracle is ICustomOracle {
    IAaveOracleV3 public immutable AAVE_ORACLE;
    address public immutable nativeWrapper; // WETH

    constructor(address aaveOracle_, address nativeWrapper_) {
        AAVE_ORACLE = IAaveOracleV3(aaveOracle_);
        nativeWrapper = nativeWrapper_;
    }

    function load()
        public
        view
        returns (address[] memory protocols, bytes[] memory protocolDeployments, address[] memory assets)
    {
        return abi.decode(Clones.fetchCloneArgs(address(this)), (address[], bytes[], address[]));
    }

    function allTokens() public view returns (address[] memory tokens) {
        (,, tokens) = load();
    }

    function evaluate(address asset, address denominator, uint256 amount) public view returns (uint256) {
        if (asset == denominator) {
            return amount;
        }
        uint256 assetPriceD8 = AAVE_ORACLE.getAssetPrice(asset);
        uint8 assetDecimals = IERC20Metadata(asset).decimals();
        uint256 denominatorPriceD8 = AAVE_ORACLE.getAssetPrice(denominator);
        uint8 denominatorDecimals = denominator == address(0) ? 8 : IERC20Metadata(denominator).decimals();
        return Math.mulDiv(amount, assetPriceD8 * 10 ** denominatorDecimals, denominatorPriceD8 * 10 ** assetDecimals);
    }

    function evaluateSigned(address asset, address denominator, int256 amount) public view returns (int256) {
        if (amount == 0) {
            return 0;
        }
        if (asset == TransferLibrary.ETH) {
            return evaluateSigned(nativeWrapper, denominator, amount);
        }
        if (amount > 0) {
            return int256(evaluate(asset, denominator, uint256(amount)));
        }
        return -int256(evaluate(asset, denominator, uint256(-amount)));
    }

    function tvl(address vault, Data calldata data) public view returns (uint256 value) {
        return tvl(vault, data.denominator);
    }

    function tvl(address vault, address denominator) public view returns (uint256 value) {
        Balance[] memory response = getDistributions(vault, denominator);
        address[] memory tokens = allTokens();
        int256[] memory balances = new int256[](tokens.length);
        for (uint256 i = 0; i < response.length; i++) {
            uint256 index;
            for (uint256 j = 0; j < tokens.length; j++) {
                if (tokens[j] == response[i].asset) {
                    index = j;
                    break;
                }
            }
            balances[index] += response[i].balance;
        }
        int256 signedValue = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            signedValue += evaluateSigned(tokens[i], denominator, balances[i]);
        }
        if (signedValue < 0) {
            return 0;
        }
        value = uint256(signedValue);
    }

    function tvlMultiChain(
        address vault,
        address denominator,
        address[] calldata otherAssets,
        int256[] calldata otherBalances
    ) public view returns (uint256 value) {
        Balance[] memory response = getDistributions(vault, denominator);
        address[] memory tokens = allTokens();
        int256[] memory balances = new int256[](tokens.length);
        for (uint256 i = 0; i < response.length; i++) {
            uint256 index;
            for (uint256 j = 0; j < tokens.length; j++) {
                if (tokens[j] == response[i].asset) {
                    index = j;
                    break;
                }
            }
            balances[index] += response[i].balance;
        }
        int256 signedValue = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            signedValue += evaluateSigned(tokens[i], denominator, balances[i]);
        }
        for (uint256 i = 0; i < otherAssets.length; i++) {
            signedValue += evaluateSigned(otherAssets[i], denominator, otherBalances[i]);
        }
        if (signedValue < 0) {
            return 0;
        }
        value = uint256(signedValue);
    }

    function getDistributions(address vault_, address denominator) public view returns (Balance[] memory response) {
        Vault vault = Vault(payable(vault_));
        uint256 subvaults = vault.subvaults();
        address[] memory vaults = new address[](subvaults + 1);
        for (uint256 i = 0; i < subvaults; i++) {
            vaults[i] = vault.subvaultAt(i);
        }
        vaults[subvaults] = address(vault);

        uint256 iterator = 0;
        (address[] memory protocols, bytes[] memory protocolDeployments, address[] memory assets) = load();
        response = new Balance[](assets.length * vaults.length * 5);
        for (uint256 i = 0; i < protocols.length; i++) {
            for (uint256 j = 0; j < vaults.length; j++) {
                IDistributionCollector.Balance[] memory balances =
                    IDistributionCollector(protocols[i]).getDistributions(vaults[j], protocolDeployments[i], assets);
                for (uint256 k = 0; k < balances.length; k++) {
                    response[iterator] = Balance({
                        asset: balances[k].asset,
                        balance: balances[k].balance,
                        value: 0,
                        metadata: balances[k].metadata,
                        holder: balances[k].holder
                    });
                    if (response[iterator].balance != 0) {
                        response[iterator].value =
                            evaluateSigned(response[iterator].asset, denominator, response[iterator].balance);
                        iterator++;
                    }
                }
            }
        }

        assembly {
            mstore(response, iterator)
        }
    }
}
