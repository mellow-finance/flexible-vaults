// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/external/cowswap/ICowswapSettlement.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../libraries/TransferLibrary.sol";
import "../libraries/external/GPv2Order.sol";
import "../oracles/ConversionOracle.sol";
import "../permissions/MellowACL.sol";

contract SwapModule is MellowACL {
    using SafeERC20 for IERC20;

    error Forbidden(string reason);
    error ZeroValue();

    struct SwapModuleStorage {
        address subvault;
        address oracle;
    }

    struct Params {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
    }

    bytes32 public constant TOKEN_IN_ROLE = keccak256("utils.SwapModule.TOKEN_IN_ROLE");
    bytes32 public constant TOKEN_OUT_ROLE = keccak256("utils.SwapModule.TOKEN_OUT_ROLE");
    bytes32 public constant ROUTER_ROLE = keccak256("utils.SwapModule.ROUTER_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("utils.SwapModule.CALLER_ROLE");

    address public immutable cowswapSettlement;
    address public immutable cowswapVaultRelayer;

    bytes32 private immutable _swapModuleStorageSlot;

    constructor(string memory name_, uint256 version_, address cowswapSettlement_, address cowswapVaultRelayer_)
        MellowACL(name_, version_)
    {
        cowswapSettlement = cowswapSettlement_;
        cowswapVaultRelayer = cowswapVaultRelayer_;
        _swapModuleStorageSlot = SlotLibrary.getSlot("SwapModule", name_, version_);
    }

    // View functions

    modifier onlySubvault() {
        if (_msgSender() != subvault()) {
            revert Forbidden("msg.sender != subvault");
        }
        _;
    }

    function subvault() public view returns (address) {
        return _swapModuleStorage().subvault;
    }

    function oracle() public view returns (address) {
        return _swapModuleStorage().oracle;
    }

    function checkParams(Params calldata params) public view {
        if (!hasRole(TOKEN_IN_ROLE, params.tokenIn)) {
            revert Forbidden("tokenIn");
        }
        if (!hasRole(TOKEN_OUT_ROLE, params.tokenOut)) {
            revert Forbidden("tokenOut");
        }
        if (TransferLibrary.balanceOf(params.tokenIn, address(this)) < params.amountIn || params.amountIn == 0) {
            revert Forbidden("amountIn");
        }
        uint256 oracleMinAmount = ConversionOracle(oracle()).evaluate(params.tokenIn, params.tokenOut, params.amountIn);
        if (params.minAmountOut < oracleMinAmount) {
            revert Forbidden("minAmountOut < oracleMinAmount");
        }
        if (params.deadline < block.timestamp) {
            revert Forbidden("deadline");
        }
        if (params.tokenIn == params.tokenOut) {
            revert Forbidden("tokenIn == tokenOut");
        }
    }

    function checkCowswapOrder(Params calldata params, GPv2Order.Data calldata order, bytes calldata orderUid)
        public
        view
    {
        if (params.tokenIn != address(order.sellToken)) {
            revert Forbidden("tokenIn != sellToken");
        }
        if (params.tokenOut != address(order.buyToken)) {
            revert Forbidden("tokenOut != buyToken");
        }
        if (address(this) != order.receiver) {
            revert Forbidden("receiver");
        }
        if (params.amountIn != order.sellAmount) {
            revert Forbidden("amountIn != sellAmount");
        }
        if (params.minAmountOut != order.buyAmount) {
            revert Forbidden("minAmountOut != buyAmount");
        }
        if (params.deadline != order.validTo) {
            revert Forbidden("deadline != validTo");
        }
        if (order.kind != GPv2Order.KIND_SELL) {
            revert Forbidden("kind != KIND_SELL");
        }
        if (order.sellTokenBalance != GPv2Order.BALANCE_ERC20) {
            revert Forbidden("sellTokenBalance != BALANCE_ERC20");
        }
        if (order.buyTokenBalance != GPv2Order.BALANCE_ERC20) {
            revert Forbidden("buyTokenBalance != BALANCE_ERC20");
        }

        bytes memory calculatedOrderUid = new bytes(56);
        GPv2Order.packOrderUidParams(
            calculatedOrderUid,
            GPv2Order.hash(order, ICowswapSettlement(cowswapSettlement).domainSeparator()),
            address(this),
            order.validTo
        );
        if (keccak256(orderUid) != keccak256(calculatedOrderUid)) {
            revert Forbidden("orderUid != calculatedOrderUid");
        }
    }

    // Mutable functions

    function initialize(bytes calldata data) external initializer {
        (address admin, address subvault_, address oracle_, address[] memory holders, bytes32[] memory roles) =
            abi.decode(data, (address, address, address, address[], bytes32[]));
        if (admin == address(0) || subvault_ == address(0) || oracle_ == address(0)) {
            revert ZeroValue();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _swapModuleStorage().subvault = subvault_;
        _swapModuleStorage().oracle = oracle_;
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == address(0) || roles[i] == bytes32(0)) {
                revert ZeroValue();
            }
            _grantRole(roles[i], holders[i]);
        }
    }

    function pushAssets(address asset, uint256 amount) external payable onlySubvault {
        TransferLibrary.receiveAssets(asset, _msgSender(), amount);
    }

    function pullAssets(address asset, uint256 amount) external onlySubvault {
        TransferLibrary.sendAssets(asset, _msgSender(), amount);
    }

    // onchain swap via whitelisted router
    function swap(Params calldata params, address router, bytes calldata data)
        external
        onlyRole(CALLER_ROLE)
        returns (bytes memory response)
    {
        checkParams(params);
        if (!hasRole(ROUTER_ROLE, router)) {
            revert Forbidden("router");
        }
        uint256 balanceBefore = TransferLibrary.balanceOf(params.tokenOut, address(this));
        if (params.tokenIn != TransferLibrary.ETH) {
            IERC20(params.tokenIn).forceApprove(router, params.amountIn);
            response = Address.functionCall(router, data);
            IERC20(params.tokenIn).forceApprove(router, 0);
        } else {
            response = Address.functionCallWithValue(router, data, params.amountIn);
        }
        uint256 amountOut = TransferLibrary.balanceOf(params.tokenOut, address(this)) - balanceBefore;
        if (amountOut < params.minAmountOut) {
            revert Forbidden("amountOut < minAmountOut");
        }
    }

    function setCowswapApproval(address asset, uint256 amount) external onlyRole(CALLER_ROLE) {
        if (!hasRole(TOKEN_IN_ROLE, asset)) {
            revert Forbidden("asset");
        }
        IERC20(asset).forceApprove(cowswapVaultRelayer, amount);
    }

    function createLimitOrder(Params calldata params, GPv2Order.Data calldata order, bytes calldata orderUid)
        external
        onlyRole(CALLER_ROLE)
    {
        checkParams(params);
        checkCowswapOrder(params, order, orderUid);
        ICowswapSettlement(cowswapSettlement).setPreSignature(orderUid, true);
    }

    function cancelLimitOrder(bytes calldata orderUid) external onlyRole(CALLER_ROLE) {
        ICowswapSettlement(cowswapSettlement).invalidateOrder(orderUid);
    }

    receive() external payable {}

    // Internal functions

    function _swapModuleStorage() internal view returns (SwapModuleStorage storage $) {
        bytes32 slot = _swapModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
