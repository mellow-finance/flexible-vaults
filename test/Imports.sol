// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/SlotDerivation.sol";

import "../src/factories/Factory.sol";

import "../src/hooks/BasicRedeemHook.sol";
import "../src/hooks/LidoDepositHook.sol";
import "../src/hooks/RedirectingDepositHook.sol";

import "../src/libraries/FenwickTreeLibrary.sol";
import "../src/libraries/ShareManagerFlagLibrary.sol";
import "../src/libraries/SlotLibrary.sol";
import "../src/libraries/TransferLibrary.sol";

import "../src/modules/ACLModule.sol";
import "../src/modules/BaseModule.sol";
import "../src/modules/CallModule.sol";
import "../src/modules/ShareModule.sol";
import "../src/modules/SubvaultModule.sol";
import "../src/modules/VaultModule.sol";
import "../src/modules/VerifierModule.sol";

import "../src/oracles/Oracle.sol";

import "../src/permissions/BitmaskVerifier.sol";

import "../src/permissions/Consensus.sol";
import "../src/permissions/Verifier.sol";

import "../src/permissions/protocols/ERC20Verifier.sol";
import "../src/permissions/protocols/EigenLayerVerifier.sol";
import "../src/permissions/protocols/SymbioticVerifier.sol";

import "../src/queues/DepositQueue.sol";
import "../src/queues/Queue.sol";
import "../src/queues/RedeemQueue.sol";
import "../src/queues/SignatureDepositQueue.sol";
import "../src/queues/SignatureQueue.sol";
import "../src/queues/SignatureRedeemQueue.sol";

import "../src/managers/BasicShareManager.sol";

import "../src/managers/FeeManager.sol";
import "../src/managers/RiskManager.sol";
import "../src/managers/ShareManager.sol";
import "../src/managers/TokenizedShareManager.sol";

import "../src/vaults/Subvault.sol";
import "../src/vaults/Vault.sol";
import "../src/vaults/VaultConfigurator.sol";

import "./mocks/MockACLModule.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockVault.sol";
