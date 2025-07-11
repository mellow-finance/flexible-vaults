// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract Mock {
    address public admin;
    uint256 public version;
    string public name;

    function initialize(bytes calldata data) external {
        (admin, version, name) = abi.decode(data, (address, uint256, string));
    }

    function test() external {}
}

contract FactoryTest is Test {
    address admin = vm.createWallet("admin").addr;
    address proxyAdmin = vm.createWallet("proxyAdmin").addr;

    function testCreate() external {
        uint256 version = 1;

        Factory factory = createFactory("Factory", version, admin);

        require(factory.owner() == admin, "wrong admin");
        require(factory.entities() == 0, "entities is not empty");
        require(factory.implementations() == 0, "implementations is not empty");
        require(factory.proposals() == 0, "proposals is not empty");

        vm.expectRevert();
        factory.entityAt(0);

        require(!factory.isEntity(address(0)), "address(0) is an entity");

        vm.expectRevert();
        factory.implementationAt(0);

        vm.expectRevert();
        factory.proposalAt(0);

        require(!factory.isBlacklisted(version), "version is blacklisted");
    }

    function testProposeAndAcceptImplementation() external {
        Factory factory = createFactory("Factory", 1, admin);

        address newImplementation = address(new Mock());

        factory.proposeImplementation(newImplementation);
        require(factory.proposalAt(0) == newImplementation, "mismatch proposal implementation");

        vm.expectRevert(abi.encodeWithSelector(IFactory.ImplementationAlreadyProposed.selector, newImplementation));
        factory.proposeImplementation(newImplementation);

        vm.prank(admin);
        factory.acceptProposedImplementation(newImplementation);

        vm.expectRevert("panic: array out-of-bounds access (0x32)");
        factory.proposalAt(0);

        vm.expectRevert(abi.encodeWithSelector(IFactory.ImplementationAlreadyAccepted.selector, newImplementation));
        factory.proposeImplementation(newImplementation);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IFactory.ImplementationNotProposed.selector, newImplementation));
        factory.acceptProposedImplementation(newImplementation);

        require(factory.implementationAt(0) == newImplementation, "mismatch accepted implementation");
    }

    function testBlackList() external {
        Factory factory = createFactory("Factory", 1, admin);

        address newFactoryImplementation = address(new Factory("FactoryNew", 1));
        pushImplementation(factory, newFactoryImplementation);

        vm.prank(admin);
        factory.setBlacklistStatus(0, true);
        require(factory.isBlacklisted(0), "version was not blacklisted");

        vm.prank(admin);
        vm.expectRevert("OutOfBounds(1)");
        factory.setBlacklistStatus(1, true);
    }

    function testCreateEntity() external {
        address ownerContract = vm.createWallet("ownerFactory").addr;
        address adminContract = vm.createWallet("adminFactory").addr;
        Factory factory = createFactory("Factory", 1, admin);
        bytes memory callData = abi.encode(address(adminContract), 0, "MockContract");

        {
            address newImplementation = address(new Mock());
            pushImplementation(factory, newImplementation);
            vm.expectRevert("OutOfBounds(1)");
            factory.create(1, ownerContract, callData);
        }
        {
            address newImplementation = address(new Mock());
            pushImplementation(factory, newImplementation);
            vm.prank(admin);
            factory.setBlacklistStatus(0, true);
            require(factory.isBlacklisted(0), "version was not blacklisted");

            vm.expectRevert("BlacklistedVersion(0)");
            factory.create(0, ownerContract, callData);
        }
    }

    /// ------------------------------------------ HELPER FUNCTIONS -------------------------------------------------

    function createFactory(string memory name, uint256 version, address admin_) internal returns (Factory factory) {
        Factory factoryImplementation = new Factory(name, version);
        factory =
            Factory(address(new TransparentUpgradeableProxy(address(factoryImplementation), proxyAdmin, new bytes(0))));
        factory.initialize(abi.encode(admin_));
    }

    function pushImplementation(Factory factory, address newImplementation) internal {
        factory.proposeImplementation(newImplementation);
        vm.prank(factory.owner());
        factory.acceptProposedImplementation(newImplementation);
    }
}
