// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

contract Integration is Test {
    struct State {
        address vault;
        address asset;
        uint256 batchIterator;
        uint256 batchesLength;
        uint256 totalDemandAssets;
        uint256 totalPendingShares;
        uint256[] assets;
        uint256[] shares;
        bool canBeRemoved;
        IRedeemQueue.Request[][] userRequests;
    }

    address public constant LIDO_MELLOW_PROXY_ADMIN = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public constant OLD_IMPLEMENTATION = 0x0000000285805eac535DADdb9648F1E10DfdC411;
    address public constant NEW_IMPLEMENTATION = 0x000000000c139266BA06170Ed1DeacA6d11903c1;

    function getState(RedeemQueue queue, address[] memory users) internal view returns (State memory $) {
        $.vault = address(queue.vault());
        $.asset = address(queue.asset());
        ($.batchIterator, $.batchesLength, $.totalDemandAssets, $.totalPendingShares) = queue.getState();
        uint256 length = $.batchesLength + 1;
        $.assets = new uint256[](length);
        $.shares = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            ($.assets[i], $.shares[i]) = queue.batchAt(i);
        }
        $.canBeRemoved = queue.canBeRemoved();
        $.userRequests = new IRedeemQueue.Request[][](users.length);

        for (uint256 i = 0; i < users.length; i++) {
            $.userRequests[i] = queue.requestsOf(users[i], 0, type(uint256).max);
        }
    }

    function getProxyInfo(address proxyContract)
        internal
        view
        returns (address implementation, ProxyAdmin proxyAdmin, address owner)
    {
        bytes memory bytecode = proxyContract.code;
        assembly {
            proxyAdmin := mload(add(bytecode, 48))
        }
        owner = proxyAdmin.owner();
        bytes32 value = vm.load(proxyContract, ERC1967Utils.IMPLEMENTATION_SLOT);
        implementation = address(uint160(uint256(value)));
    }

    function migrate(RedeemQueue queue) internal {
        (address currentImplementation, ProxyAdmin proxyAdmin, address proxyAdminOwner) = getProxyInfo(address(queue));
        assertEq(currentImplementation, OLD_IMPLEMENTATION);
        assertEq(proxyAdminOwner, LIDO_MELLOW_PROXY_ADMIN);

        vm.startPrank(proxyAdminOwner);

        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(queue)), NEW_IMPLEMENTATION, new bytes(0));

        vm.stopPrank();

        (currentImplementation,, proxyAdminOwner) = getProxyInfo(address(queue));
        assertEq(currentImplementation, NEW_IMPLEMENTATION);
        assertEq(proxyAdminOwner, LIDO_MELLOW_PROXY_ADMIN);
    }

    function runTest(Vault vault, address[] memory users) internal {
        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = vault.assetAt(i);
            for (uint256 j = 0; j < vault.getQueueCount(asset); j++) {
                address queueAddress = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queueAddress)) {
                    continue;
                }
                RedeemQueue queue = RedeemQueue(payable(queueAddress));
                State memory stateBefore = getState(queue, users);
                migrate(queue);
                State memory stateAfter = getState(queue, users);
                assertEq(keccak256(abi.encode(stateBefore)), keccak256(abi.encode(stateAfter)));
            }
        }
    }

    function testRedeemQueueMigration_strETH_NO_CI() external {
        Vault vault = Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5));

        uint256 iterator = 0;
        address[] memory users = new address[](10);
        users[iterator++] = 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3;
        users[iterator++] = 0xD7dE0f3f1ba06533305eAe8Dd626aF44e093713e;
        users[iterator++] = 0x919A158a38bbA0EE20BcAa13b10Bf90A4960a361;
        users[iterator++] = 0x7f4Dc0e83F753A815eDD01E345641d2Fe013bEc5;
        users[iterator++] = 0x46F996328Bf027CC2DAA8bCf77c3A1d064a8a383;
        users[iterator++] = 0x9E2cE511a2d87E8Baf11aA81234e12bce46793e7;
        assembly {
            mstore(users, iterator)
        }

        runTest(vault, users);
    }

    function testRedeemQueueMigration_rstETHPlus_NO_CI() external {
        Vault vault = Vault(payable(0x1DDA0c028555e846371655caB6Adf0E3307c29F6));

        uint256 iterator = 0;
        address[] memory users = new address[](10);
        users[iterator++] = 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3;
        assembly {
            mstore(users, iterator)
        }

        runTest(vault, users);
    }

    function testRedeemQueueMigration_rstETHPlusPlus_NO_CI() external {
        Vault vault = Vault(payable(0xd41f177Ec448476d287635CD3AE21457F94c2307));

        uint256 iterator = 0;
        address[] memory users = new address[](10);
        users[iterator++] = 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3;
        assembly {
            mstore(users, iterator)
        }

        runTest(vault, users);
    }
}
