// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/ISwapModule.sol";

import "../libraries/TransferLibrary.sol";
import "../permissions/MellowACL.sol";

contract SwapModule is ISwapModule, MellowACL {
    using SafeERC20 for IERC20;

    /// @inheritdoc ISwapModule
    uint256 public constant MIN_MULTIPLIER = 0.9e8;
    /// @inheritdoc ISwapModule
    uint256 public constant MAX_MULTIPLIER = 1.1e8;
    /// @inheritdoc ISwapModule
    uint256 public constant BASE_MULTIPLIER = 1e8;

    /// @inheritdoc ISwapModule
    bytes32 public constant TOKEN_IN_ROLE = keccak256("utils.SwapModule.TOKEN_IN_ROLE");
    /// @inheritdoc ISwapModule
    bytes32 public constant TOKEN_OUT_ROLE = keccak256("utils.SwapModule.TOKEN_OUT_ROLE");
    /// @inheritdoc ISwapModule
    bytes32 public constant ROUTER_ROLE = keccak256("utils.SwapModule.ROUTER_ROLE");
    /// @inheritdoc ISwapModule
    bytes32 public constant CALLER_ROLE = keccak256("utils.SwapModule.CALLER_ROLE");
    /// @inheritdoc ISwapModule
    bytes32 public constant SET_SLIPPAGE_ROLE = keccak256("utils.SwapModule.SET_SLIPPAGE_ROLE");

    /// @inheritdoc ISwapModule
    address public immutable cowswapSettlement;
    /// @inheritdoc ISwapModule
    address public immutable cowswapVaultRelayer;
    /// @inheritdoc ISwapModule
    address public immutable weth;

    bytes32 private immutable _swapModuleStorageSlot;

    constructor(
        string memory name_,
        uint256 version_,
        address cowswapSettlement_,
        address cowswapVaultRelayer_,
        address weth_
    ) MellowACL(name_, version_) {
        cowswapSettlement = cowswapSettlement_;
        cowswapVaultRelayer = cowswapVaultRelayer_;
        weth = weth_;
        _swapModuleStorageSlot = SlotLibrary.getSlot("SwapModule", name_, version_);
    }

    // View functions

    modifier onlySubvault() {
        if (_msgSender() != subvault()) {
            revert Forbidden("msg.sender != subvault");
        }
        _;
    }

    /// @inheritdoc ISwapModule
    function subvault() public view returns (address) {
        return _swapModuleStorage().subvault;
    }

    /// @inheritdoc ISwapModule
    function oracle() public view returns (address) {
        return _swapModuleStorage().oracle;
    }

    /// @inheritdoc ISwapModule
    function checkMultiplier(uint256 multiplier) public pure {
        if (multiplier < MIN_MULTIPLIER || multiplier > MAX_MULTIPLIER) {
            revert Forbidden("multiplier out of expected range");
        }
    }

    /// @inheritdoc ISwapModule
    function defaultMultiplier() public view returns (uint256) {
        return _swapModuleStorage().defaultMultiplier;
    }

    /// @inheritdoc ISwapModule
    function customMultiplier(address tokenIn, address tokenOut) public view returns (uint256) {
        return _swapModuleStorage().customMultiplier[tokenIn][tokenOut];
    }

    /// @inheritdoc ISwapModule
    function evaluate(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {
        IAaveOracle oracle_ = IAaveOracle(oracle());
        return Math.mulDiv(
            amountIn,
            oracle_.getAssetPrice(tokenIn == TransferLibrary.ETH ? weth : tokenIn),
            oracle_.getAssetPrice(tokenOut == TransferLibrary.ETH ? weth : tokenOut)
        );
    }

    /// @inheritdoc ISwapModule
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
        SwapModuleStorage storage $ = _swapModuleStorage();
        uint256 multiplier = $.customMultiplier[params.tokenIn][params.tokenOut];
        if (multiplier == 0) {
            multiplier = $.defaultMultiplier;
        }
        uint256 oracleMinAmount =
            Math.mulDiv(evaluate(params.tokenIn, params.tokenOut, params.amountIn), multiplier, BASE_MULTIPLIER);

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

    /// @inheritdoc ISwapModule
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
            GPv2Order.hash(order, GPv2Settlement(payable(cowswapSettlement)).domainSeparator()),
            address(this),
            order.validTo
        );
        if (keccak256(orderUid) != keccak256(calculatedOrderUid)) {
            revert Forbidden("orderUid != calculatedOrderUid");
        }
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        (
            address admin,
            address subvault_,
            address oracle_,
            uint256 defaultMultiplier_,
            address[] memory holders,
            bytes32[] memory roles
        ) = abi.decode(data, (address, address, address, uint256, address[], bytes32[]));
        if (admin == address(0) || subvault_ == address(0) || oracle_ == address(0)) {
            revert ZeroValue();
        }
        checkMultiplier(defaultMultiplier_);
        SwapModuleStorage storage $ = _swapModuleStorage();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        $.subvault = subvault_;
        $.oracle = oracle_;
        $.defaultMultiplier = defaultMultiplier_;
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == address(0) || roles[i] == bytes32(0)) {
                revert ZeroValue();
            }
            _grantRole(roles[i], holders[i]);
        }
        emit Initialized(data);
    }

    /// @inheritdoc ISwapModule
    function setOracle(address oracle_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (oracle_ == address(0)) {
            revert ZeroValue();
        }
        _swapModuleStorage().oracle = oracle_;
        emit OracleSet(oracle_);
    }

    /// @inheritdoc ISwapModule
    function setDefaultMultiplier(uint256 multiplier) external onlyRole(SET_SLIPPAGE_ROLE) {
        checkMultiplier(multiplier);
        _swapModuleStorage().defaultMultiplier = multiplier;
        emit DefaultMultiplierSet(multiplier);
    }

    /// @inheritdoc ISwapModule
    function setCustomMultiplier(address tokenIn, address tokenOut, uint256 multiplier)
        external
        onlyRole(SET_SLIPPAGE_ROLE)
    {
        checkMultiplier(multiplier);
        _swapModuleStorage().customMultiplier[tokenIn][tokenOut] = multiplier;
        emit CustomMultiplierSet(tokenIn, tokenOut, multiplier);
    }

    /// @inheritdoc ISwapModule
    function pushAssets(address asset, uint256 amount) external payable onlySubvault {
        TransferLibrary.receiveAssets(asset, _msgSender(), amount);
    }

    /// @inheritdoc ISwapModule
    function pullAssets(address asset, uint256 amount) external onlySubvault {
        TransferLibrary.sendAssets(asset, _msgSender(), amount);
    }

    /// @inheritdoc ISwapModule
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
        emit Swap(params, router, amountOut);
    }

    /// @inheritdoc ISwapModule
    function setCowswapApproval(address asset, uint256 amount) external onlyRole(CALLER_ROLE) {
        if (!hasRole(TOKEN_IN_ROLE, asset)) {
            revert Forbidden("asset");
        }
        IERC20(asset).forceApprove(cowswapVaultRelayer, amount);
        emit CowswapApprovalSet(asset, amount);
    }

    /// @inheritdoc ISwapModule
    function createLimitOrder(Params calldata params, GPv2Order.Data calldata order, bytes calldata orderUid)
        external
        onlyRole(CALLER_ROLE)
    {
        checkParams(params);
        checkCowswapOrder(params, order, orderUid);
        GPv2Settlement(payable(cowswapSettlement)).setPreSignature(orderUid, true);
        emit LimitOrderCreated(params, orderUid);
    }

    /// @inheritdoc ISwapModule
    function invalidateOrder(bytes calldata orderUid) external onlyRole(CALLER_ROLE) {
        GPv2Settlement(payable(cowswapSettlement)).invalidateOrder(orderUid);
        emit LimitOrderInvalidated(orderUid);
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
