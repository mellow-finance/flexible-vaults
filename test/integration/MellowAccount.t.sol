// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/common/Permissions.sol";
import "../../scripts/ethereum/Constants.sol";
import "../Imports.sol";
import "forge-std/Test.sol";

import "../../src/accounts/MellowAccountV1.sol";

contract Integration is Test {
    Vault vault = Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5));

    function testMulticall() external {
        address admin = vault.getRoleMember(Permissions.DEFAULT_ADMIN_ROLE, 0);

        address curator = vm.createWallet("curator-wallet").addr;
        MellowAccountV1 impl = new MellowAccountV1();
        MellowAccountV1 account = MellowAccountV1(
            address(
                new TransparentUpgradeableProxy(
                    address(impl), admin, abi.encodeCall(IFactoryEntity.initialize, (abi.encode(curator)))
                )
            )
        );

        address subvault0 = vault.subvaultAt(0);
        address subvault1 = vault.subvaultAt(1);

        vm.startPrank(admin);
        vault.grantRole(Permissions.PULL_LIQUIDITY_ROLE, address(account));
        vault.grantRole(Permissions.PUSH_LIQUIDITY_ROLE, address(account));
        vault.grantRole(Permissions.CALLER_ROLE, address(account));
        vault.grantRole(Permissions.ALLOW_CALL_ROLE, admin);

        IVerifier.CompactCall[] memory allowedCalls = new IVerifier.CompactCall[](3);
        allowedCalls[0] = IVerifier.CompactCall({
            who: address(account),
            where: Constants.AAVE_CORE,
            selector: IAavePoolV3.supply.selector
        });
        allowedCalls[1] = IVerifier.CompactCall({
            who: address(account),
            where: Constants.AAVE_CORE,
            selector: IAavePoolV3.borrow.selector
        });
        allowedCalls[2] =
            IVerifier.CompactCall({who: address(account), where: Constants.WSTETH, selector: IERC20.approve.selector});

        IVerifierModule(subvault1).verifier().allowCalls(allowedCalls);
        vm.stopPrank();

        uint256 balance = 1 ether;
        deal(Constants.WSTETH, subvault0, balance);

        uint256 i = 0;
        MellowAccountV1.Call[] memory calls = new MellowAccountV1.Call[](7);
        calls[i++] = MellowAccountV1.Call({
            target: address(vault),
            data: abi.encodeCall(vault.pullAssets, (subvault0, Constants.WSTETH, balance))
        });
        calls[i++] = MellowAccountV1.Call({
            target: address(vault),
            data: abi.encodeCall(vault.pushAssets, (subvault1, Constants.WSTETH, balance))
        });
        IVerifier.VerificationPayload memory payload;
        calls[i++] = MellowAccountV1.Call({
            target: subvault1,
            data: abi.encodeCall(
                ICallModule.call,
                (Constants.WSTETH, 0, abi.encodeCall(IERC20.approve, (Constants.AAVE_CORE, balance)), payload)
            )
        });

        calls[i++] = MellowAccountV1.Call({
            target: subvault1,
            data: abi.encodeCall(
                ICallModule.call,
                (
                    Constants.AAVE_CORE,
                    0,
                    abi.encodeCall(IAavePoolV3.supply, (Constants.WSTETH, balance, subvault1, 0)),
                    payload
                )
            )
        });

        calls[i++] = MellowAccountV1.Call({
            target: subvault1,
            data: abi.encodeCall(
                ICallModule.call,
                (
                    Constants.AAVE_CORE,
                    0,
                    abi.encodeCall(IAavePoolV3.borrow, (Constants.WETH, balance, 2, 0, subvault1)),
                    payload
                )
            )
        });

        calls[i++] = MellowAccountV1.Call({
            target: address(vault),
            data: abi.encodeCall(vault.pullAssets, (subvault1, Constants.WETH, balance))
        });

        calls[i++] = MellowAccountV1.Call({
            target: address(vault),
            data: abi.encodeCall(vault.pushAssets, (subvault0, Constants.WETH, balance))
        });

        assembly {
            mstore(calls, i)
        }

        vm.startPrank(curator);
        account.multicall(calls);
        vm.stopPrank();
    }
}
