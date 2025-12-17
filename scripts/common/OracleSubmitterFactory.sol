// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/oracles/OracleSubmitter.sol";
import "./interfaces/IOracleSubmitterFactory.sol";

contract OracleSubmitterFactory is IOracleSubmitterFactory {
    event OracleSubmitterDeployed(address indexed oracleSubmitter, address indexed deployer);

    function deployOracleSubmitter(address admin_, address submitter_, address accepter_, address oracle_)
        external
        returns (address)
    {
        bytes32 salt = keccak256(abi.encode(admin_, submitter_, accepter_, oracle_));
        OracleSubmitter oracleSubmitter = new OracleSubmitter{salt: salt}(admin_, submitter_, accepter_, oracle_);
        emit OracleSubmitterDeployed(address(oracleSubmitter), msg.sender);
        return address(oracleSubmitter);
    }
}
