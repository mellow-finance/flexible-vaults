// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20 as ERC20Interface} from "@cowswap/contracts/interfaces/IERC20.sol";

import {GPv2Interaction} from "@cowswap/contracts/libraries/GPv2Interaction.sol";
import {GPv2Trade} from "@cowswap/contracts/libraries/GPv2Trade.sol";

import "../../scripts/common/ArraysLibrary.sol";
import "../../scripts/ethereum/Constants.sol";
import "../Imports.sol";
import "./BaseIntegrationTest.sol";

contract SwapModuleIntegration is BaseIntegrationTest {
    using SafeERC20 for IERC20;

    address public constant COWSWAP_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address public constant COWSWAP_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address public constant AAVE_V3_ORACLE = 0x54586bE62E3c3580375aE3723C145253060Ca0C2;

    address public constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    Deployment private $;

    Factory public swapModuleFactory;

    function setUp() external {
        $ = deployBase();
        vm.startPrank($.deployer);
        swapModuleFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
        address implementation = address(new SwapModule("Mellow", 1, COWSWAP_SETTLEMENT, COWSWAP_VAULT_RELAYER, WETH));
        swapModuleFactory.proposeImplementation(implementation);
        swapModuleFactory.acceptProposedImplementation(implementation);
        swapModuleFactory.transferOwnership($.vaultProxyAdmin);
        vm.stopPrank();
    }

    function submitAndAcceptReports(IOracle oracle) public {
        IOracle.Report[] memory reports = new IOracle.Report[](2);
        reports[0] = IOracle.Report({asset: USDC, priceD18: 1e30});
        reports[1] = IOracle.Report({asset: USDT, priceD18: 1e30});
        oracle.submitReports(reports);
        if (oracle.getReport(USDC).isSuspicious) {
            oracle.acceptReport(USDC, 1e30, uint32(block.timestamp));
        }

        if (oracle.getReport(USDT).isSuspicious) {
            oracle.acceptReport(USDT, 1e30, uint32(block.timestamp));
        }
    }

    function testSwapModule_Integration() external {
        IOracle.SecurityParams memory securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 0.01 ether, // 1% abs
            suspiciousAbsoluteDeviation: 0.005 ether, // 0.05% abs
            maxRelativeDeviationD18: 0.01 ether, // 1% abs
            suspiciousRelativeDeviationD18: 0.005 ether, // 0.05% abs
            timeout: 20 hours,
            depositInterval: 1 hours,
            redeemInterval: 48 hours
        });

        address[] memory assets = ArraysLibrary.makeAddressArray(abi.encode(USDC, USDT));

        Vault.RoleHolder[] memory roleHolders = new Vault.RoleHolder[](8);

        Vault vaultImplementation = Vault(payable($.vaultFactory.implementationAt(0)));
        Oracle oracleImplementation = Oracle($.oracleFactory.implementationAt(0));

        roleHolders[0] = Vault.RoleHolder(vaultImplementation.CREATE_QUEUE_ROLE(), $.vaultAdmin);
        roleHolders[1] = Vault.RoleHolder(oracleImplementation.SUBMIT_REPORTS_ROLE(), $.vaultAdmin);
        roleHolders[2] = Vault.RoleHolder(oracleImplementation.ACCEPT_REPORT_ROLE(), $.vaultAdmin);
        roleHolders[3] = Vault.RoleHolder(vaultImplementation.CREATE_SUBVAULT_ROLE(), $.vaultAdmin);
        roleHolders[4] = Vault.RoleHolder(Verifier($.verifierFactory.implementationAt(0)).CALLER_ROLE(), $.curator);
        roleHolders[5] = Vault.RoleHolder(
            RiskManager($.riskManagerFactory.implementationAt(0)).SET_SUBVAULT_LIMIT_ROLE(), $.vaultAdmin
        );
        roleHolders[6] = Vault.RoleHolder(
            RiskManager($.riskManagerFactory.implementationAt(0)).ALLOW_SUBVAULT_ASSETS_ROLE(), $.vaultAdmin
        );
        roleHolders[7] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, $.vaultAdmin);

        (,,,, address vault_) = $.vaultConfigurator.create(
            VaultConfigurator.InitParams({
                version: 0,
                proxyAdmin: $.vaultProxyAdmin,
                vaultAdmin: $.vaultAdmin,
                shareManagerVersion: 0,
                shareManagerParams: abi.encode(bytes32(0), string("MellowVault"), string("MV")),
                feeManagerVersion: 0,
                feeManagerParams: abi.encode($.vaultAdmin, $.protocolTreasury, uint24(0), uint24(0), uint24(0), uint24(0)),
                riskManagerVersion: 0,
                riskManagerParams: abi.encode(int256(1000000 ether)),
                oracleVersion: 0,
                oracleParams: abi.encode(securityParams, assets),
                defaultDepositHook: address(new RedirectingDepositHook()),
                defaultRedeemHook: address(new BasicRedeemHook()),
                queueLimit: 16,
                roleHolders: roleHolders
            })
        );

        Vault vault = Vault(payable(vault_));

        vm.startPrank($.vaultAdmin);
        vault.createQueue(0, true, $.vaultProxyAdmin, USDC, new bytes(0));
        vault.createQueue(0, false, $.vaultProxyAdmin, USDT, new bytes(0));

        submitAndAcceptReports(vault.oracle());

        address verifier = $.verifierFactory.create(0, $.vaultProxyAdmin, abi.encode(address(vault), bytes32(0)));
        address subvault = vault.createSubvault(0, $.vaultProxyAdmin, address(verifier));
        SwapModule swapModule;
        {
            SwapModule impl = SwapModule(payable(swapModuleFactory.implementationAt(0)));
            bytes memory initParams = abi.encode(
                $.vaultAdmin,
                subvault,
                AAVE_V3_ORACLE,
                0.99e8,
                ArraysLibrary.makeAddressArray(abi.encode($.curator, USDC, USDT, $.vaultAdmin)),
                ArraysLibrary.makeBytes32Array(
                    abi.encode(
                        impl.CALLER_ROLE(), impl.TOKEN_IN_ROLE(), impl.TOKEN_OUT_ROLE(), impl.SET_SLIPPAGE_ROLE()
                    )
                )
            );
            swapModule = SwapModule(payable(swapModuleFactory.create(0, $.vaultProxyAdmin, initParams)));
        }

        ERC20Verifier erc20Verifier;
        {
            address[] memory holders = new address[](3);
            bytes32[] memory roles = new bytes32[](holders.length);

            ERC20Verifier erc20VerifierImplementation = ERC20Verifier($.protocolVerifierFactory.implementationAt(1));

            holders[0] = USDC;
            roles[0] = erc20VerifierImplementation.ASSET_ROLE();

            holders[1] = $.curator;
            roles[1] = erc20VerifierImplementation.CALLER_ROLE();

            holders[2] = address(swapModule);
            roles[2] = erc20VerifierImplementation.RECIPIENT_ROLE();

            erc20Verifier = ERC20Verifier(
                $.protocolVerifierFactory.create(1, $.vaultProxyAdmin, abi.encode($.vaultAdmin, holders, roles))
            );
        }

        IVerifier.VerificationPayload[] memory verificationPayloads;
        {
            IVerifier.VerificationPayload[] memory leaves = new IVerifier.VerificationPayload[](3);
            leaves[0] = IVerifier.VerificationPayload({
                verificationType: IVerifier.VerificationType.CUSTOM_VERIFIER,
                verificationData: abi.encode(erc20Verifier),
                proof: new bytes32[](0)
            });
            // thats for simplicity - in practice regular Bitmask verifier will be used.
            leaves[1] = IVerifier.VerificationPayload({
                verificationType: IVerifier.VerificationType.MERKLE_COMPACT,
                verificationData: abi.encodePacked(
                    IVerifier(verifier).hashCall(
                        IVerifier.CompactCall({
                            who: $.curator,
                            where: address(swapModule),
                            selector: ISwapModule.pushAssets.selector
                        })
                    )
                ),
                proof: new bytes32[](0)
            });
            leaves[2] = IVerifier.VerificationPayload({
                verificationType: IVerifier.VerificationType.MERKLE_COMPACT,
                verificationData: abi.encodePacked(
                    IVerifier(verifier).hashCall(
                        IVerifier.CompactCall({
                            who: $.curator,
                            where: address(swapModule),
                            selector: ISwapModule.pullAssets.selector
                        })
                    )
                ),
                proof: new bytes32[](0)
            });

            bytes32 merkleRoot;
            (merkleRoot, verificationPayloads) = generateMerkleProofs(leaves);
            IVerifier(verifier).setMerkleRoot(merkleRoot);

            address[] memory assets_ = new address[](2);
            assets_[0] = USDC;
            assets_[1] = USDT;

            vault.riskManager().setSubvaultLimit(subvault, type(int256).max / 2);
            vault.riskManager().allowSubvaultAssets(subvault, assets_);
        }

        vm.stopPrank();

        uint256 amountIn = 1000000e6;

        vm.startPrank($.user);

        {
            DepositQueue queue = DepositQueue(vault.queueAt(USDC, 0));
            deal(USDC, $.user, amountIn);
            IERC20(USDC).approve(address(queue), type(uint256).max);
            queue.deposit(uint224(amountIn), $.user, new bytes32[](0));
            skip(20 hours);
        }

        vm.stopPrank();

        vm.startPrank($.vaultAdmin);
        submitAndAcceptReports(vault.oracle());
        vm.stopPrank();

        vm.startPrank($.curator);

        {
            Subvault subvault_ = Subvault(payable(vault.subvaultAt(0)));
            subvault_.call(
                USDC,
                0,
                abi.encodeCall(IERC20.approve, (address(swapModule), type(uint256).max)),
                verificationPayloads[0]
            );
            subvault_.call(
                address(swapModule),
                0,
                abi.encodeCall(ISwapModule.pushAssets, (USDC, amountIn)),
                verificationPayloads[1]
            );
            subvault_.call(
                address(swapModule),
                0,
                abi.encodeCall(ISwapModule.pullAssets, (USDC, amountIn / 2)),
                verificationPayloads[2]
            );
            subvault_.call(
                address(swapModule),
                0,
                abi.encodeCall(ISwapModule.pushAssets, (USDC, amountIn / 2)),
                verificationPayloads[1]
            );

            swapModule.setCowswapApproval(USDC, amountIn);
        }

        assertEq(IERC20(USDC).balanceOf(address(swapModule)), amountIn);

        GPv2Order.Data memory order;
        {
            uint256 minAmountOut = amountIn * 0.99 ether / 1 ether;
            ISwapModule.Params memory params = ISwapModule.Params({
                tokenIn: USDC,
                tokenOut: USDT,
                amountIn: amountIn,
                minAmountOut: minAmountOut,
                deadline: block.timestamp
            });

            order = GPv2Order.Data({
                sellToken: ERC20Interface(USDC),
                buyToken: ERC20Interface(USDT),
                receiver: address(swapModule),
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
                GPv2Order.hash(order, GPv2Settlement(payable(COWSWAP_SETTLEMENT)).domainSeparator()),
                address(swapModule),
                uint32(block.timestamp)
            );

            swapModule.createLimitOrder(params, order, orderUid);

            assertEq(GPv2Settlement(payable(COWSWAP_SETTLEMENT)).filledAmount(orderUid), 0);
            assertEq(
                GPv2Settlement(payable(COWSWAP_SETTLEMENT)).preSignature(orderUid),
                uint256(keccak256("GPv2Signing.Scheme.PreSign"))
            );
        }
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(address(swapModule)), amountIn);

        address cowswapSolver = 0x95480d3f27658E73b2785D30beb0c847D78294c7;
        vm.startPrank(cowswapSolver);
        {
            deal(USDT, cowswapSolver, amountIn);

            IERC20(USDT).forceApprove(COWSWAP_SETTLEMENT, type(uint256).max);

            ERC20Interface[] memory tokens = new ERC20Interface[](2);
            tokens[0] = ERC20Interface(USDC);
            tokens[1] = ERC20Interface(USDT);

            uint256[] memory clearingPrices = new uint256[](2);
            clearingPrices[0] = 1e8;
            clearingPrices[1] = 1e8;

            GPv2Trade.Data[] memory trades = new GPv2Trade.Data[](1);
            trades[0] = GPv2Trade.Data({
                sellTokenIndex: 0,
                buyTokenIndex: 1,
                receiver: address(swapModule),
                sellAmount: amountIn,
                buyAmount: amountIn * 0.99 ether / 1 ether,
                validTo: uint32(block.timestamp),
                appData: bytes32(0),
                feeAmount: 0,
                flags: 2 | (3 << 5),
                executedAmount: amountIn,
                signature: abi.encodePacked(swapModule)
            });

            GPv2Interaction.Data[][3] memory interactions =
                [new GPv2Interaction.Data[](1), new GPv2Interaction.Data[](0), new GPv2Interaction.Data[](0)];

            interactions[0][0] = GPv2Interaction.Data({
                target: USDT,
                value: 0,
                callData: abi.encodeCall(IERC20.transferFrom, (cowswapSolver, COWSWAP_SETTLEMENT, amountIn))
            });

            GPv2Settlement(payable(COWSWAP_SETTLEMENT)).settle(tokens, clearingPrices, trades, interactions);
        }
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(address(swapModule)), 0);
        assertEq(IERC20(USDT).balanceOf(address(swapModule)), amountIn);

        vm.startPrank($.curator);
        {
            Subvault subvault_ = Subvault(payable(vault.subvaultAt(0)));
            subvault_.call(
                address(swapModule),
                0,
                abi.encodeCall(ISwapModule.pullAssets, (USDT, amountIn)),
                verificationPayloads[2]
            );
        }
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(address(swapModule)), 0);
        assertEq(IERC20(USDT).balanceOf(address(swapModule)), 0);
        assertEq(IERC20(USDT).balanceOf(subvault), amountIn);

        vm.startPrank($.user);

        {
            RedeemQueue queue = RedeemQueue(payable(vault.queueAt(USDT, 0)));
            queue.redeem(vault.shareManager().sharesOf($.user));
        }

        vm.stopPrank();

        vm.startPrank($.vaultAdmin);
        skip(48 hours);
        submitAndAcceptReports(vault.oracle());
        vm.stopPrank();

        vm.startPrank($.user);

        {
            RedeemQueue queue = RedeemQueue(payable(vault.queueAt(USDT, 0)));
            queue.handleBatches(10);
            uint32[] memory timestamps = new uint32[](1);
            timestamps[0] = uint32(queue.requestsOf($.user, 0, type(uint256).max)[0].timestamp);
            queue.claim($.user, timestamps);
        }

        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(address(swapModule)), 0);
        assertEq(IERC20(USDT).balanceOf(address(swapModule)), 0);
        assertEq(IERC20(USDT).balanceOf(subvault), 0);

        assertEq(IERC20(USDT).balanceOf(address($.user)), amountIn);
    }
}
