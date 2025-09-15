// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

import "./Permissions.sol";

import "./ProofLibrary.sol";

import "./interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "./interfaces/IWETH.sol";

contract Deploy is Script {
    // Constants
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public COWSWAP_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address public COWSWAP_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    address public AAVE = address(0);

    // Deployment
    VaultConfigurator vaultConfigurator = VaultConfigurator(0x000000028be48f9E62E13403480B60C4822C5aa5);
    BitmaskVerifier public bitmaskVerifier = BitmaskVerifier(0x0000000263Fb29C3D6B0C5837883519eF05ea20A);
    address public redirectingDepositHook = 0x00000004d3B17e5391eb571dDb8fDF95646ca827;
    address public basicRedeemHook = 0x0000000637f1b1ccDA4Af2dB6CDDf5e5Ec45fd93;
    Factory public verifierFactory = Factory(0x04B30b1e98950e6A13550d84e991bE0d734C2c61);

    // Actors
    address public proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public vaultAdminLazy = address(0);
    address public vaultAdminActive = address(0);
    address public oracleUpdater = address(0);
    address public operator = address(0);
    address public treasury = address(0);

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](4);
        holders[0] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
        holders[1] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
        holders[2] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
        holders[3] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);

        address[] memory assets_ = new address[](3);
        assets_[0] = TransferLibrary.ETH;
        assets_[1] = WETH;
        assets_[2] = WSTETH;

        (,,,, address vault_) = vaultConfigurator.create(
            VaultConfigurator.InitParams({
                version: 0,
                proxyAdmin: proxyAdmin,
                vaultAdmin: vaultAdminLazy,
                shareManagerVersion: 0,
                shareManagerParams: abi.encode(bytes32(0), "stRATEGY", "strETH"),
                feeManagerVersion: 0,
                feeManagerParams: abi.encode(vaultAdminLazy, treasury, uint24(0), uint24(0), uint24(1e5), uint24(0)),
                riskManagerVersion: 0,
                riskManagerParams: abi.encode(int256(40000 ether)),
                oracleVersion: 0,
                oracleParams: abi.encode(
                    IOracle.SecurityParams({
                        maxAbsoluteDeviation: 0.005 ether,
                        suspiciousAbsoluteDeviation: 0.001 ether,
                        maxRelativeDeviationD18: 0.005 ether,
                        suspiciousRelativeDeviationD18: 0.001 ether,
                        timeout: 12 hours,
                        depositInterval: 1 hours,
                        redeemInterval: 2 days
                    }),
                    assets_
                ),
                defaultDepositHook: redirectingDepositHook,
                defaultRedeemHook: basicRedeemHook,
                queueLimit: 4,
                roleHolders: holders
            })
        );
        Vault vault = Vault(payable(vault_));

        vault.createQueue(0, true, deployer, TransferLibrary.ETH, new bytes(0));
        vault.createQueue(0, true, deployer, WETH, new bytes(0));
        vault.createQueue(0, true, deployer, WSTETH, new bytes(0));
        vault.createQueue(0, false, deployer, WSTETH, new bytes(0));

        vault.feeManager().setBaseAsset(vault_, TransferLibrary.ETH);
        IRiskManager riskManager = vault.riskManager();

        {
            vault.createSubvault(0, proxyAdmin, _createCowswapVerifier(address(vault))); // eth,weth,wsteth
            riskManager.allowSubvaultAssets(vault.subvaultAt(0), assets_);

            (address borrowVerifier, address loopingVerifier) = _createAaveEthenaLoopingVerifiers();
            vault.createSubvault(0, proxyAdmin, borrowVerifier); // wsteth,usdt
            address[] memory subvaultAssets = new address[](2);
            subvaultAssets[0] = WSTETH;
            subvaultAssets[1] = USDT;
            riskManager.allowSubvaultAssets(vault.subvaultAt(1), subvaultAssets);

            vault.createSubvault(0, proxyAdmin, loopingVerifier); // usdt
            subvaultAssets = new address[](1);
            subvaultAssets[0] = USDT;
            riskManager.allowSubvaultAssets(vault.subvaultAt(2), subvaultAssets);

            subvaultAssets[0] = WSTETH;
            vault.createSubvault(0, proxyAdmin, _createAaveWstETHLoopingVerifier()); // wsteth
            riskManager.allowSubvaultAssets(vault.subvaultAt(3), subvaultAssets);

            vault.createSubvault(0, proxyAdmin, _createAaveAuraVerifier()); // wsteth
            riskManager.allowSubvaultAssets(vault.subvaultAt(4), subvaultAssets);
        }

        vm.stopBroadcast();
        revert("ok");
    }

    function _createCowswapVerifier(address vault) internal returns (address verifier) {
        /*
            1. weth.deposit{value: <any>}();
            2. weth.approve(cowswapVaultRelayer, <any>);
            3. cowswapSettlement.setPreSignature(anyBytes, anyBool); // bytes - fixed length always
            4. cowswapSettlement.invalidateOrder(anyBytes); // bytes - fixed length always    
        */
        IVerifier.VerificationPayload[] memory leaves = new IVerifier.VerificationPayload[](4);
        leaves[0] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            operator,
            WETH,
            0,
            abi.encodeCall(WETHInterface.deposit, ()),
            ProofLibrary.makeBitmask(true, true, false, true, new bytes(0))
        );
        leaves[1] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            operator,
            WETH,
            0,
            abi.encodeCall(IERC20.approve, (COWSWAP_VAULT_RELAYER, 0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encode(uint256(0)))
        );
        leaves[2] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            operator,
            COWSWAP_SETTLEMENT,
            0,
            abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encode(new bytes(56), false))
        );
        leaves[3] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            operator,
            COWSWAP_SETTLEMENT,
            0,
            abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encode(new bytes(56)))
        );
        bytes32 root;
        (root, leaves) = ProofLibrary.generateMerkleProofs(leaves);
        ProofLibrary.storeProofs("strETH:subvault0:eth,weth->wsteth,cowswap", root, leaves);
        return verifierFactory.create(0, proxyAdmin, abi.encode(vault, root));
    }

    function _createAaveEthenaLoopingVerifiers() internal returns (address verifier0, address verifier1) {
        /*
            strategy 1:
                in:
                    subvault 0:
                            wsteth.approve(aave, type(uint256).max)
                            aave.supply(wsteth, amount0)
                            aave.borrow(usdt, amount1)

                        pullLiquidity(usdt, amount1)

                    subvault 1:
                        pushLiquidity(usdt, amount1)

                            cowswap(usdt, usde, amount1 / 2)
                            cowswap(usdt, susde, amount1 / 2)
                            aave.setEMode(...)
                            aave.supply(usde, amount1 / 2)
                            aave.supply(susde, amount1 / 2)
                            aave.borrow(usdt)
                        repeat;

                out:
                    subvault 1:
                        aave.withdraw(usde, x)
                        aave.withdraw(susde, y)
                        cowswap(usde, usdt, x)
                        cowswap(susde, usdt, y)
                        aave.repay(usdt, x + y)
                    repeat;
                        pullLiquidity(usdt, amount1)

                    subvault 0:
                        pushLiquiditY(usdt, amount1)
                        aave.repay(usdt, amount1)
                    aave.withdraw(wsteth, amount0)
        */
    }

    function _createAaveWstETHLoopingVerifier() internal returns (address verifier) {
        /*
            erc20:
                1. approve wsteth to cowswap/aave
                2. approve weth to cowswap/aave

            cowswap:
                1. create order (wsteth<->weth)
                2. close order (wsteth<->weth)
                
            aave:
                1. supply(wsteth)
                2. borrow(weth)
                3. repay(weth)
                4. withdraw(wsteth)
        */

        //  aave wsteth-weth looping
    }

    function _createAaveAuraVerifier() internal returns (address verifier) {
        //  aave lend wsteth, borrow gho, deposit balancer, aura

        /*
            in:
                aave.supply(wsteth)
                aave.borrow(gho)

                cowswap(gho, usdc)
                cowswap(gho, usdt)

                balancer.deposit(usdc, usdt, gho)
                aura.deposit(balancerLp)

            out:
                aura.withdraw(balancerLP)
                balancer.withdraw()
                
                cowswap(usdt, gho)
                cowswap(usdc, gho)
        */
    }
}
