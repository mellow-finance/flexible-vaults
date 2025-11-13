// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20 as ERC20Interface} from "@cowswap/contracts/interfaces/IERC20.sol";

import "../../../scripts/common/ArraysLibrary.sol";
import "../../Imports.sol";

interface IUniswapV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface WETHInterface {
    function deposit() external payable;
}

contract SwapModuleTest is Test {
    bytes32 constant WILDCARD_MASK = bytes32(0);

    address admin = vm.createWallet("admin").addr;
    address caller = vm.createWallet("caller").addr;
    address subvault = vm.createWallet("subvault").addr;

    address public constant COWSWAP_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address public constant COWSWAP_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address public constant AAVE_V3_ORACLE = 0x54586bE62E3c3580375aE3723C145253060Ca0C2;

    address public constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    SwapModule public swapModule;

    function setUp() public {
        swapModule = new SwapModule("Mellow", 1, COWSWAP_SETTLEMENT, COWSWAP_VAULT_RELAYER, WETH);
    }

    function testConstructor_NO_CI() external view {
        assertNotEq(address(swapModule), address(0));
        assertEq(address(swapModule.cowswapSettlement()), COWSWAP_SETTLEMENT);
        assertEq(address(swapModule.cowswapVaultRelayer()), COWSWAP_VAULT_RELAYER);
        assertEq(address(swapModule.weth()), WETH);

        assertEq(address(swapModule.oracle()), address(0));
        assertEq(address(swapModule.subvault()), address(0));
        assertEq(swapModule.defaultMultiplier(), 0);
        assertEq(swapModule.customMultiplier(WETH, WETH), 0);
    }

    function getInitParams() public view returns (bytes memory) {
        return abi.encode(
            admin,
            subvault,
            AAVE_V3_ORACLE,
            0.99e8,
            ArraysLibrary.makeAddressArray(
                abi.encode(admin, UNISWAP_V3_ROUTER, caller, ETH, ETH, WETH, WETH, WSTETH, WSTETH, USDC, USDT)
            ),
            ArraysLibrary.makeBytes32Array(
                abi.encode(
                    swapModule.SET_SLIPPAGE_ROLE(),
                    swapModule.ROUTER_ROLE(),
                    swapModule.CALLER_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE()
                )
            )
        );
    }

    function testInitializer_NO_CI() external {
        vm.expectRevert();
        swapModule.initialize(new bytes(0));

        bytes memory data = getInitParams();

        vm.expectRevert();
        swapModule.initialize(data);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(swapModule), admin, new bytes(0));

        SwapModule module = SwapModule(payable(proxy));

        bytes memory initParams = abi.encode(
            address(0),
            subvault,
            AAVE_V3_ORACLE,
            0.99e8,
            ArraysLibrary.makeAddressArray(
                abi.encode(admin, UNISWAP_V3_ROUTER, caller, ETH, ETH, WETH, WETH, WSTETH, WSTETH, USDC, USDT)
            ),
            ArraysLibrary.makeBytes32Array(
                abi.encode(
                    swapModule.SET_SLIPPAGE_ROLE(),
                    swapModule.ROUTER_ROLE(),
                    swapModule.CALLER_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE()
                )
            )
        );

        vm.expectRevert();
        module.initialize(initParams);

        initParams = abi.encode(
            admin,
            address(0),
            AAVE_V3_ORACLE,
            0.99e8,
            ArraysLibrary.makeAddressArray(
                abi.encode(admin, UNISWAP_V3_ROUTER, caller, ETH, ETH, WETH, WETH, WSTETH, WSTETH, USDC, USDT)
            ),
            ArraysLibrary.makeBytes32Array(
                abi.encode(
                    swapModule.SET_SLIPPAGE_ROLE(),
                    swapModule.ROUTER_ROLE(),
                    swapModule.CALLER_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE()
                )
            )
        );

        vm.expectRevert();
        module.initialize(initParams);

        initParams = abi.encode(
            admin,
            subvault,
            address(0),
            0.99e8,
            ArraysLibrary.makeAddressArray(
                abi.encode(admin, UNISWAP_V3_ROUTER, caller, ETH, ETH, WETH, WETH, WSTETH, WSTETH, USDC, USDT)
            ),
            ArraysLibrary.makeBytes32Array(
                abi.encode(
                    swapModule.SET_SLIPPAGE_ROLE(),
                    swapModule.ROUTER_ROLE(),
                    swapModule.CALLER_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE()
                )
            )
        );

        vm.expectRevert();
        module.initialize(initParams);

        initParams = abi.encode(
            admin,
            subvault,
            AAVE_V3_ORACLE,
            0.99e8,
            ArraysLibrary.makeAddressArray(
                abi.encode(admin, UNISWAP_V3_ROUTER, caller, ETH, ETH, WETH, WETH, WSTETH, WSTETH, USDC, USDT)
            ),
            ArraysLibrary.makeBytes32Array(
                abi.encode(
                    swapModule.DEFAULT_ADMIN_ROLE(),
                    swapModule.ROUTER_ROLE(),
                    swapModule.CALLER_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE()
                )
            )
        );

        vm.expectRevert();
        module.initialize(initParams);

        initParams = abi.encode(
            admin,
            subvault,
            AAVE_V3_ORACLE,
            0.99e8,
            ArraysLibrary.makeAddressArray(
                abi.encode(address(0), UNISWAP_V3_ROUTER, caller, ETH, ETH, WETH, WETH, WSTETH, WSTETH, USDC, USDT)
            ),
            ArraysLibrary.makeBytes32Array(
                abi.encode(
                    swapModule.SET_SLIPPAGE_ROLE(),
                    swapModule.ROUTER_ROLE(),
                    swapModule.CALLER_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE(),
                    swapModule.TOKEN_IN_ROLE(),
                    swapModule.TOKEN_OUT_ROLE()
                )
            )
        );

        vm.expectRevert();
        module.initialize(initParams);

        module.initialize(data);

        assertTrue(module.hasRole(module.SET_SLIPPAGE_ROLE(), admin));
        assertTrue(module.hasRole(module.ROUTER_ROLE(), UNISWAP_V3_ROUTER));

        assertTrue(module.hasRole(module.CALLER_ROLE(), caller));

        assertTrue(module.hasRole(module.TOKEN_IN_ROLE(), ETH));
        assertTrue(module.hasRole(module.TOKEN_IN_ROLE(), WETH));
        assertTrue(module.hasRole(module.TOKEN_IN_ROLE(), WSTETH));
        assertTrue(module.hasRole(module.TOKEN_IN_ROLE(), USDC));

        assertTrue(module.hasRole(module.TOKEN_OUT_ROLE(), ETH));
        assertTrue(module.hasRole(module.TOKEN_OUT_ROLE(), WETH));
        assertTrue(module.hasRole(module.TOKEN_OUT_ROLE(), WSTETH));
        assertTrue(module.hasRole(module.TOKEN_OUT_ROLE(), USDT));
    }

    function testSingleSwap_USDC_USDT_NO_CI() external {
        vm.expectRevert();
        swapModule.initialize(new bytes(0));

        bytes memory data = getInitParams();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(swapModule), admin, new bytes(0));

        SwapModule module = SwapModule(payable(proxy));

        module.initialize(data);

        deal(USDC, subvault, 100e6); // 100$

        assertEq(IERC20(USDC).balanceOf(subvault), 100e6);
        assertEq(IERC20(USDC).balanceOf(address(module)), 0);

        vm.expectRevert();
        module.pushAssets(USDC, 100e6);

        vm.startPrank(subvault);

        IERC20(USDC).approve(address(module), type(uint256).max);
        module.pushAssets(USDC, 100e6);

        assertEq(IERC20(USDC).balanceOf(subvault), 0);
        assertEq(IERC20(USDC).balanceOf(address(module)), 100e6);

        vm.stopPrank();

        vm.startPrank(caller);

        ISwapModule.Params memory swapParams = ISwapModule.Params({
            tokenIn: USDC,
            tokenOut: USDT,
            amountIn: 100e6,
            minAmountOut: 99e6,
            deadline: block.timestamp
        });

        bytes memory routerData = abi.encodeCall(
            IUniswapV3Router.exactInputSingle,
            (
                IUniswapV3Router.ExactInputSingleParams({
                    tokenIn: USDC,
                    tokenOut: USDT,
                    fee: 100,
                    recipient: address(module),
                    deadline: block.timestamp,
                    amountIn: 100e6,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            )
        );

        swapParams.minAmountOut = 100e6;

        vm.expectRevert();
        module.swap(swapParams, UNISWAP_V3_ROUTER, routerData);

        swapParams.minAmountOut = 99e6;
        vm.stopPrank();

        vm.expectRevert();
        module.swap(swapParams, UNISWAP_V3_ROUTER, routerData);

        vm.startPrank(caller);

        vm.expectRevert();
        module.swap(swapParams, address(0xdead), routerData);

        swapParams.tokenIn = address(0xdead);

        vm.expectRevert();
        module.checkParams(swapParams);

        vm.expectRevert();
        module.swap(swapParams, UNISWAP_V3_ROUTER, routerData);
        swapParams.tokenIn = USDC;

        swapParams.tokenOut = address(0xdead);

        vm.expectRevert();
        module.checkParams(swapParams);
        vm.expectRevert();
        module.swap(swapParams, UNISWAP_V3_ROUTER, routerData);
        swapParams.tokenOut = USDT;

        swapParams.amountIn = 200e6;

        vm.expectRevert();
        module.checkParams(swapParams);
        vm.expectRevert();
        module.swap(swapParams, UNISWAP_V3_ROUTER, routerData);
        swapParams.amountIn = 100e6;

        swapParams.minAmountOut = 50e6;

        vm.expectRevert();
        module.checkParams(swapParams);
        vm.expectRevert();
        module.swap(swapParams, UNISWAP_V3_ROUTER, routerData);
        swapParams.minAmountOut = 99e6;

        swapParams.deadline = block.timestamp - 1;

        vm.expectRevert();
        module.checkParams(swapParams);
        vm.expectRevert();
        module.swap(swapParams, UNISWAP_V3_ROUTER, routerData);
        swapParams.deadline = block.timestamp;

        deal(address(module), 100 ether);

        swapParams.tokenIn = ETH;
        swapParams.tokenOut = ETH;

        vm.expectRevert();
        module.checkParams(swapParams);

        vm.expectRevert();
        module.swap(swapParams, UNISWAP_V3_ROUTER, routerData);
        swapParams.tokenIn = USDC;
        swapParams.tokenOut = USDT;

        bytes memory response = module.swap(swapParams, UNISWAP_V3_ROUTER, routerData);

        uint256 amountOut = abi.decode(response, (uint256));

        assertEq(IERC20(USDC).balanceOf(subvault), 0);
        assertEq(IERC20(USDC).balanceOf(address(module)), 0);
        assertEq(IERC20(USDT).balanceOf(address(module)), amountOut);
        vm.stopPrank();

        vm.startPrank(subvault);
        module.pullAssets(USDT, amountOut);

        assertEq(IERC20(USDC).balanceOf(subvault), 0);
        assertEq(IERC20(USDC).balanceOf(address(module)), 0);
        assertEq(IERC20(USDT).balanceOf(address(module)), 0);
        assertEq(IERC20(USDT).balanceOf(subvault), amountOut);
        vm.stopPrank();
    }

    function testSingleSwap_ETH_WETH_NO_CI() external {
        vm.expectRevert();
        swapModule.initialize(new bytes(0));

        bytes memory data = getInitParams();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(swapModule), admin, new bytes(0));

        SwapModule module = SwapModule(payable(proxy));

        module.initialize(data);

        vm.startPrank(admin);
        module.grantRole(module.ROUTER_ROLE(), WETH);
        vm.stopPrank();

        vm.startPrank(caller);
        deal(address(module), 100 ether);

        ISwapModule.Params memory swapParams = ISwapModule.Params({
            tokenIn: ETH,
            tokenOut: WETH,
            amountIn: 100 ether,
            minAmountOut: 100 ether,
            deadline: block.timestamp
        });

        module.swap(swapParams, WETH, abi.encodeCall(WETHInterface.deposit, ()));

        vm.stopPrank();
    }

    function testSingleSwap_WETH_USDT_NO_CI() external {
        vm.expectRevert();
        swapModule.initialize(new bytes(0));

        bytes memory data = getInitParams();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(swapModule), admin, new bytes(0));

        SwapModule module = SwapModule(payable(proxy));

        module.initialize(data);

        vm.startPrank(caller);
        deal(WETH, address(module), 100 ether);

        ISwapModule.Params memory swapParams = ISwapModule.Params({
            tokenIn: WETH,
            tokenOut: USDT,
            amountIn: 100 ether,
            minAmountOut: 403900e6,
            deadline: block.timestamp
        });

        bytes memory routerData = abi.encodeCall(
            IUniswapV3Router.exactInputSingle,
            (
                IUniswapV3Router.ExactInputSingleParams({
                    tokenIn: WETH,
                    tokenOut: USDT,
                    fee: 500,
                    recipient: address(module),
                    deadline: block.timestamp,
                    amountIn: 100 ether,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            )
        );

        vm.expectRevert();
        module.swap(swapParams, UNISWAP_V3_ROUTER, routerData);
        swapParams.minAmountOut = 4008e8;
        uint256 amountOut = abi.decode(module.swap(swapParams, UNISWAP_V3_ROUTER, routerData), (uint256));

        assertEq(IERC20(USDT).balanceOf(address(module)), amountOut);
        vm.stopPrank();
    }

    function testSingleSwap_USDC_WETH_NO_CI() external {
        vm.expectRevert();
        swapModule.initialize(new bytes(0));

        bytes memory data = getInitParams();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(swapModule), admin, new bytes(0));

        SwapModule module = SwapModule(payable(proxy));

        module.initialize(data);

        vm.startPrank(caller);
        uint256 amountIn = 1e12;
        deal(USDC, address(module), amountIn);

        ISwapModule.Params memory swapParams = ISwapModule.Params({
            tokenIn: USDC,
            tokenOut: WETH,
            amountIn: amountIn,
            minAmountOut: 247.508 ether,
            deadline: block.timestamp
        });

        bytes memory routerData = abi.encodeCall(
            IUniswapV3Router.exactInputSingle,
            (
                IUniswapV3Router.ExactInputSingleParams({
                    tokenIn: USDC,
                    tokenOut: WETH,
                    fee: 500,
                    recipient: address(module),
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            )
        );

        vm.expectRevert();
        module.swap(swapParams, UNISWAP_V3_ROUTER, routerData);

        swapParams.minAmountOut = 245.12 ether;
        uint256 amountOut = abi.decode(module.swap(swapParams, UNISWAP_V3_ROUTER, routerData), (uint256));

        assertEq(IERC20(WETH).balanceOf(address(module)), amountOut);
        vm.stopPrank();
    }

    function testSetters_NO_CI() external {
        vm.expectRevert();
        swapModule.initialize(new bytes(0));

        bytes memory data = getInitParams();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(swapModule), admin, new bytes(0));

        SwapModule module = SwapModule(payable(proxy));

        module.initialize(data);
        vm.startPrank(admin);

        uint256 minMultiplier = module.MIN_MULTIPLIER();
        uint256 maxMultiplier = module.MAX_MULTIPLIER();

        vm.expectRevert();
        module.checkMultiplier(minMultiplier - 1);
        vm.expectRevert();
        module.checkMultiplier(maxMultiplier + 1);

        assertLt(minMultiplier, maxMultiplier);

        module.setDefaultMultiplier(1.1e8);
        assertEq(module.defaultMultiplier(), 1.1e8);

        module.setCustomMultiplier(USDC, USDT, 0.999e8);
        assertEq(module.customMultiplier(USDC, USDT), 0.999e8);

        assertGe(module.evaluate(USDC, USDT, 1e6), 0.998e6);
        assertLe(module.evaluate(USDC, USDT, 1e6), 1e6);

        vm.expectRevert();
        module.setOracle(address(0));

        module.setOracle(address(0xdead));
        module.setOracle(AAVE_V3_ORACLE);

        vm.stopPrank();
    }

    function testCheckCowswapOrder_NO_CI() external {
        SwapModule module = SwapModule(
            payable(
                new TransparentUpgradeableProxy(
                    address(swapModule), admin, abi.encodeCall(IFactoryEntity.initialize, getInitParams())
                )
            )
        );

        uint256 amountIn = 1000000e6;
        uint256 minAmountOut = 247.508 ether;

        ISwapModule.Params memory params = ISwapModule.Params({
            tokenIn: USDC,
            tokenOut: WETH,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            deadline: block.timestamp
        });

        GPv2Order.Data memory order = GPv2Order.Data({
            sellToken: ERC20Interface(USDC),
            buyToken: ERC20Interface(WETH),
            receiver: address(module),
            sellAmount: amountIn,
            buyAmount: minAmountOut,
            validTo: uint32(block.timestamp),
            appData: bytes32(0),
            feeAmount: 0,
            kind: GPv2Order.KIND_SELL,
            partiallyFillable: true,
            sellTokenBalance: GPv2Order.BALANCE_ERC20,
            buyTokenBalance: GPv2Order.BALANCE_ERC20
        });

        bytes memory orderUid = new bytes(56);
        GPv2Order.packOrderUidParams(
            orderUid,
            GPv2Order.hash(order, GPv2Settlement(payable(module.cowswapSettlement())).domainSeparator()),
            address(module),
            uint32(block.timestamp)
        );

        module.checkCowswapOrder(params, order, orderUid);

        params.tokenIn = address(0xdead);
        vm.expectRevert();
        module.checkCowswapOrder(params, order, orderUid);

        params.tokenIn = TransferLibrary.ETH;
        order.sellToken = ERC20Interface(TransferLibrary.ETH);

        vm.expectRevert();
        module.checkCowswapOrder(params, order, orderUid);

        params.tokenIn = USDC;
        order.sellToken = ERC20Interface(USDC);

        params.tokenOut = address(0xdead);

        vm.expectRevert();
        module.checkCowswapOrder(params, order, orderUid);

        params.tokenOut = TransferLibrary.ETH;
        order.buyToken = ERC20Interface(TransferLibrary.ETH);

        vm.expectRevert();
        module.checkCowswapOrder(params, order, orderUid);

        params.tokenOut = WETH;
        order.buyToken = ERC20Interface(WETH);

        order.receiver = address(0xdead);

        vm.expectRevert();
        module.checkCowswapOrder(params, order, orderUid);

        order.receiver = address(module);
        params.amountIn = order.sellAmount + 1;

        vm.expectRevert();
        module.checkCowswapOrder(params, order, orderUid);

        params.amountIn = order.sellAmount;
        params.minAmountOut = order.buyAmount + 1;

        vm.expectRevert();
        module.checkCowswapOrder(params, order, orderUid);
        params.minAmountOut = order.buyAmount;
        params.deadline = block.timestamp + 1;

        vm.expectRevert();
        module.checkCowswapOrder(params, order, orderUid);
        params.deadline = block.timestamp;
        order.kind = GPv2Order.KIND_BUY;

        vm.expectRevert();
        module.checkCowswapOrder(params, order, orderUid);
        order.kind = GPv2Order.KIND_SELL;
        order.sellTokenBalance = GPv2Order.BALANCE_EXTERNAL;

        vm.expectRevert();
        module.checkCowswapOrder(params, order, orderUid);
        order.sellTokenBalance = GPv2Order.BALANCE_ERC20;
        order.buyTokenBalance = GPv2Order.BALANCE_EXTERNAL;

        vm.expectRevert();
        module.checkCowswapOrder(params, order, orderUid);
        order.buyTokenBalance = GPv2Order.BALANCE_ERC20;

        vm.expectRevert();
        module.checkCowswapOrder(params, order, new bytes(56));
    }

    function testCreateCowswapOrder_NO_CI() external {
        SwapModule module = SwapModule(
            payable(
                new TransparentUpgradeableProxy(
                    address(swapModule), admin, abi.encodeCall(IFactoryEntity.initialize, getInitParams())
                )
            )
        );

        uint256 amountIn = 1000000e6;
        deal(USDC, address(module), amountIn);

        uint256 minAmountOut = 247.508 ether;

        ISwapModule.Params memory params = ISwapModule.Params({
            tokenIn: USDC,
            tokenOut: WETH,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            deadline: block.timestamp
        });

        GPv2Order.Data memory order = GPv2Order.Data({
            sellToken: ERC20Interface(USDC),
            buyToken: ERC20Interface(WETH),
            receiver: address(module),
            sellAmount: amountIn,
            buyAmount: minAmountOut,
            validTo: uint32(block.timestamp),
            appData: bytes32(0),
            feeAmount: 0,
            kind: GPv2Order.KIND_SELL,
            partiallyFillable: true,
            sellTokenBalance: GPv2Order.BALANCE_ERC20,
            buyTokenBalance: GPv2Order.BALANCE_ERC20
        });

        bytes memory orderUid = new bytes(56);
        GPv2Order.packOrderUidParams(
            orderUid,
            GPv2Order.hash(order, GPv2Settlement(payable(module.cowswapSettlement())).domainSeparator()),
            address(module),
            uint32(block.timestamp)
        );

        vm.startPrank(caller);

        assertEq(IERC20(USDC).allowance(address(module), COWSWAP_VAULT_RELAYER), 0);

        vm.expectRevert();
        module.setCowswapApproval(TransferLibrary.ETH, amountIn);
        vm.expectRevert();
        module.setCowswapApproval(address(0xdead), amountIn);

        module.setCowswapApproval(USDC, amountIn);

        assertEq(IERC20(USDC).allowance(address(module), COWSWAP_VAULT_RELAYER), amountIn);

        assertEq(GPv2Settlement(payable(COWSWAP_SETTLEMENT)).filledAmount(orderUid), 0);
        assertEq(GPv2Settlement(payable(COWSWAP_SETTLEMENT)).preSignature(orderUid), 0);
        module.createLimitOrder(params, order, orderUid);

        assertEq(
            GPv2Settlement(payable(COWSWAP_SETTLEMENT)).preSignature(orderUid),
            uint256(keccak256("GPv2Signing.Scheme.PreSign"))
        );
        assertEq(GPv2Settlement(payable(COWSWAP_SETTLEMENT)).filledAmount(orderUid), 0);

        module.invalidateOrder(orderUid);

        assertEq(GPv2Settlement(payable(COWSWAP_SETTLEMENT)).filledAmount(orderUid), type(uint256).max);
        assertEq(
            GPv2Settlement(payable(COWSWAP_SETTLEMENT)).preSignature(orderUid),
            uint256(keccak256("GPv2Signing.Scheme.PreSign"))
        );

        module.createLimitOrder(params, order, orderUid);

        assertEq(GPv2Settlement(payable(COWSWAP_SETTLEMENT)).filledAmount(orderUid), type(uint256).max);
        assertEq(
            GPv2Settlement(payable(COWSWAP_SETTLEMENT)).preSignature(orderUid),
            uint256(keccak256("GPv2Signing.Scheme.PreSign"))
        );

        skip(1);

        params.deadline = block.timestamp;
        order.validTo = uint32(block.timestamp);
        orderUid = new bytes(56);
        GPv2Order.packOrderUidParams(
            orderUid,
            GPv2Order.hash(order, GPv2Settlement(payable(module.cowswapSettlement())).domainSeparator()),
            address(module),
            uint32(block.timestamp)
        );

        module.createLimitOrder(params, order, orderUid);

        vm.stopPrank();
    }
}
