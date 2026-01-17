// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/ethereum/Constants.sol";
import "../Imports.sol";

contract IntegrationTest is Test {
    Vault vault = Vault(payable(Constants.STRETH));
    FlexibleStrategy impl = new FlexibleStrategy("Mellow", 1);

    address strategyAdmin = vm.createWallet("strategy-admin").addr;

    function allowCalls(address strategy, address[] memory targets, bytes32[] memory selectors) internal {
        address vaultAdmin = vault.getRoleMember(Permissions.DEFAULT_ADMIN_ROLE, 0);
        vm.startPrank(vaultAdmin);
        vault.grantRole(Permissions.ALLOW_CALL_ROLE, vaultAdmin);
        vault.grantRole(Permissions.CALLER_ROLE, strategy);
        IVerifier.CompactCall[] memory compactCalls = new IVerifier.CompactCall[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            compactCalls[i] = IVerifier.CompactCall({who: strategy, where: targets[i], selector: bytes4(selectors[i])});
        }
        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            IVerifier verifier = IVerifierModule(subvault).verifier();
            verifier.allowCalls(compactCalls);
        }
        vm.stopPrank();
    }

    function buildSimpleTupleValues(bytes32[] memory values, uint256 msgValue)
        internal
        pure
        returns (FlexibleStrategy.InputValue[] memory inputValues)
    {
        inputValues = new FlexibleStrategy.InputValue[](values.length + 3);
        {
            uint256[] memory edges = new uint256[](2);
            for (uint256 i = 0; i < edges.length; i++) {
                edges[i] = i + 1;
            }
            inputValues[0] =
                FlexibleStrategy.InputValue({vertexType: FlexibleStrategy.VertexType.PARENT, data: "", edges: edges});

            inputValues[1] = FlexibleStrategy.InputValue({
                vertexType: FlexibleStrategy.VertexType.CONSTANT,
                data: abi.encode(msgValue),
                edges: new uint256[](0)
            });
        }

        {
            uint256[] memory edges = new uint256[](values.length);
            for (uint256 i = 0; i < edges.length; i++) {
                edges[i] = i + 3;
            }
            inputValues[2] =
                FlexibleStrategy.InputValue({vertexType: FlexibleStrategy.VertexType.PARENT, data: "", edges: edges});
        }
        for (uint256 i = 0; i < values.length; i++) {
            inputValues[i + 3] = FlexibleStrategy.InputValue({
                vertexType: FlexibleStrategy.VertexType.CONSTANT,
                data: abi.encode(values[i]),
                edges: new uint256[](0)
            });
        }
    }

    function buildSimpleTupleInputTree(uint256 n) internal pure returns (FlexibleStrategy.Vertex[] memory tree) {
        tree = new FlexibleStrategy.Vertex[](n + 3);
        tree[0].t = Type.TUPLE;
        tree[0].edges = new uint256[](2);
        tree[0].edges[0] = 1;
        tree[0].edges[1] = 2;
        tree[1].t = Type.WORD;
        tree[2].t = Type.TUPLE;
        tree[2].edges = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            tree[2].edges[i] = i + 3;
            tree[3 + i].t = Type.WORD;
        }
    }

    function buildSimpleTupleTree(uint256 n) internal pure returns (FlexibleStrategy.Vertex[] memory tree) {
        tree = new FlexibleStrategy.Vertex[](n + 1);
        tree[0].t = Type.TUPLE;
        tree[0].edges = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            tree[0].edges[i] = i + 1;
        }
        for (uint256 i = 1; i <= n; i++) {
            tree[i].t = Type.WORD;
        }
    }

    function testFexibleStrategy_NO_CI() external {
        // create a strategy that will work as an automated stuff
        FlexibleStrategy strategy =
            FlexibleStrategy(address(new TransparentUpgradeableProxy(address(impl), address(0xdead), "")));

        strategy.initialize(abi.encode(strategyAdmin, vault));

        vm.startPrank(strategyAdmin);
        strategy.grantRole(strategy.EXECUTOR_ROLE(), strategyAdmin);
        vm.stopPrank();
        {
            allowCalls(
                address(strategy),
                ArraysLibrary.makeAddressArray(
                    abi.encode(
                        Constants.AAVE_CORE,
                        Constants.AAVE_CORE,
                        Constants.AAVE_CORE,
                        Constants.AAVE_CORE,
                        Constants.WSTETH,
                        Constants.WETH
                    )
                ),
                ArraysLibrary.makeBytes32Array(
                    abi.encode(
                        IAavePoolV3.supply.selector,
                        IAavePoolV3.borrow.selector,
                        IAavePoolV3.repay.selector,
                        IAavePoolV3.withdraw.selector,
                        IERC20.approve.selector,
                        IERC20.approve.selector
                    )
                )
            );
        }
        vm.startPrank(strategyAdmin);

        FlexibleStrategy.Action[] memory actions = new FlexibleStrategy.Action[](3);
        IVerifier.VerificationPayload memory payload;

        actions[0] = FlexibleStrategy.Action({
            actionType: FlexibleStrategy.ActionType.CALL,
            inputValues: buildSimpleTupleValues(
                ArraysLibrary.makeBytes32Array(abi.encode(Constants.AAVE_CORE, type(uint256).max)), 0
            ),
            inputTypes: buildSimpleTupleInputTree(2),
            outputTypes: buildSimpleTupleTree(1),
            data: abi.encode(vault.subvaultAt(0), Constants.WSTETH, IERC20.approve.selector),
            payload: payload
        });

        actions[1] = FlexibleStrategy.Action({
            actionType: FlexibleStrategy.ActionType.CALL,
            inputValues: buildSimpleTupleValues(
                ArraysLibrary.makeBytes32Array(abi.encode(Constants.WSTETH, 1 ether, vault.subvaultAt(0), 0)), 0
            ),
            inputTypes: buildSimpleTupleInputTree(4),
            outputTypes: buildSimpleTupleTree(0),
            data: abi.encode(vault.subvaultAt(0), Constants.AAVE_CORE, IAavePoolV3.supply.selector),
            payload: payload
        });

        actions[2] = FlexibleStrategy.Action({
            actionType: FlexibleStrategy.ActionType.CALL,
            inputValues: buildSimpleTupleValues(
                ArraysLibrary.makeBytes32Array(abi.encode(Constants.WETH, 0.5 ether, 2, 0, vault.subvaultAt(0))), 0
            ),
            inputTypes: buildSimpleTupleInputTree(5),
            outputTypes: buildSimpleTupleTree(0),
            data: abi.encode(vault.subvaultAt(0), Constants.AAVE_CORE, IAavePoolV3.borrow.selector),
            payload: payload
        });

        strategy.execute(actions, new bytes[](0));

        vm.stopPrank();
    }
}
