// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

interface IWETHInterface {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

interface IPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

interface INFPM {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    function burn(uint256 tokenId) external payable;
}

contract Deploy is Script {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    Factory depositQueueFactory = Factory(0x0aE52c4804578b0E9311c273f3dd7092C06A4c49);
    Factory feeManagerFactory = Factory(0xA235D20641988C80Da3f17E7012d15Cad14bBE0a);
    Factory oracleFactory = Factory(0x3BD1F592DD8d684260a18899AD65Fa100cF48038);
    Factory redeemQueueFactory = Factory(0x2BD86E06437090E9E738D147cAba1377986663D2);
    Factory riskManagerFactory = Factory(0x521A8e873CaEB00783ea246b2e438Ed893Bcb812);
    Factory shareManagerFactory = Factory(0xfca30806cc28Fa199172B96e155a5D52826394Ad);
    Factory subvaultFactory = Factory(0x59cEb1B97a93cF0D5D13D73C1554D4A867F53bbA);
    Factory vaultFactory = Factory(0x27eDf8706Fb64B2A402d8334e71e3Ce794Ed7376);
    Factory verifierFactory = Factory(0x89AB09d56f8fDB542995d99ea312A68898EaC6b8);
    BitmaskVerifier bitmaskVerifier = BitmaskVerifier(0xA0EAcc0E00f4935dc293177E848873093Cb5124d);
    VaultConfigurator vaultConfigurator = VaultConfigurator(0x8263Bd42A80B25677Aa0b9a619d305a32191D5fB);

    RedirectingDepositHook redirectingDepositHook = RedirectingDepositHook(0x3169036c3F79c03C14a7496DD2016f5B059e17D8);
    BasicRedeemHook basicRedeemHook = BasicRedeemHook(0x5FEF2c3f9B870b4EF7099E153a73D6C1Ba6d7D1d);

    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
    address public constant KAITO = 0x98d0baa52b2D063E780DE12F615f963Fe8537553;
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    address public constant curator = 0x503CAf4B74f95A4499A05e4eC187e6C02182Bc79;
    address public constant positionManager = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address public constant swapRouter = 0x2626664c2603336E57B271c5C0b26F421741e481;

    RedirectingDepositHook defaultDepositHook;
    BasicRedeemHook defaultRedeemHook;
    IOracle.SecurityParams securityParams_;

    /*
        === Deployment ===

        Vault 0x85C205b7Dd8EAd3a288feF72E7e6681E524F1575
        Subvault 0x738C241A49d4dC2905D32EA4c27425958c9B8759
        Oracle 0x22ea163694F25984D02bce638af2574b80aF42D6
        ShareManager 0x6b2EBecb6259882CF7Ed460a8AB5014A5D96936f
        RiskManager 0x2d23a00605dd9B3e2D1D8f4307C1856B31b18738
        FeeManager 0x9b89285B47c3e6bbf10e982c568fB377738f943c
        DepositQueue ETH 0xA1d81018535D30C925509A0cAFBE6600ac7500A3
        DepositQueue WETH 0x4014Cf89fc4D7d308AF2547fD2a8ed6aDcE63217
        DepositQueue USDC 0xDb397318a250038cd894765115E706c285D37998
        DepositQueue USDT 0x196feDC8CFE29276782a01c581846a942163dA98
        DepositQueue KAITO 0x413F763E1Ff2d05c6420B96fBA527C01E2F2Ff01
        RedeemQueue ETH 0xCe6934090cE40a42c096F716D00cc7aCAb5B9Eb4
        RedeemQueue WETH 0xA6cf4200464307C19099912584D03Eb760b30573
        RedeemQueue USDC 0x9a90DE14C0df7FBdfE6b02F693535f0Aeb83a4D0
        RedeemQueue USDT 0xE9f7A5b34dab00AdD842cFC746DE7649db1f5851
        RedeemQueue KAITO 0x71BC50054ef73685a51B69cf89F6aC361934C561

        === Allowed Curator Calls ===

        These calls are allowed via `Subvault.call(...)`:

        1. WETH:
            1.1 WETH.deposit{value: <any>}();
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124dd92e08bec948a55c565b5fb664dfd812badc7487a7e9219828023f7b8f65107600000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000064ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000ffffffff00000000000000000000000000000000000000000000000000000000
                proof: [
                        0x1fa09133209860e3e4537cff3650cf726372efa3935c4097880b146733867256,
                        0x50a6a0171dab3f72737880ecd5209db1c6083e786547e39adbbf3a6a5eade0c1,
                        0x0ccb2d36cf18fec5972094a7b1327fe612313a283b186d7c5ea3efa6c0288f55,
                        0x0ab296dd5eec254f7725bb9291710d5d314f87b8fb4b9dacccf51fca831279b2,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]

            1.2 WETH.withdraw(<any>);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124d8c36eea469bdb657610ed4bc4960ea1a49688359dcf3a895c58417c083c1ef9300000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000084ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
                proof: [
                        0x47af64db001522e1a735d8f1d1054adbb9e181237130dce6ebb7a3d20493bbac,
                        0x594272b135ef42fc016005e72c64b5072d028c132b72fd49ec2e82977e1a1432,
                        0x33951e1e32ccf1ecf85c1fbe4417f7d9c3df1b59b70ef0a908e6453c22e2c296,
                        0x0ab296dd5eec254f7725bb9291710d5d314f87b8fb4b9dacccf51fca831279b2,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]

        2. NonfungiblePositionManager:
            2.1 burn(<any>);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124ddc88586c70fd9b615473186e1cb8f756aaadddc77e1c4d2e88d56b02096a97b500000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000084ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
                proof: [
                        0x255b679465debec00a3ff709f0dcb1753fb5489d9e17444ca55cc3cbda14d0df,
                        0x80c68f81adefe34cfe454800ae3e6a3b42778ba427e64b1d338d7c923cb433ae,
                        0x33951e1e32ccf1ecf85c1fbe4417f7d9c3df1b59b70ef0a908e6453c22e2c296,
                        0x0ab296dd5eec254f7725bb9291710d5d314f87b8fb4b9dacccf51fca831279b2,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]
            2.2 increaseLiquidity(<any>);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124d4a76cafb3f96518d7a1380bc448a85976f09736a3a097bd6a4eaa11c5ad3319600000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000124ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
                proof: [
                        0x9def1d7a30c971f573ace7efa4f4bd07aeed39592ac2221a5c749609d49e0014,
                        0xfd62f56ac614ff8cb124a3da77b07a5c2429d08415d2d39360ecf7d61cc4921e,
                        0x2e90088e9f7f8276b727b33782efeefac5e084e386393886372de96e28d20d47,
                        0x860138502495519d07429ef3754bf7844b6882ef383ef788179f28e99964912f
                ]
            2.3 decreaseLiquidity(<any>);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124da29dbc048f08ad878c0976ba767af4e305340584297c34fdf31b1e1fc146b33900000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000104ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
                proof: [
                        0xe7ca4d614cf16aa905e0f88d12671ce26720b44a6a169f927097070c400d9dea,
                        0xc46ff3cadaf04b53d2600168ae0ee944a9290178ac864a3ee794a3db65c1c499,
                        0x6ec70573f9e30651b258d1f9a6f56d0fa7aa2d18de09dda2df706b8d783a622e,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]
            2.4 collect(recipient = Subvault);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124df1948a011225284962c1fabfde19abb3b9312750e50082d5f84381348d7fa5d8000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
                proof: [
                        0x1c13dba7790fe3a6adf978358a6f049e7dba32a40b81f64233041ec7eb4e4e68,
                        0x50a6a0171dab3f72737880ecd5209db1c6083e786547e39adbbf3a6a5eade0c1,
                        0x0ccb2d36cf18fec5972094a7b1327fe612313a283b186d7c5ea3efa6c0288f55,
                        0x0ab296dd5eec254f7725bb9291710d5d314f87b8fb4b9dacccf51fca831279b2,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]


        3. SwapRouter (recipient = Subvault):
            3.1 exactInputSingle(...);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124d7d7ed519195c23ecf9ed062970d826721a9c862e8f1ba6bcce72877a90592dcf00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000144ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
                proof: [
                        0x593e210048a90de2df8d72600072a2106e0d73182da6098e2b562c7fd83f7635,
                        0x9e5fa4487e0b014356db7d31b0c32e74692de2c523ba8bada949df02a6a22b09,
                        0xbbad5dd0d075541dddb11b96edbc6e2817cb02ced520d760962e7c0918b3e594,
                        0x860138502495519d07429ef3754bf7844b6882ef383ef788179f28e99964912f
                ]
            3.2 exactOutputSingle(...);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124d8183c3cf1485b190ade5dc2e5a06c0be605954e2ee763b58bc886daf53a5471800000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000144ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
                proof: [
                        0xd52e3b6c707820baad30ce7c6168b9454fbc166c78d8c87eb8258b9391c0fcc4,
                        0xc46ff3cadaf04b53d2600168ae0ee944a9290178ac864a3ee794a3db65c1c499,
                        0x6ec70573f9e30651b258d1f9a6f56d0fa7aa2d18de09dda2df706b8d783a622e,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]

        4. Token Approvals (max allowance = type(uint256).max):
            4.1 USDC.approve(SwapRouter, max);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124d0b0281f59fedb9e00764cb2ae0702ba8fca0c7b43e4384aa34fbf59183c5b76b000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000
                proof: [
                        0x59ef0152f654b52d91414eab6070ed6c43158f6c16e75496926b8dfb06dcb9d9,
                        0x9af131a527d07b1d7f7fae3b57f01e69f0f9bd7d24423cd0c63e325f18c9be48,
                        0xbbad5dd0d075541dddb11b96edbc6e2817cb02ced520d760962e7c0918b3e594,
                        0x860138502495519d07429ef3754bf7844b6882ef383ef788179f28e99964912f
                ]
            4.2 USDT.approve(SwapRouter, max);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124daa31d2781a3ecacd3699b2ddb79ab1d7d85b187af6f0775d8a5ba481b66529b8000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000
                proof: [
                        0x55cdd5dbc48bb305cf43f8c05671a8d860e348cda1369961fffa2fc3c911b80f,
                        0x594272b135ef42fc016005e72c64b5072d028c132b72fd49ec2e82977e1a1432,
                        0x33951e1e32ccf1ecf85c1fbe4417f7d9c3df1b59b70ef0a908e6453c22e2c296,
                        0x0ab296dd5eec254f7725bb9291710d5d314f87b8fb4b9dacccf51fca831279b2,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]
            4.3 WETH.approve(SwapRouter, max);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124d6e14fa70690e1dfde7c7625e6d824725714214673e4edb5c6fdf1e1529ab18e4000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000
                proof: [
                        0x3720ff51e2245ff5363171be8e738a1b3ea37d86507ccf2aad649a135e89eda1,
                        0x80c68f81adefe34cfe454800ae3e6a3b42778ba427e64b1d338d7c923cb433ae,
                        0x33951e1e32ccf1ecf85c1fbe4417f7d9c3df1b59b70ef0a908e6453c22e2c296,
                        0x0ab296dd5eec254f7725bb9291710d5d314f87b8fb4b9dacccf51fca831279b2,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]
            4.4 KAITO.approve(SwapRouter, max);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124df432a4fede3b09266d08db2bc5cc115dd12557c6bbf22c88f5b3b05644b0caf1000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000
                proof: [
                        0xa3f73ba3bca5828edf1271a0d9bebbc5ba06cd15c461821be9c29b272405db81,
                        0xfd62f56ac614ff8cb124a3da77b07a5c2429d08415d2d39360ecf7d61cc4921e,
                        0x2e90088e9f7f8276b727b33782efeefac5e084e386393886372de96e28d20d47,
                        0x860138502495519d07429ef3754bf7844b6882ef383ef788179f28e99964912f
                ]
            4.5 USDC.approve(NonfungiblePositionManager, max);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124d294dba053977ba62033a47ec6fdb3fe360ea994f5e8d6255785e7f3b51f49a46000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000
                proof: [
                        0xb805a72b151fa673893c3d28a6c179ff9949912a41c02b4a23de44181d321e0e,
                        0x0ba7fedea6fa56eb23127154059af9c29533c6c148e5d7d0f761b0de390fe8b2,
                        0x2e90088e9f7f8276b727b33782efeefac5e084e386393886372de96e28d20d47,
                        0x860138502495519d07429ef3754bf7844b6882ef383ef788179f28e99964912f
                ]
            4.6 USDT.approve(NonfungiblePositionManager, max);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124d16d1071f2a2c3559e8acdab7e8f3441e77a0fa5496c6f2cdf295eb14358d6d20000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000
                proof: [
                        0x736951168bbb23b3ef085c3abe24b032eca93a885666530140a167838b9a8579,
                        0x9af131a527d07b1d7f7fae3b57f01e69f0f9bd7d24423cd0c63e325f18c9be48,
                        0xbbad5dd0d075541dddb11b96edbc6e2817cb02ced520d760962e7c0918b3e594,
                        0x860138502495519d07429ef3754bf7844b6882ef383ef788179f28e99964912f
                ]
            4.7 WETH.approve(NonfungiblePositionManager, max);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124ddbf8857a16b189554c36a5d3fcaee4db39b3aff5c7a4108140d95219c4bca548000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000
                proof: [
                        0x59cb356c5ff340685b14f9c9e8ed0ebd84a6cd349b7bf94749e629f57b5f65a7,
                        0x9e5fa4487e0b014356db7d31b0c32e74692de2c523ba8bada949df02a6a22b09,
                        0xbbad5dd0d075541dddb11b96edbc6e2817cb02ced520d760962e7c0918b3e594,
                        0x860138502495519d07429ef3754bf7844b6882ef383ef788179f28e99964912f
                ]
            4.8 KAITO.approve(NonfungiblePositionManager, max);
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124dd9537bdd48576668d69766e2a4d16f0d45d252b46e47bd33ce86bed9a7cda936000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000
                proof: [
                        0xb494e95d2403c3e93d674ab67f63596f45b90875f7a4af11fe89110dfca1cef6,
                        0x0ba7fedea6fa56eb23127154059af9c29533c6c148e5d7d0f761b0de390fe8b2,
                        0x2e90088e9f7f8276b727b33782efeefac5e084e386393886372de96e28d20d47,
                        0x860138502495519d07429ef3754bf7844b6882ef383ef788179f28e99964912f
                ]
        5. NonfungiblePositionManager.mint(...) — allowed only for specific pools (recipient = Subvault):
            5.1 Uniswap V3 WETH–USDC 0.05%
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124dfec1125e02b7900e223441324f7bb5c71390af52cb948f4a6d013aab5e339cc3000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001c4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000ffffffffffffffffffffffffffffffffffffffff000000000000000000000000ffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000ffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
                proof: [
                        0x047a00b8f9032d218ab4a8862aab236759cbfb3db78bf31a63cdec1527efae17,
                        0x59ef81163ea9f14579ac4c08e09895007044530ab92e7f9bd162cf2d9681e089,
                        0x0ccb2d36cf18fec5972094a7b1327fe612313a283b186d7c5ea3efa6c0288f55,
                        0x0ab296dd5eec254f7725bb9291710d5d314f87b8fb4b9dacccf51fca831279b2,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]
            5.2 Uniswap V3 KAITO–WETH 0.3%
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124dbae306c049bc7c339bb328c5462b4b28cc2a50b4b3b68c46af22e675957b24fc000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001c4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000ffffffffffffffffffffffffffffffffffffffff000000000000000000000000ffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000ffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
                proof: [
                        0xf7595c18bd001dfa3d0f021db4e360f7940535c056d90fe88126f8e17d22b2d7,
                        0x77f45edf3a9f308971ec95092b8aa0af8647ea8bbc8028ba0df3271f661542c2,
                        0x6ec70573f9e30651b258d1f9a6f56d0fa7aa2d18de09dda2df706b8d783a622e,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]
            5.3 Uniswap V3 USDC–USDT 0.05%
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124dfec1125e02b7900e223441324f7bb5c71390af52cb948f4a6d013aab5e339cc3000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001c4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000ffffffffffffffffffffffffffffffffffffffff000000000000000000000000ffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000ffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
                proof: [
                        0x047a00b8f9032d218ab4a8862aab236759cbfb3db78bf31a63cdec1527efae17,
                        0x59ef81163ea9f14579ac4c08e09895007044530ab92e7f9bd162cf2d9681e089,
                        0x0ccb2d36cf18fec5972094a7b1327fe612313a283b186d7c5ea3efa6c0288f55,
                        0x0ab296dd5eec254f7725bb9291710d5d314f87b8fb4b9dacccf51fca831279b2,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]
            5.4 Uniswap V3 WETH–USDT 0.3%
                verificationType: 3
                verificationData: 0x000000000000000000000000a0eacc0e00f4935dc293177e848873093cb5124dbae306c049bc7c339bb328c5462b4b28cc2a50b4b3b68c46af22e675957b24fc000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001c4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000ffffffffffffffffffffffffffffffffffffffff000000000000000000000000ffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000ffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
                proof: [
                        0xf7595c18bd001dfa3d0f021db4e360f7940535c056d90fe88126f8e17d22b2d7,
                        0x77f45edf3a9f308971ec95092b8aa0af8647ea8bbc8028ba0df3271f661542c2,
                        0x6ec70573f9e30651b258d1f9a6f56d0fa7aa2d18de09dda2df706b8d783a622e,
                        0x64bc06bf79d879e918778ab784fe1adad464661cc52d6a3a611c7ea02fb800d4
                ]

        === Vault Roles ===
            1. VaultModule.PULL_LIQUIDITY_ROLE
            2. VaultModule.PUSH_LIQUIDITY_ROLE
            3. Verifier.CALLER_ROLE
    */

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        defaultDepositHook = new RedirectingDepositHook();
        defaultRedeemHook = new BasicRedeemHook();

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](19);
        holders[0] = Vault.RoleHolder(keccak256("oracles.Oracle.SUBMIT_REPORTS_ROLE"), deployer);
        holders[1] = Vault.RoleHolder(keccak256("oracles.Oracle.ACCEPT_REPORT_ROLE"), deployer);
        holders[2] = Vault.RoleHolder(keccak256("modules.VaultModule.CREATE_SUBVAULT_ROLE"), deployer);
        holders[3] = Vault.RoleHolder(keccak256("modules.VaultModule.PULL_LIQUIDITY_ROLE"), deployer);
        holders[4] = Vault.RoleHolder(keccak256("modules.VaultModule.PUSH_LIQUIDITY_ROLE"), deployer);
        holders[5] = Vault.RoleHolder(keccak256("permissions.Verifier.SET_MERKLE_ROOT_ROLE"), deployer);
        holders[6] = Vault.RoleHolder(keccak256("permissions.Verifier.CALLER_ROLE"), deployer);
        holders[7] = Vault.RoleHolder(keccak256("permissions.Verifier.ALLOW_CALL_ROLE"), deployer);
        holders[8] = Vault.RoleHolder(keccak256("permissions.Verifier.DISALLOW_CALL_ROLE"), deployer);
        holders[9] = Vault.RoleHolder(keccak256("modules.ShareModule.CREATE_QUEUE_ROLE"), deployer);
        holders[10] = Vault.RoleHolder(keccak256("modules.ShareModule.CREATE_QUEUE_ROLE"), deployer);
        holders[11] = Vault.RoleHolder(keccak256("managers.RiskManager.SET_VAULT_LIMIT_ROLE"), deployer);
        holders[12] = Vault.RoleHolder(keccak256("managers.RiskManager.SET_SUBVAULT_LIMIT_ROLE"), deployer);
        holders[13] = Vault.RoleHolder(keccak256("managers.RiskManager.ALLOW_SUBVAULT_ASSETS_ROLE"), deployer);
        holders[14] = Vault.RoleHolder(keccak256("managers.RiskManager.MODIFY_VAULT_BALANCE_ROLE"), deployer);
        holders[15] = Vault.RoleHolder(keccak256("managers.RiskManager.MODIFY_SUBVAULT_BALANCE_ROLE"), deployer);

