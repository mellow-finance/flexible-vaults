// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function test() external {}
}

contract TransferWrapper {
    using TransferLibrary for address;

    function sendAssets(address asset, address to, uint256 amount) external {
        asset.sendAssets(to, amount);
    }

    function receiveAssets(address asset, address from, uint256 amount) external payable {
        asset.receiveAssets(from, amount);
    }

    function test() external {}
}

contract TransferLibraryTest is Test {
    TransferWrapper internal wrapper;
    ERC20Mock internal token;
    address deployer = vm.createWallet("deployer").addr;
    address user = vm.createWallet("admin").addr;

    function setUp() public {
        vm.prank(deployer);
        wrapper = new TransferWrapper();
        token = new ERC20Mock("Mock Token", "MOCK");
        token.mint(user, 100 ether);
        vm.deal(user, 100 ether);
    }

    function testSendAndReceiveETH() public {
        vm.prank(user);
        wrapper.receiveAssets{value: 1 ether}(TransferLibrary.ETH, user, 1 ether);
        assertEq(address(wrapper).balance, 1 ether);
        wrapper.sendAssets(TransferLibrary.ETH, user, 1 ether);
        assertEq(user.balance, 100 ether);
        assertEq(address(wrapper).balance, 0);
    }

    function testSendAndReceiveERC20() public {
        vm.startPrank(user);
        token.approve(address(wrapper), 50 ether);
        vm.stopPrank();
        vm.prank(user);
        wrapper.receiveAssets(address(token), user, 50 ether);
        assertEq(token.balanceOf(address(wrapper)), 50 ether);
        wrapper.sendAssets(address(token), user, 50 ether);
        assertEq(token.balanceOf(user), 100 ether);
        assertEq(token.balanceOf(address(wrapper)), 0);
    }

    function testReceiveETHWrongAmount() public {
        vm.prank(user);
        vm.expectRevert(TransferLibrary.InvalidValue.selector);
        wrapper.receiveAssets{value: 0.1 ether}(TransferLibrary.ETH, user, 1 ether);
    }
}
