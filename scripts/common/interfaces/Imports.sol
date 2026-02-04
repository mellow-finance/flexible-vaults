// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/factories/Factory.sol";

import "../../../src/hooks/BasicRedeemHook.sol";
import "../../../src/hooks/LidoDepositHook.sol";
import "../../../src/hooks/RedirectingDepositHook.sol";

import "../../../src/libraries/FenwickTreeLibrary.sol";
import "../../../src/libraries/ShareManagerFlagLibrary.sol";
import "../../../src/libraries/SlotLibrary.sol";

import "../../../src/managers/BasicShareManager.sol";

import "../../../src/managers/BurnableTokenizedShareManager.sol";
import "../../../src/managers/FeeManager.sol";
import "../../../src/managers/RiskManager.sol";
import "../../../src/managers/TokenizedShareManager.sol";

import "../../../src/oracles/Oracle.sol";
import "../../../src/oracles/OracleHelper.sol";
import "../../../src/oracles/OracleSubmitter.sol";

import "../../../src/permissions/protocols/ERC20Verifier.sol";
import "../../../src/permissions/protocols/EigenLayerVerifier.sol";
import "../../../src/permissions/protocols/SymbioticVerifier.sol";

import "../../../src/permissions/BitmaskVerifier.sol";
import "../../../src/permissions/Consensus.sol";
import "../../../src/permissions/MellowACL.sol";
import "../../../src/permissions/Verifier.sol";

import "../../../src/queues/DepositQueue.sol";

import "../../../src/queues/RedeemQueue.sol";
import "../../../src/queues/SignatureDepositQueue.sol";
import "../../../src/queues/SignatureRedeemQueue.sol";
import "../../../src/queues/SyncDepositQueue.sol";

import "../../../src/vaults/Subvault.sol";
import "../../../src/vaults/Vault.sol";
import "../../../src/vaults/VaultConfigurator.sol";

import "../../../scripts/common/DeployVaultFactory.sol";
import "../../../scripts/common/DeployVaultFactoryRegistry.sol";
import "../../../src/utils/SwapModule.sol";

struct ProtocolDeployment {
    string deploymentName;
    uint256 deploymentVersion;
    address eigenLayerDelegationManager;
    address eigenLayerStrategyManager;
    address eigenLayerRewardsCoordinator;
    address symbioticVaultFactory;
    address symbioticFarmFactory;
    address wsteth;
    address weth;
    address proxyAdmin;
    address deployer;
    Factory factoryImplementation;
    Factory factory;
    Factory erc20VerifierFactory;
    Factory symbioticVerifierFactory;
    Factory eigenLayerVerifierFactory;
    Factory riskManagerFactory;
    Factory subvaultFactory;
    Factory verifierFactory;
    Factory vaultFactory;
    Factory shareManagerFactory;
    Factory consensusFactory;
    Factory depositQueueFactory;
    Factory redeemQueueFactory;
    Factory feeManagerFactory;
    Factory oracleFactory;
    Factory swapModuleFactory;
    Consensus consensusImplementation;
    DepositQueue depositQueueImplementation;
    SignatureDepositQueue signatureDepositQueueImplementation;
    SyncDepositQueue syncDepositQueueImplementation;
    RedeemQueue redeemQueueImplementation;
    SignatureRedeemQueue signatureRedeemQueueImplementation;
    FeeManager feeManagerImplementation;
    Oracle oracleImplementation;
    RiskManager riskManagerImplementation;
    TokenizedShareManager tokenizedShareManagerImplementation;
    BurnableTokenizedShareManager burnableTokenizedShareManagerImplementation;
    BasicShareManager basicShareManagerImplementation;
    Subvault subvaultImplementation;
    Verifier verifierImplementation;
    Vault vaultImplementation;
    BitmaskVerifier bitmaskVerifier;
    ERC20Verifier erc20VerifierImplementation;
    SymbioticVerifier symbioticVerifierImplementation;
    EigenLayerVerifier eigenLayerVerifierImplementation;
    SwapModule swapModuleImplementation;
    VaultConfigurator vaultConfigurator;
    BasicRedeemHook basicRedeemHook;
    RedirectingDepositHook redirectingDepositHook;
    LidoDepositHook lidoDepositHook;
    OracleHelper oracleHelper;
}

struct Call {
    address who;
    address where;
    uint256 value;
    bytes data;
    bool verificationResult;
}

struct SubvaultCalls {
    IVerifier.VerificationPayload[] payloads;
    Call[][] calls;
}

struct VaultDeployment {
    VaultConfigurator.InitParams initParams;
    Vault vault;
    SubvaultCalls[] calls;
    Vault.RoleHolder[] holders;
    address depositHook;
    address redeemHook;
    address[] assets;
    address[] depositQueueAssets;
    address[] redeemQueueAssets;
    address[] subvaultVerifiers;
    address[] timelockControllers;
    address[] timelockProposers;
    address[] timelockExecutors;
}