        holders[16] = Vault.RoleHolder(keccak256("modules.VaultModule.PULL_LIQUIDITY_ROLE"), curator);
        holders[17] = Vault.RoleHolder(keccak256("modules.VaultModule.PUSH_LIQUIDITY_ROLE"), curator);
        holders[18] = Vault.RoleHolder(keccak256("permissions.Verifier.CALLER_ROLE"), curator);

        securityParams_ = IOracle.SecurityParams({
            maxAbsoluteDeviation: 0.001 ether,
            suspiciousAbsoluteDeviation: 0.0005 ether,
            maxRelativeDeviationD18: 0.001 ether,
            suspiciousRelativeDeviationD18: 0.0005 ether,
            timeout: 10 minutes,
            depositInterval: 1 minutes,
            redeemInterval: 1 minutes
        });
        address[] memory assets_ = new address[](5);
        assets_[0] = USDC;
        assets_[1] = USDT;
        assets_[2] = KAITO;
        assets_[3] = WETH;
        assets_[4] = TransferLibrary.ETH;

        (,,,, address vault_) = vaultConfigurator.create(
            VaultConfigurator.InitParams({
                version: 0,
                proxyAdmin: deployer,
                vaultAdmin: deployer,
                shareManagerVersion: 0,
                shareManagerParams: abi.encode(bytes32(0), "MellowTestVaultBase", "MTVB"),
                feeManagerVersion: 0,
                feeManagerParams: abi.encode(deployer, deployer, uint24(0), uint24(0), uint24(0), uint24(0)),
                riskManagerVersion: 0,
                riskManagerParams: abi.encode(int256(100 ether)),
                oracleVersion: 0,
                oracleParams: abi.encode(securityParams_, assets_),
                defaultDepositHook: address(defaultDepositHook),
                defaultRedeemHook: address(defaultRedeemHook),
                queueLimit: 16,
                roleHolders: holders
            })
        );

