// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/TransferLibrary.sol";
import "./PermissionsModule.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract NodeModule is PermissionsModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Flows {
        int256 inflow;
        int256 outflow;
        int256 limit;
        int256 correction;
    }

    struct SetValue {
        address asset;
        address childNode;
        int256 value;
    }

    struct NodeModuleStorage {
        address parentModule;
        mapping(address asset => mapping(address childModule => Flows)) flows;
        EnumerableSet.AddressSet childModules;
    }

    bytes32 public constant SET_PARENT_MODULE_ROLE = keccak256("NODE_MODULE:SET_PARENT_MODULE_ROLE");
    bytes32 public constant CONNECT_CHILD_NODE_ROLE =
        keccak256("NODE_MODULE:CONNECT_CHILD_NODE_ROLE");
    bytes32 public constant PULL_LIQUIDITY_ROLE = keccak256("NODE_MODULE:PULL_LIQUIDITY_ROLE");
    bytes32 public constant PUSH_LIQUIDITY_ROLE = keccak256("NODE_MODULE:PUSH_LIQUIDITY_ROLE");
    bytes32 public constant SET_CORRECTIONS_ROLE = keccak256("NODE_MODULE:SET_CORRECTIONS_ROLE");
    bytes32 public constant SET_LIMITS_ROLE = keccak256("NODE_MODULE:SET_LIMITS_ROLE");

    bytes32 private immutable _nodeModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _nodeModuleStorageSlot = SlotLibrary.getSlot("NodeModule", name_, version_);
    }

    // View functions

    function parentModule() public view returns (address) {
        return _nodeModuleStorage().parentModule;
    }

    function childModules() public view returns (uint256) {
        return _nodeModuleStorage().childModules.length();
    }

    function childModuleAt(uint256 index) public view returns (address) {
        return _nodeModuleStorage().childModules.at(index);
    }

    function hasChildModule(address childModule) public view returns (bool) {
        return _nodeModuleStorage().childModules.contains(childModule);
    }

    function flowsOf(address asset, address childModule) external view returns (Flows memory) {
        return _nodeModuleStorage().flows[asset][childModule];
    }

    function availableLimit(address asset, address childModule) public view returns (uint256) {
        NodeModuleStorage storage $ = _nodeModuleStorage();
        Flows memory flows = $.flows[asset][childModule];

        int256 balance = int256(flows.outflow) - int256(flows.inflow) + flows.correction;

        if (
            flows.limit == type(int256).max
                || balance < 0 && flows.limit > type(int256).max + balance
        ) {
            return type(uint256).max;
        }
        int256 limit = flows.limit - balance;
        if (limit < 0) {
            return 0;
        }
        return uint256(limit);
    }

    // Mutable functions

    function setParentModule(address parentModule_)
        external
        virtual
        onlyRole(SET_PARENT_MODULE_ROLE)
    {
        NodeModuleStorage storage $ = _nodeModuleStorage();
        if (parentModule_ == address(0)) {
            revert("NodeModule: zero address");
        }
        if ($.parentModule != address(0)) {
            revert("NodeModule: parent module already set");
        }
        $.parentModule = parentModule_;
    }

    function connectChildNode(address node) external onlyRole(CONNECT_CHILD_NODE_ROLE) {
        if (NodeModule(payable(node)).parentModule() != address(this)) {
            revert("NodeModule: child module not set to this parent");
        }
        EnumerableSet.AddressSet storage childModules_ = _nodeModuleStorage().childModules;
        if (!childModules_.add(node)) {
            revert("NodeModule: child module already connected");
        }
    }

    function pushLiquidity(address childModule, address asset, uint256 assets)
        external
        onlyRole(PUSH_LIQUIDITY_ROLE)
    {
        NodeModuleStorage storage $ = _nodeModuleStorage();
        if (!$.childModules.contains(childModule)) {
            revert("NodeModule: child module not connected");
        }

        if (availableLimit(asset, childModule) < assets) {
            revert("NodeModule: limit exceeded");
        }

        TransferLibrary.transfer(asset, address(this), childModule, assets);
        $.flows[asset][childModule].outflow += int256(assets);
    }

    function pullLiquidity(address childModule, address asset, uint256 assets)
        external
        onlyRole(PULL_LIQUIDITY_ROLE)
    {
        NodeModuleStorage storage $ = _nodeModuleStorage();
        if (!$.childModules.contains(childModule)) {
            revert("NodeModule: child module not connected");
        }
        NodeModule(payable(childModule)).transferLiquidity(asset, assets);
        $.flows[asset][childModule].inflow += int256(assets);
    }

    function transferLiquidity(address asset, uint256 assets) external {
        require(
            _msgSender() == _nodeModuleStorage().parentModule,
            "NodeModule: only parent module can transfer liquidity"
        );
        if (assets == 0) {
            revert("NodeModule: assets must be greater than zero");
        }
        if (asset == address(0)) {
            revert("NodeModule: asset cannot be zero address");
        }
        TransferLibrary.transfer(asset, address(this), _msgSender(), assets);
    }

    function setCorrections(SetValue[] calldata corrections)
        external
        onlyRole(SET_CORRECTIONS_ROLE)
    {
        NodeModuleStorage storage $ = _nodeModuleStorage();
        for (uint256 i = 0; i < corrections.length; i++) {
            SetValue calldata param = corrections[i];
            if (param.asset == address(0)) {
                revert("NodeModule: zero address");
            }
            if (!$.childModules.contains(param.childNode)) {
                revert("NodeModule: child module not connected");
            }
            $.flows[param.asset][param.childNode].correction = param.value;
        }
    }

    function setLimits(SetValue[] calldata corrections) external onlyRole(SET_LIMITS_ROLE) {
        NodeModuleStorage storage $ = _nodeModuleStorage();
        for (uint256 i = 0; i < corrections.length; i++) {
            SetValue calldata param = corrections[i];
            if (param.asset == address(0)) {
                revert("NodeModule: zero address");
            }
            if (!$.childModules.contains(param.childNode)) {
                revert("NodeModule: child module not connected");
            }
            if (param.value < 0) {
                revert("NodeModule: limit cannot be negative");
            }
            $.flows[param.asset][param.childNode].limit = param.value;
        }
    }

    // Internal functions

    function _nodeModuleStorage() internal view returns (NodeModuleStorage storage $) {
        bytes32 slot = _nodeModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
