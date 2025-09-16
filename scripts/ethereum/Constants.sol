// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/Imports.sol";

library Constants {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address public constant COWSWAP_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address public constant COWSWAP_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address public constant EIGEN_LAYER_DELEGATION_MANAGER = 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A;
    address public constant EIGEN_LAYER_STRATEGY_MANAGER = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
    address public constant EIGEN_LAYER_REWARDS_COORDINATOR = 0x7750d328b314EfFa365A0402CcfD489B80B0adda;

    address public constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;
    address public constant SYMBIOTIC_FARM_FACTORY = 0xFEB871581C2ab2e1EEe6f7dDC7e6246cFa087A23;

    function protocolDeployment() internal pure returns (ProtocolDeployment memory) {
        return ProtocolDeployment({
            deploymentName: DEPLOYMENT_NAME,
            deploymentVersion: DEPLOYMENT_VERSION,
            eigenLayerDelegationManager: EIGEN_LAYER_DELEGATION_MANAGER,
            eigenLayerStrategyManager: EIGEN_LAYER_STRATEGY_MANAGER,
            eigenLayerRewardsCoordinator: EIGEN_LAYER_REWARDS_COORDINATOR,
            symbioticVaultFactory: SYMBIOTIC_VAULT_FACTORY,
            symbioticFarmFactory: SYMBIOTIC_FARM_FACTORY,
            wsteth: WSTETH,
            weth: WETH,
            proxyAdmin: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
            deployer: 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3,
            factoryImplementation: Factory(0x0000000397b71C8f3182Fd40D247330D218fdC72),
            factory: Factory(0x0000000f9686896836C39cf721141922Ce42639f),
            consensusFactory: Factory(0xaEEB06CBd91A18b51a2D30b61477eAeE3a9633C3),
            depositQueueFactory: Factory(0xBB92A7B9695750e1234BaB18F83b73686dd09854),
            redeemQueueFactory: Factory(0xfe76b5fd238553D65Ce6dd0A572C0fda629F8421),
            feeManagerFactory: Factory(0xF7223356819Ea48f25880b6c2ab3e907CC336D45),
            oracleFactory: Factory(0x0CdFf250C7a071fdc72340D820C5C8e29507Aaad),
            riskManagerFactory: Factory(0xa51E4FA916b939Fa451520D2B7600c740d86E5A0),
            shareManagerFactory: Factory(0x952f39AA62E94db3Ad0d1C7D1E43C1a8519E45D8),
            subvaultFactory: Factory(0x75FE0d73d3C64cdC1C6449D9F977Be6857c4d011),
            vaultFactory: Factory(0x4E38F679e46B3216f0bd4B314E9C429AFfB1dEE3),
            verifierFactory: Factory(0x04B30b1e98950e6A13550d84e991bE0d734C2c61),
            erc20VerifierFactory: Factory(0x2e234F4E1b7934d5F4bEAE3fF2FDC109f5C42F1d),
            symbioticVerifierFactory: Factory(0x41C443F10a92D597e6c9E271140BC94c10f5159F),
            eigenLayerVerifierFactory: Factory(0x77A83AcBf7A6df20f1D681b4810437d74AE790F8),
            consensusImplementation: Consensus(0x0000000167598d2C78E2313fD5328E16bD9A0b13),
            depositQueueImplementation: DepositQueue(payable(0x00000006dA9f179BFE250Dd1c51cD2d3581930c8)),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x00000003887dfBCEbD1e4097Ad89B690de7eFbf9)),
            redeemQueueImplementation: RedeemQueue(payable(0x0000000285805eac535DADdb9648F1E10DfdC411)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0x0000000b2082667589A16c4cF18e9f923781c471)),
            feeManagerImplementation: FeeManager(0x0000000dE74e5D51651326E0A3e1ACA94bEAF6E1),
            oracleImplementation: Oracle(0x0000000F0d3D1c31b72368366A4049C05E291D58),
            riskManagerImplementation: RiskManager(0x0000000714cf2851baC1AE2f41871862e9D216fD),
            tokenizedShareManagerImplementation: TokenizedShareManager(0x0000000E8eb7173fA1a3ba60eCA325bcB6aaf378),
            basicShareManagerImplementation: BasicShareManager(0x00000005564AAE40D88e2F08dA71CBe156767977),
            subvaultImplementation: Subvault(payable(0x0000000E535B4E063f8372933A55470e67910a66)),
            verifierImplementation: Verifier(0x000000047Fc878662006E78D5174FB4285637966),
            vaultImplementation: Vault(payable(0x0000000615B2771511dAa693aC07BE5622869E01)),
            bitmaskVerifier: BitmaskVerifier(0x0000000263Fb29C3D6B0C5837883519eF05ea20A),
            eigenLayerVerifierImplementation: EigenLayerVerifier(0x00000003F82051A8B2F020B79e94C3DC94E89B81),
            erc20VerifierImplementation: ERC20Verifier(0x00000009207D366cBB8549837F8Ae4bf800Af2D6),
            symbioticVerifierImplementation: SymbioticVerifier(0x00000000cBC6f5d4348496FfA22Cf014b9DA394B),
            vaultConfigurator: VaultConfigurator(0x000000028be48f9E62E13403480B60C4822C5aa5),
            basicRedeemHook: BasicRedeemHook(0x0000000637f1b1ccDA4Af2dB6CDDf5e5Ec45fd93),
            redirectingDepositHook: RedirectingDepositHook(0x00000004d3B17e5391eb571dDb8fDF95646ca827),
            lidoDepositHook: LidoDepositHook(0x000000065d1A7bD71f52886910aaBE6555b7317c),
            oracleHelper: OracleHelper(0x000000005F543c38d5ea6D0bF10A50974Eb55E35)
        });
    }
}