        Vault vault = Vault(payable(vault_));

        vault.createQueue(0, true, deployer, TransferLibrary.ETH, new bytes(0));
        vault.createQueue(0, true, deployer, WETH, new bytes(0));
        vault.createQueue(0, true, deployer, USDC, new bytes(0));
        vault.createQueue(0, true, deployer, USDT, new bytes(0));
        vault.createQueue(0, true, deployer, KAITO, new bytes(0));

        vault.createQueue(0, false, deployer, TransferLibrary.ETH, new bytes(0));
        vault.createQueue(0, false, deployer, WETH, new bytes(0));
        vault.createQueue(0, false, deployer, USDC, new bytes(0));
        vault.createQueue(0, false, deployer, USDT, new bytes(0));
        vault.createQueue(0, false, deployer, KAITO, new bytes(0));

        address verifier = verifierFactory.create(0, deployer, abi.encode(vault, bytes32(0)));
        address subvault = vault.createSubvault(0, deployer, verifier);

        IVerifier.VerificationPayload[] memory array = new IVerifier.VerificationPayload[](50);
        /*
            ERC20 (usdc, usdt, kaito, weth):
                approve: selector, to, infAmount
        */

        uint256 iterator = 0;
        // weth.deposit()
        array[iterator++] = makeVerificationPayload(
            curator,
            WETH,
            0,
            abi.encodeCall(IWETHInterface.deposit, ()),
            abi.encodePacked(type(uint256).max, type(uint256).max, uint256(0), type(uint32).max)
        );
        // weth.withdraw(amount)
        array[iterator++] = makeVerificationPayload(
            curator,
            WETH,
            0,
            abi.encodeCall(IWETHInterface.withdraw, (0)),
            abi.encodePacked(type(uint256).max, type(uint256).max, type(uint256).max, type(uint32).max, uint256(0))
        );
        // positionManager.burn(tokenId)
        array[iterator++] = makeVerificationPayload(
            curator,
            positionManager,
            0,
            abi.encodeCall(INFPM.burn, (0)),
            abi.encodePacked(type(uint256).max, type(uint256).max, type(uint256).max, type(uint32).max, uint256(0))
        );
        // positionManager.increaseLiquidity(...)
        {
            INFPM.IncreaseLiquidityParams memory increaseLiquidityEmptyParams;
            array[iterator++] = makeVerificationPayload(
                curator,
                positionManager,
                0,
                abi.encodeCall(INFPM.increaseLiquidity, (increaseLiquidityEmptyParams)),
                abi.encodePacked(
                    type(uint256).max,
                    type(uint256).max,
                    type(uint256).max,
                    type(uint32).max,
                    abi.encode(increaseLiquidityEmptyParams)
                )
            );
        }
        // positionManager.decreaseLiquidity
        {
            INFPM.DecreaseLiquidityParams memory decreaseLiquidityEmptyParams;
            array[iterator++] = makeVerificationPayload(
                curator,
                positionManager,
                0,
                abi.encodeCall(INFPM.decreaseLiquidity, (decreaseLiquidityEmptyParams)),
                abi.encodePacked(
                    type(uint256).max,
                    type(uint256).max,
                    type(uint256).max,
                    type(uint32).max,
                    abi.encode(decreaseLiquidityEmptyParams)
                )
            );
        }
        // positionManger.collect
        {
            INFPM.CollectParams memory p;
            p.recipient = subvault;
            INFPM.CollectParams memory bp;
            bp.recipient = address(type(uint160).max);
            array[iterator++] = makeVerificationPayload(
                curator,
                positionManager,
                0,
                abi.encodeCall(INFPM.collect, (p)),
                abi.encodePacked(
                    type(uint256).max, type(uint256).max, type(uint256).max, type(uint32).max, abi.encode(bp)
                )
            );
        }
        // swapRouter.exactInputSingle
        {
            IV3SwapRouter.ExactInputSingleParams memory exactInputParams;
            exactInputParams.recipient = subvault;
            IV3SwapRouter.ExactInputSingleParams memory bitmaskParams;
            bitmaskParams.recipient = address(type(uint160).max);
            array[iterator++] = makeVerificationPayload(
                curator,
                swapRouter,
                0,
                abi.encodeCall(IV3SwapRouter.exactInputSingle, (exactInputParams)),
                abi.encodePacked(
                    type(uint256).max, type(uint256).max, type(uint256).max, type(uint32).max, abi.encode(bitmaskParams)
                )
            );
        }
        // swapRouter.exactOutputSingle
        {
            IV3SwapRouter.ExactOutputSingleParams memory exactOutputParams;
            exactOutputParams.recipient = subvault;
            IV3SwapRouter.ExactOutputSingleParams memory bitmaskParams;
            bitmaskParams.recipient = address(type(uint160).max);
            array[iterator++] = makeVerificationPayload(
                curator,
                swapRouter,
                0,
                abi.encodeCall(IV3SwapRouter.exactOutputSingle, (exactOutputParams)),
                abi.encodePacked(
                    type(uint256).max, type(uint256).max, type(uint256).max, type(uint32).max, abi.encode(bitmaskParams)
                )
            );
        }
        // token.approve(swapRouter/positionManager, inf)
        {
            // usdc.approve(swapRouter, inf)
            array[iterator++] = makeVerificationPayload(
                curator,
                USDC,
                0,
                abi.encodeCall(IERC20.approve, (swapRouter, type(uint256).max)),
                abi.encodePacked(
                    type(uint256).max,
                    type(uint256).max,
                    type(uint256).max,
                    type(uint32).max,
                    type(uint256).max,
                    abi.encode(type(uint256).max)
                )
            );

            // usdt.approve(swapRouter, inf)
            array[iterator++] = makeVerificationPayload(
                curator,
                USDT,
                0,
                abi.encodeCall(IERC20.approve, (swapRouter, type(uint256).max)),
                abi.encodePacked(
                    type(uint256).max,
                    type(uint256).max,
                    type(uint256).max,
                    type(uint32).max,
                    type(uint256).max,
                    abi.encode(type(uint256).max)
                )
            );
            // weth.approve(swapRouter, inf)
            array[iterator++] = makeVerificationPayload(
                curator,
                WETH,
                0,
                abi.encodeCall(IERC20.approve, (swapRouter, type(uint256).max)),
                abi.encodePacked(
                    type(uint256).max,
                    type(uint256).max,
                    type(uint256).max,
                    type(uint32).max,
                    type(uint256).max,
                    abi.encode(type(uint256).max)
                )
            );
            // kaito.approve(swapRouter, inf)
            array[iterator++] = makeVerificationPayload(
                curator,
                KAITO,
                0,
                abi.encodeCall(IERC20.approve, (swapRouter, type(uint256).max)),
                abi.encodePacked(
                    type(uint256).max,
                    type(uint256).max,
                    type(uint256).max,
                    type(uint32).max,
                    type(uint256).max,
                    abi.encode(type(uint256).max)
                )
            );

            // usdc.approve(positionManager, inf)
            array[iterator++] = makeVerificationPayload(
                curator,
                USDC,
                0,
                abi.encodeCall(IERC20.approve, (positionManager, type(uint256).max)),
                abi.encodePacked(
                    type(uint256).max,
                    type(uint256).max,
                    type(uint256).max,
                    type(uint32).max,
                    type(uint256).max,
                    abi.encode(type(uint256).max)
                )
            );
            // usdt.approve(positionManager, inf)
            array[iterator++] = makeVerificationPayload(
                curator,
                USDT,
                0,
                abi.encodeCall(IERC20.approve, (positionManager, type(uint256).max)),
                abi.encodePacked(
                    type(uint256).max,
                    type(uint256).max,
                    type(uint256).max,
                    type(uint32).max,
                    type(uint256).max,
                    abi.encode(type(uint256).max)
                )
            );
            // weth.approve(positionManager, inf)
            array[iterator++] = makeVerificationPayload(
                curator,
                WETH,
                0,
                abi.encodeCall(IERC20.approve, (positionManager, type(uint256).max)),
                abi.encodePacked(
                    type(uint256).max,
                    type(uint256).max,
                    type(uint256).max,
                    type(uint32).max,
                    type(uint256).max,
                    abi.encode(type(uint256).max)
                )
            );
            // kaito.approve(positionManager, inf)
            array[iterator++] = makeVerificationPayload(
                curator,
                KAITO,
                0,
                abi.encodeCall(IERC20.approve, (positionManager, type(uint256).max)),
                abi.encodePacked(
                    type(uint256).max,
                    type(uint256).max,
                    type(uint256).max,
                    type(uint32).max,
                    type(uint256).max,
                    abi.encode(type(uint256).max)
                )
            );
        }

