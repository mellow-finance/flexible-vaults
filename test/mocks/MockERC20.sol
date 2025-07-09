// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockERC20", "ME20") {}

    function mint(address to, uint256 value) external {
        _mint(to, value);
    }

    function burn(address to, uint256 value) external {
        _burn(to, value);
    }

    function take(address from, uint256 value) external {
        _transfer(from, msg.sender, value);
    }

    function test() internal pure {}
}
