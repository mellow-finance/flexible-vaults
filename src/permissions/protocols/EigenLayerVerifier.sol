// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/external/eigen-layer/IDelegationManager.sol";
import "../../interfaces/external/eigen-layer/IRewardsCoordinator.sol";
import "../../interfaces/external/eigen-layer/IStrategyManager.sol";
import "../../interfaces/permissions/ICustomVerifier.sol";

import "../../libraries/SlotLibrary.sol";

contract EigenLayerVerifier is ICustomVerifier, ContextUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct EigenLayerVerifierStorage {
        address vault;
        EnumerableSet.AddressSet whitelistedStrategies;
        EnumerableSet.AddressSet whitelistedAssets;
        EnumerableSet.AddressSet whitelistedOperators;
        EnumerableSet.AddressSet whitelistedReceivers;
    }

    bytes32 public constant ADD_WHITELISTED_STRATEGY_ROLE =
        keccak256("EIGEN_LAYER_VERIFIER:ADD_WHITELISTED_STRATEGY_ROLE");
    bytes32 public constant ADD_WHITELISTED_ASSET_ROLE = keccak256("EIGEN_LAYER_VERIFIER:ADD_WHITELISTED_ASSET_ROLE");
    bytes32 public constant ADD_WHITELISTED_OPERATOR_ROLE =
        keccak256("EIGEN_LAYER_VERIFIER:ADD_WHITELISTED_OPERATOR_ROLE");
    bytes32 public constant REMOVE_WHITELISTED_STRATEGY_ROLE =
        keccak256("EIGEN_LAYER_VERIFIER:REMOVE_WHITELISTED_STRATEGY_ROLE");
    bytes32 public constant REMOVE_WHITELISTED_ASSET_ROLE =
        keccak256("EIGEN_LAYER_VERIFIER:REMOVE_WHITELISTED_ASSET_ROLE");
    bytes32 public constant REMOVE_WHITELISTED_OPERATOR_ROLE =
        keccak256("EIGEN_LAYER_VERIFIER:REMOVE_WHITELISTED_OPERATOR_ROLE");

    bytes32 private immutable _eigenLayerVerifierStorageSlot;

    IDelegationManager public immutable delegationManager;
    IStrategyManager public immutable strategyManager;
    IRewardsCoordinator public immutable rewardsCoordinator;

    constructor(
        string memory name_,
        uint256 version_,
        address delegationManager_,
        address strategyManager_,
        address rewardsCoordinator_
    ) {
        _eigenLayerVerifierStorageSlot = SlotLibrary.getSlot("EigenLayerVerifier", name_, version_);
        delegationManager = IDelegationManager(delegationManager_);
        strategyManager = IStrategyManager(strategyManager_);
        rewardsCoordinator = IRewardsCoordinator(rewardsCoordinator_);
        _disableInitializers();
    }

    // View functions

    modifier onlyRole(bytes32 role) {
        require(
            IAccessControl(_eigenLayerVerifierStorage().vault).hasRole(role, _msgSender()),
            "EigenLayerVerifier: Caller does not have the required role"
        );
        _;
    }

    function vault() public view returns (address) {
        return _eigenLayerVerifierStorage().vault;
    }

    function isWhitelistedStrategy(address strategy) public view returns (bool) {
        return _eigenLayerVerifierStorage().whitelistedStrategies.contains(strategy);
    }

    function isWhitelistedAsset(address asset) public view returns (bool) {
        return _eigenLayerVerifierStorage().whitelistedAssets.contains(asset);
    }

    function isWhitelistedOperator(address operator) public view returns (bool) {
        return _eigenLayerVerifierStorage().whitelistedOperators.contains(operator);
    }

    function isWhitelistedReceiver(address receiver) public view returns (bool) {
        EigenLayerVerifierStorage storage $ = _eigenLayerVerifierStorage();
        return receiver == $.vault || $.whitelistedReceivers.contains(receiver);
    }

    function whitelistedStrategies() public view returns (uint256) {
        return _eigenLayerVerifierStorage().whitelistedStrategies.length();
    }

    function whitelistedAssets() public view returns (uint256) {
        return _eigenLayerVerifierStorage().whitelistedAssets.length();
    }

    function whitelistedOperators() public view returns (uint256) {
        return _eigenLayerVerifierStorage().whitelistedOperators.length();
    }

    function whitelistedReceivers() public view returns (uint256) {
        return _eigenLayerVerifierStorage().whitelistedReceivers.length();
    }

    function whitelistedStrategyAt(uint256 index) public view returns (address) {
        return _eigenLayerVerifierStorage().whitelistedStrategies.at(index);
    }

    function whitelistedAssetAt(uint256 index) public view returns (address) {
        return _eigenLayerVerifierStorage().whitelistedAssets.at(index);
    }

    function whitelistedOperatorAt(uint256 index) public view returns (address) {
        return _eigenLayerVerifierStorage().whitelistedOperators.at(index);
    }

    function whitelistedReceiverAt(uint256 index) public view returns (address) {
        return _eigenLayerVerifierStorage().whitelistedReceivers.at(index);
    }

    function verifyCall(
        address, /* who */
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata /* verificationData */
    ) external view override returns (bool) {
        if (callData.length < 4 || value != 0) {
            return false;
        }
        bytes4 selector = bytes4(callData[:4]);
        if (where == address(strategyManager)) {
            if (selector == IStrategyManager.depositIntoStrategy.selector) {
                (IStrategy strategy, address asset, uint256 shares) =
                    abi.decode(callData[4:], (IStrategy, address, uint256));
                if (!isWhitelistedStrategy(address(strategy)) || !isWhitelistedAsset(asset) || shares == 0) {
                    return false;
                }
                if (keccak256(abi.encodeWithSelector(selector, strategy, asset, shares)) != keccak256(callData)) {
                    return false;
                }
            } else {
                return false;
            }
        } else if (where == address(delegationManager)) {
            if (selector == IDelegationManager.delegateTo.selector) {
                (address operator, ISignatureUtils.SignatureWithExpiry memory signature, bytes32 approverSalt) =
                    abi.decode(callData[4:], (address, ISignatureUtils.SignatureWithExpiry, bytes32));
                if (!isWhitelistedOperator(operator)) {
                    return false;
                }
                if (
                    keccak256(abi.encodeWithSelector(selector, operator, signature, approverSalt))
                        != keccak256(callData)
                ) {
                    return false;
                }
            } else if (selector == IDelegationManager.queueWithdrawals.selector) {
                IDelegationManager.QueuedWithdrawalParams[] memory params =
                    abi.decode(callData[4:], (IDelegationManager.QueuedWithdrawalParams[]));
                if (params.length != 1) {
                    return false;
                }
                IDelegationManager.QueuedWithdrawalParams memory param = params[0];
                if (
                    param.strategies.length != 1 || address(param.strategies[0]) == address(0)
                        || param.depositShares.length != 1 || param.depositShares[0] == 0
                        || !isWhitelistedStrategy(address(param.strategies[0]))
                ) {
                    return false;
                }
                if (keccak256(callData) != keccak256(abi.encodeWithSelector(selector, params))) {
                    return false;
                }
            } else if (selector == IDelegationManager.completeQueuedWithdrawal.selector) {
                (IDelegationManager.Withdrawal memory withdrawal, address[] memory tokens, bool receiveAsTokens) =
                    abi.decode(callData[4:], (IDelegationManager.Withdrawal, address[], bool));

                IStrategy strategy = withdrawal.strategies[0];
                if (
                    tokens.length != 1 || !receiveAsTokens || withdrawal.staker != address(vault())
                        || withdrawal.strategies.length != 1 || address(strategy) == address(0)
                        || !isWhitelistedStrategy(address(strategy)) || !isWhitelistedAsset(tokens[0])
                ) {
                    return false;
                }
                if (
                    keccak256(abi.encodeWithSelector(selector, withdrawal, tokens, receiveAsTokens))
                        != keccak256(callData)
                ) {
                    return false;
                }
            } else {
                return false;
            }
        } else if (where == address(rewardsCoordinator)) {
            if (selector == IRewardsCoordinator.processClaim.selector) {
                (IRewardsCoordinator.RewardsMerkleClaim memory claimData, address receiver) =
                    abi.decode(callData[4:], (IRewardsCoordinator.RewardsMerkleClaim, address));
                if (claimData.earnerLeaf.earner != vault()) {
                    return false;
                }
                if (!isWhitelistedReceiver(receiver)) {
                    return false;
                }
                if (keccak256(abi.encodeWithSelector(selector, claimData, receiver)) != keccak256(callData)) {
                    return false;
                }
            } else {
                return false;
            }
        } else {
            return false;
        }
        return true;
    }

    // Mutable functions

    function addWhitelistedStrategy(address strategy) external onlyRole(ADD_WHITELISTED_STRATEGY_ROLE) {
        require(strategy != address(0), "EigenLayerVerifier: invalid strategy address");
        require(
            _eigenLayerVerifierStorage().whitelistedStrategies.add(strategy),
            "EigenLayerVerifier: strategy already whitelisted"
        );
    }

    function removeWhitelistedStrategy(address strategy) external onlyRole(REMOVE_WHITELISTED_STRATEGY_ROLE) {
        require(
            _eigenLayerVerifierStorage().whitelistedStrategies.remove(strategy),
            "EigenLayerVerifier: strategy not whitelisted"
        );
    }

    function addWhitelistedAsset(address asset) external onlyRole(ADD_WHITELISTED_ASSET_ROLE) {
        require(asset != address(0), "EigenLayerVerifier: Invalid asset address");
        require(
            _eigenLayerVerifierStorage().whitelistedAssets.add(asset), "EigenLayerVerifier: asset already whitelisted"
        );
    }

    function removeWhitelistedAsset(address asset) external onlyRole(REMOVE_WHITELISTED_ASSET_ROLE) {
        require(
            _eigenLayerVerifierStorage().whitelistedAssets.remove(asset), "EigenLayerVerifier: asset not whitelisted"
        );
    }

    function addWhitelistedOperator(address operator) external onlyRole(ADD_WHITELISTED_OPERATOR_ROLE) {
        require(operator != address(0), "EigenLayerVerifier: invalid operator address");
        require(
            _eigenLayerVerifierStorage().whitelistedOperators.add(operator),
            "EigenLayerVerifier: operator already whitelisted"
        );
    }

    function removeWhitelistedOperator(address operator) external onlyRole(REMOVE_WHITELISTED_OPERATOR_ROLE) {
        require(
            _eigenLayerVerifierStorage().whitelistedOperators.remove(operator),
            "EigenLayerVerifier: operator not whitelisted"
        );
    }

    function initialize(bytes calldata data) external initializer {
        address vault_ = abi.decode(data, (address));
        if (vault_ == address(0)) {
            revert("EigenLayerVerifier: vault address cannot be zero");
        }
        _eigenLayerVerifierStorage().vault = vault_;
    }

    // Internal functions

    function _eigenLayerVerifierStorage() internal view returns (EigenLayerVerifierStorage storage $) {
        bytes32 slot = _eigenLayerVerifierStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