        address[4] memory pools = [
            0xd0b53D9277642d899DF5C87A3966A349A798F224,
            0x37bb450b17721c6720040a150029e504766e9777,
            0xd92E0767473D1E3FF11Ac036f2b1DB90aD0aE55F,
            0xcE1d8c90A5F0ef28fe0F457e5Ad615215899319a
        ];
        for (uint256 i = 0; i < pools.length; i++) {
            IPool pool = IPool(pools[i]);

            INFPM.MintParams memory p;
            p.token0 = pool.token0();
            p.token1 = pool.token0();
            p.fee = pool.fee();
            p.recipient = subvault;

            INFPM.MintParams memory bp;
            bp.token0 = address(type(uint160).max);
            bp.token1 = address(type(uint160).max);
            bp.fee = type(uint24).max;
            bp.recipient = address(type(uint160).max);

            array[iterator++] = makeVerificationPayload(
                curator,
                positionManager,
                0,
                abi.encodeCall(INFPM.mint, (p)),
                abi.encodePacked(
                    type(uint256).max, type(uint256).max, type(uint256).max, type(uint32).max, abi.encode(bp)
                )
            );
        }
        assembly {
            mstore(array, iterator)
        }

        bytes32 verifierMerkleRoot;
        (verifierMerkleRoot, array) = generateMerkleProofs(array);

