// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/vaults/Vault.sol";
import "./ICustomOracle.sol";
import "./external/IAaveOracleV3.sol";
import "./external/IAavePoolV3.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract StrETHOracle is ICustomOracle {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

    address public constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address public constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

    IAavePoolV3 public constant AAVE_CORE = IAavePoolV3(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IAavePoolV3 public constant AAVE_PRIME = IAavePoolV3(0x4e033931ad43597d96D6bcc25c280717730B58B1);
    IAaveOracleV3 public constant AAVE_ORACLE = IAaveOracleV3(0x54586bE62E3c3580375aE3723C145253060Ca0C2);

    struct Balance {
        address subvault;
        address asset;
        int256 balance;
        string metadata;
    }

    function getAaveBalances(address token, address vault, IAavePoolV3 instance)
        public
        view
        returns (uint256 collateral, uint256 debt)
    {
        if (token == ETH) {
            return (0, 0);
        }

        IAavePoolV3.ReserveDataLegacy memory data;
        data = instance.getReserveData(token);
        if (data.aTokenAddress != address(0)) {
            collateral = IERC20(data.aTokenAddress).balanceOf(vault);
        }
        if (data.variableDebtTokenAddress != address(0)) {
            debt = IERC20(data.variableDebtTokenAddress).balanceOf(vault);
        }
    }

    function allTokens() public pure returns (address[] memory tokens) {
        address[8] memory tokens_ = [ETH, WETH, WSTETH, USDC, USDT, USDS, USDE, SUSDE];
        tokens = new address[](tokens_.length);
        for (uint256 i = 0; i < tokens_.length; i++) {
            tokens[i] = tokens_[i];
        }
    }

    function evaluate(address asset, address denominator, uint256 amount) public view returns (uint256) {
        if (asset == denominator) {
            return amount;
        }
        uint256 assetPriceD8 = AAVE_ORACLE.getAssetPrice(asset);
        uint8 assetDecimals = IERC20Metadata(asset).decimals();
        uint256 denominatorPriceD8 = AAVE_ORACLE.getAssetPrice(denominator);
        uint8 denominatorDecimals = IERC20Metadata(asset).decimals();
        return Math.mulDiv(amount, assetPriceD8 * 10 ** denominatorDecimals, denominatorPriceD8 * 10 ** assetDecimals);
    }

    function evaluateSigned(address asset, address denominator, int256 amount) public view returns (int256) {
        if (amount == 0) {
            return 0;
        }
        if (asset == ETH) {
            return evaluateSigned(WETH, denominator, amount);
        }
        if (amount > 0) {
            return int256(evaluate(asset, denominator, uint256(amount)));
        }
        return -int256(evaluate(asset, denominator, uint256(-amount)));
    }

    function tvl(address vault, Data calldata data) public view returns (uint256 value) {
        Balance[] memory response = getDistributions(Vault(payable(vault)));
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
            signedValue += evaluateSigned(tokens[i], data.denominator, balances[i]);
        }
        if (signedValue < 0) {
            return 0;
        }
        value = uint256(signedValue);
    }

    function getDistributions(Vault vault) public view returns (Balance[] memory response) {
        uint256 subvaults = vault.subvaults();
        address[] memory vaults = new address[](subvaults + 1);
        for (uint256 i = 0; i < subvaults; i++) {
            vaults[i] = vault.subvaultAt(i);
        }
        vaults[subvaults] = address(vault);

        address[] memory tokens = allTokens();

        response = new Balance[](tokens.length * 5);
        uint256 iterator = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = 0; j < vaults.length; j++) {
                // ERC20
                {
                    uint256 balance = TransferLibrary.balanceOf(tokens[i], vaults[j]);
                    if (balance != 0) {
                        response[iterator++] = Balance({subvault: vaults[j], asset: tokens[i], balance: int256(balance), metadata: "ERC20"});
                    }
                }
                // AaveCore
                {
                    (uint256 collateral, uint256 debt) = getAaveBalances(tokens[i], vaults[j], AAVE_CORE);
                    if (collateral != 0) {
                        response[iterator++] = Balance({subvault: vaults[j], asset: tokens[i], balance: int256(collateral), metadata: "AaveCoreCollateral"});
                    }
                    if (debt != 0) {
                        response[iterator++] = Balance({subvault: vaults[j], asset: tokens[i], balance: -int256(debt), metadata: "AaveCoreDebt"});
                    }
                }
                // AavePrime
                {
                    (uint256 collateral, uint256 debt) = getAaveBalances(tokens[i], vaults[j], AAVE_PRIME);
                    if (collateral != 0) {
                        response[iterator++] = Balance({subvault: vaults[j], asset: tokens[i], balance: int256(collateral), metadata: "AavePrimeCollateral"});
                    }
                    if (debt != 0) {
                        response[iterator++] = Balance({subvault: vaults[j], asset: tokens[i], balance: -int256(debt), metadata: "AavePrimeDebt"});
                    }
                }
            }
        }

        assembly {
            mstore(response, iterator)
        }
    }
}
