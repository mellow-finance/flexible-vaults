// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";
import "../common/interfaces/Imports.sol";

import "./strETHLibrary.sol";
import "./tqETHLibrary.sol";

library Constants {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    address public constant BTC = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function protocolDeployment() internal pure returns (ProtocolDeployment memory) {
        return ProtocolDeployment({
            deploymentName: DEPLOYMENT_NAME,
            deploymentVersion: DEPLOYMENT_VERSION,
            eigenLayerDelegationManager: address(0),
            eigenLayerStrategyManager: address(0),
            eigenLayerRewardsCoordinator: address(0),
            symbioticVaultFactory: address(0),
            symbioticFarmFactory: address(0),
            wsteth: address(0),
            weth: address(0),
            proxyAdmin: 0xAFfAE6697Ca8B35f397FA2993B03cD9F506DdD17,
            deployer: 0x4d551d74e851Bd93Ce44D5F588Ba14623249CDda,
            factoryImplementation: Factory(0x00000008E7c244Fb6FA6Fc1fB5EC53Ec71c34386),
            factory: Factory(0x000000071a219faa713E719F2DfB458b10dbAED1),
            consensusFactory: Factory(0xE4Db00dCc29966368E8aA966ac75B6FE5B4113D7),
            depositQueueFactory: Factory(0x664B70AE0a01D9beF57c2Eb64664B0CFB055A461),
            redeemQueueFactory: Factory(0x7f2F6B155B41F2DD8A8Ea0FbA3b4EA1ceDc6260e),
            feeManagerFactory: Factory(0x4b2b12a33e260ef35e84687860785d263EfF5172),
            oracleFactory: Factory(0xbb7e4da67Fe8E66AB4AE8EAb2999e731DA364492),
            riskManagerFactory: Factory(0x902266fE38DD8Eee290987490bD57537c82007a1),
            shareManagerFactory: Factory(0x6C3BB5478fD189DCf35Fb3a4b56015163392AA35),
            subvaultFactory: Factory(0x3B62CaA341fA0535a479B394c2f6EA28ee8fA449),
            vaultFactory: Factory(0x5310AD84B0cd3Af376C751EAb81ceE414bD442d8),
            verifierFactory: Factory(0xbc1468D587DaEE3023E2b41Cc642643AF3221178),
            erc20VerifierFactory: Factory(0x0d634B6e35368b8954C53b38aDF72716a16667FA),
            symbioticVerifierFactory: Factory(address(0)),
            eigenLayerVerifierFactory: Factory(address(0)),
            swapModuleFactory: Factory(address(0)),
            consensusImplementation: Consensus(0x000000083a1bE8Aa2Aa5fB244c84A6E410e6ce24),
            depositQueueImplementation: DepositQueue(payable(0x0000000518eC830D8C3da6056b34A0dfBF9e924d)),
            syncDepositQueueImplementation: DepositQueue(payable(address(0x0000000B813e85943D42c5187efAb487E12e1485))),
            signatureDepositQueueImplementation: SignatureDepositQueue(payable(0x00000006A03A937E4B316F02a5130e4FB0B22Dea)),
            redeemQueueImplementation: RedeemQueue(payable(0x00000000d06959064b28a46970497923f8834B16)),
            signatureRedeemQueueImplementation: SignatureRedeemQueue(payable(0x000000004a3F4ff856e7cb47A0ae8aDe6d133cFB)),
            feeManagerImplementation: FeeManager(0x0000000df5Cff487723b8D8c58eD5C336d8a2317),
            oracleImplementation: Oracle(0x0000000C705B7C7485F62Bc1DF7554fD6EB6C602),
            riskManagerImplementation: RiskManager(0x0000000A7a10ea335C54E03220cfAe92310b2465),
            tokenizedShareManagerImplementation: TokenizedShareManager(0x000000071F09E877c469749c093d09FB17896D6c),
            basicShareManagerImplementation: BasicShareManager(0x00000008be96121073931e2b6Da8f5711a52097d),
            subvaultImplementation: Subvault(payable(0x0000000585bE8a415f9edCdC3C56472625BB2E02)),
            verifierImplementation: Verifier(0x000000097bD869258523A17D1e9836E71Ef8aB2A),
            vaultImplementation: Vault(payable(0x0000000B39b91D795b9975219E228bCb4D33A6A3)),
            bitmaskVerifier: BitmaskVerifier(0x0000000819BA998E0Dfe0DAfdd6B23dBf103314D),
            eigenLayerVerifierImplementation: EigenLayerVerifier(address(0)),
            erc20VerifierImplementation: ERC20Verifier(0x000000038Cd2281fe3C651A8B9C2380Ea15f2c87),
            symbioticVerifierImplementation: SymbioticVerifier(address(0)),
            vaultConfigurator: VaultConfigurator(0x00000000f731118c52AeA768c1ac22CEcA7e3b8D),
            basicRedeemHook: BasicRedeemHook(0x0000000887657b16F0dc7EFbb2be9EA77cEDF16c),
            redirectingDepositHook: RedirectingDepositHook(0x0000000B77FC23f6F0f4c51238D6e1c76DefBFdb),
            lidoDepositHook: LidoDepositHook(address(0)),
            oracleHelper: OracleHelper(0x00000002FC616d31133ab9AD626E43a94674D5B6),
            swapModuleImplementation: SwapModule(payable(address(0)))
        });
    }

    OracleSubmitterFactory public constant oracleSubmitterFactory =
        OracleSubmitterFactory(0x00000007AA9Bd15F538a2d1D68A2aCFE8D09BFd0);

    DeployVaultFactoryRegistry public constant deployVaultFactoryRegistry =
        DeployVaultFactoryRegistry(0x000000020893B447c2c13E4A8e5abCF5E7c09AeA);

    DeployVaultFactory public constant deployVaultFactory =
        DeployVaultFactory(0x0000000bd67D6538614668EFe27aF3f17A3031dd);
}