        Verifier(verifier).setMerkleRoot(verifierMerkleRoot);

        iterator = 0;

        console2.log("WETH.deposit verifyCall");
        Verifier(verifier).verifyCall(
            curator, WETH, 0.001 ether, abi.encodeCall(IWETHInterface.deposit, ()), array[iterator++]
        );
        console2.log("WETH.withdraw verifyCall");
        Verifier(verifier).verifyCall(
            curator, WETH, 0, abi.encodeCall(IWETHInterface.withdraw, (0.001 ether)), array[iterator++]
        );
        console2.log("NonfungiblePositionManager.burn verifyCall");
        Verifier(verifier).verifyCall(curator, positionManager, 0, abi.encodeCall(INFPM.burn, (1)), array[iterator++]);

        console2.log("NonfungiblePositionManager.increaseLiquidity verifyCall");
        {
            INFPM.IncreaseLiquidityParams memory p;
            Verifier(verifier).verifyCall(
                curator, positionManager, 0, abi.encodeCall(INFPM.increaseLiquidity, (p)), array[iterator++]
            );
        }
        console2.log("NonfungiblePositionManager.decreaseLiquidity verifyCall");
        {
            INFPM.DecreaseLiquidityParams memory p;
            Verifier(verifier).verifyCall(
                curator, positionManager, 0, abi.encodeCall(INFPM.decreaseLiquidity, (p)), array[iterator++]
            );
        }
        console2.log("NonfungiblePositionManager.collect verifyCall");
        {
            INFPM.CollectParams memory p;
            p.recipient = subvault;
            Verifier(verifier).verifyCall(
                curator, positionManager, 0, abi.encodeCall(INFPM.collect, (p)), array[iterator++]
            );
        }

