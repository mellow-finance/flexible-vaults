// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import "../ProofLibrary.sol";

import "../interfaces/ICoreWriter.sol";
import "../interfaces/Imports.sol";

library HyperLiquidLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    /// @dev actionId with sensible params
    uint24 public constant LIMIT_ORDER = 1; // (assetId, ...)
    uint24 public constant VAULT_TRANSFER = 2; // (vault, ...)
    uint24 public constant TOKEN_DELEGATE = 3; // (validator, ...)
    uint24 public constant STAKING_DEPOSIT = 4;
    uint24 public constant STAKING_WITHDRAW = 5;
    uint24 public constant SPOT_SEND = 6; // (destination, token, ...)
    uint24 public constant USD_CLASS_TRANSFER = 7;
    uint24 public constant FINALIZE_EVM_CONTRACT = 8;
    uint24 public constant ADD_API_WALLET = 9; // (apiWallet, ...) 0x20 + string
    uint24 public constant CANCEL_ORDER_BY_OID = 10; // (assetId, ...)
    uint24 public constant CANCEL_ORDER_BY_CLOID = 11; // (assetId, ...)

    struct Info {
        address strategy;
        address hype;
        uint32 hypeTokenIndex;
        address core;
        address[] assets;
        uint8 version;
        address systemAddress;
        ActionParams params;
    }

    struct ActionParams {
        uint24[] actions; // ids of actions: limit, spot, usd class, cancels etc
        Token[] tokens; // spot send,  limit, cancels
        address[] vaults; // vault transfers
        address[] validators; // token delegate
        address[] apiWallets; // add api wallet
    }

    /*
        spot: assetId = 10000 + pairIndex
        perp: assetId = coinIndex
    */
    struct Token {
        address addr; // evm address
        uint64 id; // token index in HyperLiquid (addr<->index mapping, system address = 0x20...[index])
        uint32[] assets; // asset id in HyperLiquid (relates to trading pairs). One token can participate in multiple assets (trading pairs both spot and perp)
    }

    function getHyperLiquidProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            0. hype.call{value: any}("") deposits HYPE to Core
            1. withdraw Hype to EVM
            2. token.transfer(systemAddress, any) deposits ERC20 to Core
            3. coreWriter.sendRawAction(actions + any params)
        */

        // 0. hype native send
        uint256 length = getTotalActionsCount($);
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.strategy,
            $.hype,
            0,
            abi.encode(bytes4(0)),
            ProofLibrary.makeBitmask(true, true, false, true, abi.encode(bytes4(0)))
        );

        // 1. withdraw Hype to EVM: CoreWriter spot send to hype with hype token index
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.strategy,
            $.core,
            0,
            _encodeCoreWriterSendRawAction($.version, SPOT_SEND, abi.encode($.hype, $.hypeTokenIndex, 0)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                _encodeCoreWriterSendRawAction(
                    $.version, SPOT_SEND, abi.encode(address(type(uint160).max), type(uint32).max, 0)
                )
            )
        );

        // 2. approves transfers of specified ERC20 tokens to their corresponding Core system addresses
        for (uint256 i = 0; i < $.params.tokens.length; i++) {
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.strategy,
                $.params.tokens[i].addr,
                0,
                abi.encodeWithSelector(IERC20.transfer.selector, _coreSystemAddress($.params.tokens[i].id), 0),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeWithSelector(IERC20.transfer.selector, address(type(uint160).max), 0)
                )
            );
        }

        // 3. sendRawAction calldata: abi.encodePacked(uint8(0x01), bytes3(actionId), encodedActionSpecificParams);
        for (uint256 i = 0; i < $.params.actions.length; i++) {
            (bytes[] memory data, bytes[] memory bitmask,,) = getVerificationActionDataBitmask($.params.actions[i], $);
            for (uint256 j = 0; j < data.length; j++) {
                leaves[index++] = ProofLibrary.makeVerificationPayload(
                    bitmaskVerifier,
                    $.strategy,
                    $.core,
                    0,
                    data[j],
                    ProofLibrary.makeBitmask(true, true, true, true, bitmask[j])
                );
            }
        }
    }

    function getHyperLiquidDescription(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = getTotalActionsCount($);
        descriptions = new string[](length);
        uint256 index;

        descriptions[index++] = JsonLibrary.toJson(
            "HYPE.call{value: any}()",
            "null",
            ParameterLibrary.build(Strings.toHexString($.strategy), Strings.toHexString($.hype), "any"),
            new ParameterLibrary.Parameter[](0)
        );

        {
            uint32 hypeTokenIndex = $.hypeTokenIndex;
            ParameterLibrary.Parameter[] memory innerParameters =
                ParameterLibrary.build("version", Strings.toHexString($.version));
            innerParameters = innerParameters.add("action", Strings.toString(SPOT_SEND));
            innerParameters = innerParameters.add("hype", Strings.toHexString($.hype));
            innerParameters = innerParameters.add("tokenId", Strings.toString(hypeTokenIndex));
            innerParameters = innerParameters.addAny("amount");
            descriptions[index++] = JsonLibrary.toJson(
                string(abi.encodePacked("SPOT_SEND HYPE (withdraw to EVM) ", Strings.toString(hypeTokenIndex))),
                ABILibrary.getABI(ICoreWriter.sendRawAction.selector),
                ParameterLibrary.build(Strings.toHexString($.strategy), Strings.toHexString($.core), "0"),
                innerParameters
            );
        }

        for (uint256 i = 0; i < $.params.tokens.length; i++) {
            string memory assetSymbol = IERC20Metadata($.params.tokens[i].addr).symbol();
            address coreSystemAddr = _coreSystemAddress($.params.tokens[i].id);
            descriptions[index++] = JsonLibrary.toJson(
                string(abi.encodePacked("IERC20(", assetSymbol, ").transfer(Core, any)")),
                ABILibrary.getABI(IERC20.transfer.selector),
                ParameterLibrary.build(
                    Strings.toHexString($.strategy), Strings.toHexString($.params.tokens[i].addr), "0"
                ),
                ParameterLibrary.build("to", Strings.toHexString(coreSystemAddr)).add("amount", "any")
            );
        }

        for (uint256 i = 0; i < $.params.actions.length; i++) {
            (,, string[] memory actionDescriptions,) = getVerificationActionDataBitmask($.params.actions[i], $);
            for (uint256 j = 0; j < actionDescriptions.length; j++) {
                descriptions[index++] = actionDescriptions[j];
            }
        }
    }

    function getHyperLiquidCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index;
        calls = new Call[][](100);
        // hype.call{value: any}("")
        {
            Call[] memory tmp = new Call[](5);
            uint256 idx;
            tmp[idx++] = Call($.strategy, $.hype, 0, abi.encode(bytes4(0)), true);
            tmp[idx++] = Call($.strategy, $.hype, 1 ether, abi.encode(bytes4(0)), true);
            tmp[idx++] = Call(address(0xdead), $.hype, 0, abi.encode(bytes4(0)), false);
            tmp[idx++] = Call($.strategy, address(0xdead), 0, abi.encode(bytes4(0)), false);
            tmp[idx++] = Call($.strategy, $.hype, 0, abi.encodeWithSelector(bytes4(0x00000001), ""), false);
            calls[index++] = tmp;
        }
        // withdraw Hype to EVM: CoreWriter.spotSend(hype, hypeTokenIndex, any)
        {
            Call[] memory tmp = new Call[](9);
            uint256 idx;
            tmp[idx++] = Call(
                $.strategy,
                $.core,
                0,
                _encodeCoreWriterSendRawAction($.version, SPOT_SEND, abi.encode($.hype, $.hypeTokenIndex, 0)),
                true
            );
            tmp[idx++] = Call(
                $.strategy,
                $.core,
                0,
                _encodeCoreWriterSendRawAction($.version, SPOT_SEND, abi.encode($.hype, $.hypeTokenIndex, 1 ether)),
                true
            );
            tmp[idx++] = Call(
                $.strategy,
                $.core,
                1 wei,
                _encodeCoreWriterSendRawAction($.version, SPOT_SEND, abi.encode($.hype, $.hypeTokenIndex, 0)),
                false
            );
            tmp[idx++] = Call(
                $.strategy,
                $.core,
                0,
                _encodeCoreWriterSendRawAction($.version, ADD_API_WALLET, abi.encode($.hype, $.hypeTokenIndex, 0)),
                false
            );
            tmp[idx++] = Call(
                $.strategy,
                $.core,
                0,
                _encodeCoreWriterSendRawAction($.version + 1, SPOT_SEND, abi.encode($.hype, $.hypeTokenIndex, 0)),
                false
            );
            tmp[idx++] = Call(
                $.strategy,
                $.core,
                0,
                _encodeCoreWriterSendRawAction($.version, SPOT_SEND, abi.encode(address(0xdead), $.hypeTokenIndex, 0)),
                false
            );
            tmp[idx++] = Call(
                $.strategy,
                $.core,
                0,
                _encodeCoreWriterSendRawAction($.version, SPOT_SEND, abi.encode($.hype, $.hypeTokenIndex + 1, 0)),
                false
            );
            tmp[idx++] = Call(
                address(0xdead),
                $.core,
                0,
                _encodeCoreWriterSendRawAction($.version, SPOT_SEND, abi.encode($.hype, $.hypeTokenIndex, 0)),
                false
            );
            tmp[idx++] = Call(
                $.strategy,
                address(0xdead),
                0,
                _encodeCoreWriterSendRawAction($.version, SPOT_SEND, abi.encode($.hype, $.hypeTokenIndex, 0)),
                false
            );

            calls[index++] = tmp;
        }
        // erc20.transfer(systemAddress, any)
        {
            for (uint256 i = 0; i < $.params.tokens.length; i++) {
                Call[] memory tmp = new Call[](7);
                uint256 idx;
                address erc20Address = $.params.tokens[i].addr;
                address systemAddress = _coreSystemAddress($.params.tokens[i].id);
                tmp[idx++] = Call(
                    $.strategy,
                    erc20Address,
                    0,
                    abi.encodeWithSelector(IERC20.transfer.selector, systemAddress, 0),
                    true
                );
                tmp[idx++] = Call(
                    $.strategy,
                    erc20Address,
                    0,
                    abi.encodeWithSelector(IERC20.transfer.selector, systemAddress, 1 ether),
                    true
                );
                tmp[idx++] = Call(
                    $.strategy,
                    erc20Address,
                    1 wei,
                    abi.encodeWithSelector(IERC20.transfer.selector, systemAddress, 0),
                    false
                );
                tmp[idx++] = Call(
                    $.strategy,
                    erc20Address,
                    0,
                    abi.encodeWithSelector(IERC20.transfer.selector, address(0xdead), 0),
                    false
                );
                tmp[idx++] = Call(
                    address(0xdead),
                    erc20Address,
                    0,
                    abi.encodeWithSelector(IERC20.transfer.selector, systemAddress, 0),
                    false
                );
                tmp[idx++] = Call(
                    $.strategy,
                    address(0xdead),
                    0,
                    abi.encodeWithSelector(IERC20.transfer.selector, systemAddress, 0),
                    false
                );
                tmp[idx++] =
                    Call($.strategy, erc20Address, 0, abi.encode(IERC20.transfer.selector, systemAddress, 0), false);
                calls[index++] = tmp;
            }
        }
        // Core.sendRawAction(abi.encodePacked(uint8(0x01), bytes3(actionId), encodedActionSpecificParams))
        {
            for (uint256 i = 0; i < $.params.actions.length; i++) {
                (bytes[] memory validCalldata,,, bytes[] memory forbiddenCallData) =
                    getVerificationActionDataBitmask($.params.actions[i], $);
                for (uint256 j = 0; j < validCalldata.length; j++) {
                    Call[] memory tmp = new Call[](5 + forbiddenCallData.length);
                    uint256 idx;
                    tmp[idx++] = Call($.strategy, $.core, 0, validCalldata[j], true);
                    tmp[idx++] = Call($.strategy, $.core, 1 ether, validCalldata[j], false);
                    tmp[idx++] = Call(address(0xdead), $.core, 0, validCalldata[j], false);
                    tmp[idx++] = Call($.strategy, address(0xdead), 0, validCalldata[j], false);
                    for (uint256 k = 0; k < forbiddenCallData.length; k++) {
                        tmp[idx++] = Call($.strategy, $.core, 0, forbiddenCallData[k], false);
                    }
                    calls[index++] = tmp;
                }
            }
        }
        assembly {
            mstore(calls, index)
        }
    }

    function getVerificationActionDataBitmask(uint24 action, Info memory info)
        internal
        pure
        returns (
            bytes[] memory data,
            bytes[] memory bitmask,
            string[] memory descriptions,
            bytes[] memory forbiddenData
        )
    {
        ActionParams memory $ = info.params;
        uint256 dummyParamsLength; // remaining params to fill with zeros (that means "any" value)
        ParameterLibrary.Parameter[] memory parameters =
            ParameterLibrary.build(Strings.toHexString(info.strategy), Strings.toHexString(info.core), "0");
        ParameterLibrary.Parameter[] memory innerParameters =
            ParameterLibrary.build("version", Strings.toHexString(info.version)).add("action", Strings.toString(action));

        if (action == LIMIT_ORDER) {
            uint256 assetsCount = _getAssetsCount($.tokens);
            // approves limit order for all specified assets
            dummyParamsLength = 6;
            data = new bytes[](assetsCount);
            bitmask = new bytes[](assetsCount);
            descriptions = new string[](assetsCount);
            forbiddenData = new bytes[](assetsCount);
            uint256 assetIndex;
            for (uint256 i = 0; i < $.tokens.length; i++) {
                for (uint256 j = 0; j < $.tokens[i].assets.length; j++) {
                    data[assetIndex] = abi.encode($.tokens[i].assets[j]);
                    bitmask[assetIndex] = abi.encode(type(uint256).max);
                    forbiddenData[assetIndex] = abi.encode(type(uint32).max - $.tokens[i].assets[j]);

                    innerParameters = innerParameters.add("assetId", Strings.toString($.tokens[i].assets[j]));
                    innerParameters = innerParameters.addAny("isBuy");
                    innerParameters = innerParameters.addAny("limitPx");
                    innerParameters = innerParameters.addAny("sz");
                    innerParameters = innerParameters.addAny("reduceOnly");
                    innerParameters = innerParameters.addAny("tif");
                    innerParameters = innerParameters.addAny("cloid");
                    descriptions[assetIndex] = JsonLibrary.toJson(
                        string(abi.encodePacked("LIMIT_ORDER for asset ", Strings.toString($.tokens[i].assets[j]))),
                        ABILibrary.getABI(ICoreWriter.sendRawAction.selector),
                        parameters,
                        innerParameters
                    );
                    assetIndex++;
                }
            }
        } else if (action == VAULT_TRANSFER) {
            // approves transfers to vaults
            dummyParamsLength = 2;
            data = new bytes[]($.vaults.length);
            bitmask = new bytes[]($.vaults.length);
            descriptions = new string[]($.vaults.length);
            forbiddenData = new bytes[]($.vaults.length);
            for (uint256 i = 0; i < $.vaults.length; i++) {
                data[i] = abi.encode($.vaults[i]);
                bitmask[i] = abi.encode(address(type(uint160).max));
                forbiddenData[i] = abi.encode(address(0xdead));
                innerParameters = innerParameters.add("vault", Strings.toHexString($.vaults[i]));
                innerParameters = innerParameters.addAny("isDeposit");
                innerParameters = innerParameters.addAny("usdAmount");
                descriptions[i] = JsonLibrary.toJson(
                    string(abi.encodePacked("VAULT_TRANSFER for vault ", Strings.toHexString($.vaults[i]))),
                    ABILibrary.getABI(ICoreWriter.sendRawAction.selector),
                    parameters,
                    innerParameters
                );
            }
        } else if (action == TOKEN_DELEGATE) {
            // approves delegation to validators
            dummyParamsLength = 2;
            data = new bytes[]($.validators.length);
            bitmask = new bytes[]($.validators.length);
            descriptions = new string[]($.validators.length);
            forbiddenData = new bytes[]($.validators.length);
            for (uint256 i = 0; i < $.validators.length; i++) {
                data[i] = abi.encode($.validators[i]);
                bitmask[i] = abi.encode(address(type(uint160).max));
                forbiddenData[i] = abi.encode(address(0xdead));
                innerParameters = innerParameters.add("validator", Strings.toHexString($.validators[i]));
                innerParameters = innerParameters.addAny("amount");
                innerParameters = innerParameters.addAny("isUndelegate");
                descriptions[i] = JsonLibrary.toJson(
                    string(abi.encodePacked("VAULT_TRANSFER for validator ", Strings.toHexString($.validators[i]))),
                    ABILibrary.getABI(ICoreWriter.sendRawAction.selector),
                    parameters,
                    innerParameters
                );
            }
        } else if (action == STAKING_DEPOSIT) {
            // approves staking deposit
            dummyParamsLength = 1;
            data = new bytes[](1);
            bitmask = new bytes[](1);
            descriptions = new string[](1);
            forbiddenData = new bytes[](0);
            data[0] = "";
            bitmask[0] = "";
            descriptions[0] = JsonLibrary.toJson(
                "STAKING_DEPOSIT",
                ABILibrary.getABI(ICoreWriter.sendRawAction.selector),
                parameters,
                innerParameters.addAny("amount")
            );
        } else if (action == STAKING_WITHDRAW) {
            // approves staking withdraw
            dummyParamsLength = 1;
            data = new bytes[](1);
            bitmask = new bytes[](1);
            descriptions = new string[](1);
            forbiddenData = new bytes[](0);
            data[0] = "";
            bitmask[0] = "";
            descriptions[0] = JsonLibrary.toJson(
                "STAKING_WITHDRAW",
                ABILibrary.getABI(ICoreWriter.sendRawAction.selector),
                parameters,
                innerParameters.addAny("amount")
            );
        } else if (action == SPOT_SEND) {
            // approves spot send specific tokens
            dummyParamsLength = 1;
            data = new bytes[]($.tokens.length);
            bitmask = new bytes[]($.tokens.length);
            descriptions = new string[]($.tokens.length);
            forbiddenData = new bytes[]($.tokens.length * 2);
            for (uint256 i = 0; i < $.tokens.length; i++) {
                address systemAddr = _coreSystemAddress($.tokens[i].id);

                data[i] = abi.encode(systemAddr, $.tokens[i].id);
                bitmask[i] = abi.encode(address(type(uint160).max), type(uint64).max);
                forbiddenData[i * $.tokens.length] = abi.encode(address(0xdead), $.tokens[i].id);
                forbiddenData[i * $.tokens.length + 1] = abi.encode(systemAddr, type(uint32).max - $.tokens[i].id);

                innerParameters = innerParameters.add("systemAddr", Strings.toHexString(systemAddr));
                innerParameters = innerParameters.add("tokenId", Strings.toString($.tokens[i].id));
                innerParameters = innerParameters.addAny("amount");
                descriptions[i] = JsonLibrary.toJson(
                    string(abi.encodePacked("SPOT_SEND for tokenId ", Strings.toString($.tokens[i].id))),
                    ABILibrary.getABI(ICoreWriter.sendRawAction.selector),
                    parameters,
                    innerParameters
                );
            }
        } else if (action == USD_CLASS_TRANSFER) {
            // approves usd class transfer
            dummyParamsLength = 2;
            data = new bytes[](1);
            bitmask = new bytes[](1);
            descriptions = new string[](1);
            forbiddenData = new bytes[](0);
            data[0] = "";
            bitmask[0] = "";
            innerParameters = innerParameters.addAny("ntl");
            innerParameters = innerParameters.addAny("amount");
            descriptions[0] = JsonLibrary.toJson(
                "USD_CLASS_TRANSFER", ABILibrary.getABI(ICoreWriter.sendRawAction.selector), parameters, innerParameters
            );
        } else if (action == FINALIZE_EVM_CONTRACT) {
            // approves finalize evm contract
            dummyParamsLength = 3;
            data = new bytes[](1);
            bitmask = new bytes[](1);
            descriptions = new string[](1);
            forbiddenData = new bytes[](0);
            data[0] = "";
            bitmask[0] = "";
            innerParameters = innerParameters.addAny("token");
            innerParameters = innerParameters.addAny("encodedFinalizeEvmContractVariant");
            innerParameters = innerParameters.addAny("createNonce");
            descriptions[0] = JsonLibrary.toJson(
                "FINALIZE_EVM_CONTRACT",
                ABILibrary.getABI(ICoreWriter.sendRawAction.selector),
                parameters,
                innerParameters
            );
        } else if (action == ADD_API_WALLET) {
            // approves adding api wallets with arbitrary string names
            dummyParamsLength = 1;
            data = new bytes[]($.apiWallets.length);
            bitmask = new bytes[]($.apiWallets.length);
            descriptions = new string[]($.apiWallets.length);
            forbiddenData = new bytes[]($.apiWallets.length);
            for (uint256 i = 0; i < $.apiWallets.length; i++) {
                data[i] = abi.encode($.apiWallets[i]);
                bitmask[i] = abi.encode(address(type(uint160).max));
                forbiddenData[i] = abi.encode(address(0xdead));
                innerParameters = innerParameters.add("address", Strings.toHexString($.apiWallets[i]));
                innerParameters = innerParameters.addAny("name");
                descriptions[i] = JsonLibrary.toJson(
                    string(abi.encodePacked("ADD_API_WALLET for address ", Strings.toHexString($.apiWallets[i]))),
                    ABILibrary.getABI(ICoreWriter.sendRawAction.selector),
                    parameters,
                    innerParameters
                );
            }
        } else if (action == CANCEL_ORDER_BY_OID) {
            uint256 assetsCount = _getAssetsCount($.tokens);
            // approves cancel order by oid for all specified assets
            dummyParamsLength = 1;
            data = new bytes[](assetsCount);
            bitmask = new bytes[](assetsCount);
            descriptions = new string[](assetsCount);
            forbiddenData = new bytes[](assetsCount);
            uint256 assetIndex;
            for (uint256 i = 0; i < $.tokens.length; i++) {
                for (uint256 j = 0; j < $.tokens[i].assets.length; j++) {
                    data[assetIndex] = abi.encode($.tokens[i].assets[j]);
                    bitmask[assetIndex] = abi.encode(type(uint32).max);
                    forbiddenData[assetIndex] = abi.encode(type(uint32).max - $.tokens[i].assets[j]);
                    innerParameters = innerParameters.add("assetId", Strings.toString($.tokens[i].assets[j]));
                    innerParameters = innerParameters.addAny("oid");
                    descriptions[assetIndex] = JsonLibrary.toJson(
                        string(
                            abi.encodePacked("CANCEL_ORDER_BY_OID for asset ", Strings.toString($.tokens[i].assets[j]))
                        ),
                        ABILibrary.getABI(ICoreWriter.sendRawAction.selector),
                        parameters,
                        innerParameters
                    );
                    assetIndex++;
                }
            }
        } else if (action == CANCEL_ORDER_BY_CLOID) {
            uint256 assetsCount = _getAssetsCount($.tokens);
            // approves cancel order by cloid for all specified assets
            dummyParamsLength = 1;
            data = new bytes[](assetsCount);
            bitmask = new bytes[](assetsCount);
            descriptions = new string[](assetsCount);
            forbiddenData = new bytes[](assetsCount);
            uint256 assetIndex;
            for (uint256 i = 0; i < $.tokens.length; i++) {
                for (uint256 j = 0; j < $.tokens[i].assets.length; j++) {
                    data[assetIndex] = abi.encode($.tokens[i].assets[j]);
                    bitmask[assetIndex] = abi.encode(type(uint32).max);
                    forbiddenData[assetIndex] = abi.encode(type(uint32).max - $.tokens[i].assets[j]);
                    innerParameters = innerParameters.add("assetId", Strings.toString($.tokens[i].assets[j]));
                    innerParameters = innerParameters.addAny("cloid");
                    descriptions[assetIndex] = JsonLibrary.toJson(
                        string(
                            abi.encodePacked(
                                "CANCEL_ORDER_BY_CLOID for asset ", Strings.toString($.tokens[i].assets[j])
                            )
                        ),
                        ABILibrary.getABI(ICoreWriter.sendRawAction.selector),
                        parameters,
                        innerParameters
                    );
                    assetIndex++;
                }
            }
        }

        for (uint256 i = 0; i < data.length; i++) {
            bytes memory padding = _makeDummyZeroCalldata(dummyParamsLength);
            data[i] = _encodeCoreWriterSendRawAction(info.version, action, abi.encodePacked(data[i], padding));
            bitmask[i] = _encodeCoreWriterSendRawAction(info.version, action, abi.encodePacked(bitmask[i], padding));
        }

        for (uint256 i = 0; i < forbiddenData.length; i++) {
            bytes memory padding = _makeDummyZeroCalldata(dummyParamsLength);
            forbiddenData[i] =
                _encodeCoreWriterSendRawAction(info.version, action, abi.encodePacked(forbiddenData[i], padding));
        }
    }

    function _encodeCoreWriterSendRawAction(uint8 version, uint24 action, bytes memory actionParams)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(ICoreWriter.sendRawAction, abi.encodePacked(version, action, actionParams));
    }

    function getTotalActionsCount(Info memory $) internal pure returns (uint256) {
        return _getCoreActions($) + $.params.tokens.length + 2;
    }

    // creates dummy calldata with zeros of specified length (each param is 32 bytes)
    function _makeDummyZeroCalldata(uint256 length) private pure returns (bytes memory) {
        return new bytes(0x20 * length);
    }

    /**
     *  @notice Computes the Core system address for a given token index.
     *  @dev System addresses have first byte 0x20 and token index encoded in big-endian in the low bytes.
     *  @param tokenIndex The token index to compute the system address for.
     *  @return The computed system address.
     */
    function _coreSystemAddress(uint64 tokenIndex) private pure returns (address) {
        // 20-byte address with first byte 0x20 and token index encoded in big-endian in the low bytes.
        uint256 prefix = uint256(0x20) << 152; // place 0x20 at the first byte of the address.
        return address(uint160(prefix | uint256(tokenIndex)));
    }

    /**
     *  @notice Calculates the total number of actions including those expanded by parameters.
     */
    function _getCoreActions(Info memory $) private pure returns (uint256 total) {
        uint256 assetsLength = _getAssetsCount($.params.tokens);
        for (uint256 i = 0; i < $.params.actions.length; i++) {
            uint24 action = $.params.actions[i];
            if (action == LIMIT_ORDER || action == CANCEL_ORDER_BY_OID || action == CANCEL_ORDER_BY_CLOID) {
                total += assetsLength;
            } else if (action == VAULT_TRANSFER) {
                total += $.params.vaults.length;
            } else if (action == TOKEN_DELEGATE) {
                total += $.params.validators.length;
            } else if (action == SPOT_SEND) {
                total += $.params.tokens.length;
            } else if (action == ADD_API_WALLET) {
                total += $.params.apiWallets.length;
            } else {
                total += 1;
            }
        }
    }

    function _getAssetsCount(Token[] memory tokens) private pure returns (uint256 count) {
        for (uint256 i = 0; i < tokens.length; i++) {
            count += tokens[i].assets.length;
        }
    }
}
