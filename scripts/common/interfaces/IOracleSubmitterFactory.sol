// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IOracleSubmitterFactory {
    function deployOracleSubmitter(address admin_, address submitter_, address accepter_, address oracle_)
        external
        returns (address);
}