        console2.log("swapRouter.exactInputSingle verifyCall");
        {
            IV3SwapRouter.ExactInputSingleParams memory p;
            p.recipient = subvault;
            Verifier(verifier).verifyCall(
                curator, swapRouter, 0, abi.encodeCall(IV3SwapRouter.exactInputSingle, (p)), array[iterator++]
            );
        }

        console2.log("swapRouter.exactOutputSingle verifyCall");
        {
            IV3SwapRouter.ExactOutputSingleParams memory p;
            p.recipient = subvault;
            Verifier(verifier).verifyCall(
                curator, swapRouter, 0, abi.encodeCall(IV3SwapRouter.exactOutputSingle, (p)), array[iterator++]
            );
        }

        console2.log("usdc.approve(swapRouter, type(uint256).max) verifyCall");
        Verifier(verifier).verifyCall(
            curator, USDC, 0, abi.encodeCall(IERC20.approve, (swapRouter, type(uint256).max)), array[iterator++]
        );
        console2.log("usdt.approve(swapRouter, type(uint256).max) verifyCall");
        Verifier(verifier).verifyCall(
            curator, USDT, 0, abi.encodeCall(IERC20.approve, (swapRouter, type(uint256).max)), array[iterator++]
        );
        console2.log("weth.approve(swapRouter, type(uint256).max) verifyCall");
        Verifier(verifier).verifyCall(
            curator, WETH, 0, abi.encodeCall(IERC20.approve, (swapRouter, type(uint256).max)), array[iterator++]
        );
        console2.log("kaito.approve(swapRouter, type(uint256).max) verifyCall");
        Verifier(verifier).verifyCall(
            curator, KAITO, 0, abi.encodeCall(IERC20.approve, (swapRouter, type(uint256).max)), array[iterator++]
        );

