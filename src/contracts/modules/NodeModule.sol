// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/TransferLibrary.sol";
import "./PermissionsModule.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract NodeModule is PermissionsModule {
    /*
        TODO:
        limits
        permissions
        storage
    */

    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant SET_PARENT_MODULE_ROLE = keccak256("NODE_MODULE:SET_PARENT_MODULE_ROLE");
    bytes32 public constant CONNECT_CHILD_NODE_ROLE =
        keccak256("NODE_MODULE:CONNECT_CHILD_NODE_ROLE");
    bytes32 public constant PULL_LIQUIDITY_ROLE = keccak256("NODE_MODULE:PULL_LIQUIDITY_ROLE");
    bytes32 public constant PUSH_LIQUIDITY_ROLE = keccak256("NODE_MODULE:PUSH_LIQUIDITY_ROLE");

    address public parentModule;
    EnumerableSet.AddressSet private _childModules;

    mapping(address asset => mapping(address childModule => uint256)) public inflows;
    mapping(address asset => mapping(address childModule => uint256)) public outflows;
    mapping(address asset => mapping(address childModule => uint256)) public limits;
    mapping(address asset => mapping(address childModule => int256)) public corrections;

    function setParentModule(address parentModule_)
        external
        virtual
        onlyRole(SET_PARENT_MODULE_ROLE)
    {
        if (parentModule != address(0)) {
            revert("NodeModule: parent module already set");
        }
        parentModule = parentModule_;
    }

    function connectChildNode(address node) external onlyRole(CONNECT_CHILD_NODE_ROLE) {
        if (NodeModule(payable(node)).parentModule() != address(this)) {
            revert("NodeModule: child module not set to this parent");
        }
        _childModules.add(node);
    }

    function pushLiquidity(address childModule, address asset, uint256 assets)
        external
        onlyRole(PULL_LIQUIDITY_ROLE)
    {
        if (!_childModules.contains(childModule)) {
            revert("NodeModule: child module not connected");
        }

        if (
            int256(outflows[asset][childModule]) - int256(inflows[asset][childModule])
                + int256(assets) < int256(limits[asset][childModule]) + corrections[asset][childModule]
        ) {
            revert("NodeModule: limit exceeded");
        }

        TransferLibrary.transfer(asset, address(this), childModule, assets);
        outflows[asset][childModule] += assets;
    }

    function pullLiquidity(address childModule, address asset, uint256 assets)
        external
        onlyRole(PULL_LIQUIDITY_ROLE)
    {
        if (!_childModules.contains(childModule)) {
            revert("NodeModule: child module not connected");
        }
        NodeModule(payable(childModule)).transferLiquidity(asset, assets);
        inflows[asset][childModule] += assets;
    }

    function transferLiquidity(address asset, uint256 assets) external {
        require(
            _msgSender() == parentModule, "NodeModule: only parent module can transfer liquidity"
        );
        if (assets == 0) {
            revert("NodeModule: assets must be greater than zero");
        }
        if (asset == address(0)) {
            revert("NodeModule: asset cannot be zero address");
        }
        TransferLibrary.transfer(asset, address(this), _msgSender(), assets);
    }
}
