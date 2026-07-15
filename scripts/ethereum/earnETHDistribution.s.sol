// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IShareManager} from "../../src/interfaces/managers/IShareManager.sol";

interface IURD {
    function claim(address account, address reward, uint256 claimable, bytes32[] calldata proof)
        external
        returns (uint256 amount);
}

contract Deploy is Script, Test {
    address public constant URD = 0x4a3dd51476aa7768EdED42a3DE548F4d7F73973F;
    address public constant EARNETH = 0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4;
    uint256 public constant TOTAL_AMOUNT = 58040288971165746373;
    uint256 public constant TOTAL_USERS = 686;

    function claimAndCheck(string memory json, uint256 index) public returns (uint256) {
        bytes32[] memory proof =
            vm.parseJsonBytes32Array(json, string.concat(".leaves[", vm.toString(index), "].proof"));
        address account = vm.parseJsonAddress(json, string.concat(".leaves[", vm.toString(index), "].account"));
        uint256 claimable = vm.parseJsonUint(json, string.concat(".leaves[", vm.toString(index), "].claimable"));

        uint256 balanceBefore = IShareManager(EARNETH).sharesOf(account);
        require(IURD(URD).claim(account, EARNETH, claimable, proof) == claimable, "claimable != claimed");
        uint256 balanceAfter = IShareManager(EARNETH).sharesOf(account);
        require(balanceBefore + claimable == balanceAfter, "claimable != claimed actually");
        console.log("User %s got required shares", account);

        return claimable;
    }

    function run() external {
        string memory json = vm.readFile("./scripts/ethereum/earnETHProofs.json");

        deal(EARNETH, URD, TOTAL_AMOUNT);

        uint256 totalClaimed = 0;
        for (uint256 i = 0; i < TOTAL_USERS; i++) {
            totalClaimed += claimAndCheck(json, i);
        }

        require(totalClaimed == TOTAL_AMOUNT, "Invalid total distributed amount");
        require(IShareManager(EARNETH).sharesOf(URD) == 0, "Non-zero URD balance after full distribution");
    }
}