        console2.log("usdc.approve(positionManager, type(uint256).max) verifyCall");
        Verifier(verifier).verifyCall(
            curator, USDC, 0, abi.encodeCall(IERC20.approve, (positionManager, type(uint256).max)), array[iterator++]
        );
        console2.log("usdt.approve(positionManager, type(uint256).max) verifyCall");
        Verifier(verifier).verifyCall(
            curator, USDT, 0, abi.encodeCall(IERC20.approve, (positionManager, type(uint256).max)), array[iterator++]
        );
        console2.log("weth.approve(positionManager, type(uint256).max) verifyCall");
        Verifier(verifier).verifyCall(
            curator, WETH, 0, abi.encodeCall(IERC20.approve, (positionManager, type(uint256).max)), array[iterator++]
        );
        console2.log("kaito.approve(positionManager, type(uint256).max) verifyCall");
        Verifier(verifier).verifyCall(
            curator, KAITO, 0, abi.encodeCall(IERC20.approve, (positionManager, type(uint256).max)), array[iterator++]
        );

        for (uint256 i = 0; i < pools.length; i++) {
            IPool pool = IPool(pools[i]);

            INFPM.MintParams memory p;
            p.token0 = pool.token0();
            p.token1 = pool.token0();
            p.fee = pool.fee();
            p.recipient = subvault;

            console2.log("positionManager.mint(%s)", pools[i]);
            Verifier(verifier).verifyCall(
                curator, positionManager, 0, abi.encodeCall(INFPM.mint, (p)), array[iterator++]
            );
        }

        vault.riskManager().allowSubvaultAssets(subvault, assets_);
        vault.riskManager().setSubvaultLimit(subvault, type(int256).max);

        IOracle oracle = vault.oracle();
        IOracle.Report[] memory reports = new IOracle.Report[](5);
        reports[0] = IOracle.Report({asset: TransferLibrary.ETH, priceD18: 1 ether});
        reports[1] = IOracle.Report({asset: WETH, priceD18: 1 ether});
        reports[2] = IOracle.Report({asset: USDT, priceD18: 275938189845474613686534216});
        reports[3] = IOracle.Report({asset: USDC, priceD18: 275938189845474613686534216});
        reports[4] = IOracle.Report({asset: KAITO, priceD18: 309050772626931});
        oracle.submitReports(reports);
        // uint32 timestamp = oracle.getReport(TransferLibrary.ETH).timestamp;
        // for (uint256 i = 0; i < reports.length; i++) {
        //     oracle.acceptReport(reports[i].asset, reports[i].priceD18, timestamp);
        // }

