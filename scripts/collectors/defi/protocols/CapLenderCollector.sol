// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../../src/libraries/TransferLibrary.sol";
import "./IDistributionCollector.sol";

import "../../../common/interfaces/IUsrExternalRequestsManager.sol";

contract CapLenderCollector is IDistributionCollector {
    /*
        what can we see in this lender contract at all?
        is this possible to collect more precise data?
        rather then
    */

    struct Deployment {}

    function getDistributions(address holder, bytes memory deployment, address[] memory /* assets */ )
        external
        view
        returns (Balance[] memory balances)
    {}
}
