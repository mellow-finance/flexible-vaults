// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../external/aave/IAaveOracle.sol";
import "../external/cowswap/ICowswapSettlement.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../libraries/external/GPv2Order.sol";

import "../factories/IFactoryEntity.sol";

interface ISwapModule is IFactoryEntity {
    // Errors

    error Forbidden(string reason);
    error ZeroValue();

    // Structs

    struct SwapModuleStorage {
        address subvault;
        address oracle;
        uint256 defaultMultiplier;
        mapping(address => mapping(address => uint256)) customMultiplier;
    }

    struct Params {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
    }

    // View functions

    function MIN_MULTIPLIER() external view returns (uint256);
    function MAX_MULTIPLIER() external view returns (uint256);
    function BASE_MULTIPLIER() external view returns (uint256);

    function TOKEN_IN_ROLE() external view returns (bytes32);
    function TOKEN_OUT_ROLE() external view returns (bytes32);
    function ROUTER_ROLE() external view returns (bytes32);
    function CALLER_ROLE() external view returns (bytes32);
    function SET_SLIPPAGE_ROLE() external view returns (bytes32);

    function cowswapSettlement() external view returns (address);
    function cowswapVaultRelayer() external view returns (address);
    function weth() external view returns (address);

    function subvault() external view returns (address);

    function oracle() external view returns (address);

    function checkMultiplier(uint256 multiplier) external pure;

    function defaultMultiplier() external view returns (uint256);

    function customMultiplier(address tokenIn, address tokenOut) external view returns (uint256);

    function evaluate(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256);

    function checkParams(Params calldata params) external view;

    function checkCowswapOrder(Params calldata params, GPv2Order.Data calldata order, bytes calldata orderUid)
        external
        view;

    // Mutable functions

    function setOracle(address oracle_) external;

    function setDefaultMultiplier(uint256 multiplier) external;

    function setCustomMultiplier(address tokenIn, address tokenOut, uint256 multiplier) external;

    function pushAssets(address asset, uint256 amount) external payable;

    function pullAssets(address asset, uint256 amount) external;

    function swap(Params calldata params, address router, bytes calldata data)
        external
        returns (bytes memory response);

    function setCowswapApproval(address asset, uint256 amount) external;

    function createLimitOrder(Params calldata params, GPv2Order.Data calldata order, bytes calldata orderUid)
        external;

    function invalidateOrder(bytes calldata orderUid) external;

    // Events

    event DefaultMultiplierSet(uint256 indexed multiplier);

    event CustomMultiplierSet(address indexed tokenIn, address indexed tokenOut, uint256 indexed multiplier);

    event CowswapApprovalSet(address indexed asset, uint256 amount);

    event LimitOrderCreated(Params params, bytes orderUid);

    event LimitOrderInvalidated(bytes orderUid);

    event Swap(Params params, address router, uint256 amountOut);

    event OracleSet(address indexed oracle);
}