        // IDepositQueue depositQueue = IDepositQueue(vault.queueAt(TransferLibrary.ETH, 0));
        // depositQueue.deposit{value: 0.001 ether}(0.001 ether, address(0), new bytes32[](0));

        for (uint256 i = 0; i < array.length; i++) {
            console2.log("VerificationPayload for %s-th call:", i + 1);
            console2.log(convert(array[i]));
        }

        console2.log("Vault", address(vault));
        console2.log("Subvault", address(subvault));

        console2.log("Oracle", address(vault.oracle()));

        console2.log("ShareManager", address(vault.shareManager()));
        console2.log("RiskManager", address(vault.riskManager()));
        console2.log("FeeManager", address(vault.feeManager()));

        console2.log("DepositQueue ETH", address(vault.queueAt(TransferLibrary.ETH, 0)));
        console2.log("DepositQueue WETH", address(vault.queueAt(WETH, 0)));
        console2.log("DepositQueue USDC", address(vault.queueAt(USDC, 0)));
        console2.log("DepositQueue USDT", address(vault.queueAt(USDT, 0)));
        console2.log("DepositQueue KAITO", address(vault.queueAt(KAITO, 0)));

        console2.log("RedeemQueue ETH", address(vault.queueAt(TransferLibrary.ETH, 1)));
        console2.log("RedeemQueue WETH", address(vault.queueAt(WETH, 1)));
        console2.log("RedeemQueue USDC", address(vault.queueAt(USDC, 1)));
        console2.log("RedeemQueue USDT", address(vault.queueAt(USDT, 1)));
        console2.log("RedeemQueue KAITO", address(vault.queueAt(KAITO, 1)));

        vm.stopBroadcast();
        // revert("ok");
    }

    function convert(IVerifier.VerificationPayload memory p) public pure returns (string memory s) {
        s = string(
            abi.encodePacked(
                "\tverificationType: ",
                vm.toString(uint256(p.verificationType)),
                "\n\tverificationData: ",
                vm.toString(p.verificationData),
                "\n\tproof: ["
            )
        );

        for (uint256 i = 0; i < p.proof.length; i++) {
            s = string(
                abi.encodePacked(s, "\n\t\t", vm.toString(p.proof[i]), (i + 1 == p.proof.length ? "\n\t]" : ","))
            );
        }
        return s;
    }

    function makeVerificationPayload(address who, address where, uint256 value, bytes memory data, bytes memory bitmask)
        public
        view
        returns (IVerifier.VerificationPayload memory payload)
    {
        if (data.length + 0x60 != bitmask.length) {
            revert("Length mismatch");
        }
        bytes32 hash_ = bitmaskVerifier.calculateHash(bitmask, who, where, value, data);
        payload.verificationType = IVerifier.VerificationType.CUSTOM_VERIFIER;
        payload.verificationData =
            abi.encodePacked(bytes32(uint256(uint160(address(bitmaskVerifier)))), abi.encode(hash_, bitmask));
    }

    function generateMerkleProofs(IVerifier.VerificationPayload[] memory leaves)
        public
        pure
        returns (bytes32 root, IVerifier.VerificationPayload[] memory)
    {
        uint256 n = leaves.length;
        bytes32[] memory tree = new bytes32[](n * 2 - 1);
        bytes32[] memory cache = new bytes32[](n);
        bytes32[] memory sortedHashes = new bytes32[](n);

        for (uint256 i = 0; i < n; i++) {
            bytes32 leaf = keccak256(
                bytes.concat(keccak256(abi.encode(leaves[i].verificationType, keccak256(leaves[i].verificationData))))
            );
            cache[i] = leaf;
            sortedHashes[i] = leaf;
        }
        Arrays.sort(sortedHashes);
        for (uint256 i = 0; i < n; i++) {
            tree[tree.length - 1 - i] = sortedHashes[i];
        }
        for (uint256 i = n; i < 2 * n - 1; i++) {
            uint256 v = tree.length - 1 - i;
            uint256 l = v * 2 + 1;
            uint256 r = v * 2 + 2;
            tree[v] = Hashes.commutativeKeccak256(tree[l], tree[r]);
        }
        root = tree[0];
        for (uint256 i = 0; i < n; i++) {
            uint256 index;
            for (uint256 j = 0; j < n; j++) {
                if (cache[i] == sortedHashes[j]) {
                    index = j;
                    break;
                }
            }
            bytes32[] memory proof = new bytes32[](30);
            uint256 iterator = 0;
            uint256 treeIndex = tree.length - 1 - index;
            while (treeIndex > 0) {
                uint256 siblingIndex = treeIndex;
                if ((treeIndex % 2) == 0) {
                    siblingIndex -= 1;
                } else {
                    siblingIndex += 1;
                }
                proof[iterator++] = tree[siblingIndex];
                treeIndex = (treeIndex - 1) >> 1;
            }
            assembly {
                mstore(proof, iterator)
            }
            leaves[i].proof = proof;
            require(MerkleProof.verify(proof, root, cache[i]), "Invalid proof or tree");
        }
        return (root, leaves);
    }
}
