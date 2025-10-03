// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../permissions/MellowACL.sol";

contract AssetOracle is MellowACL {
    enum OracleType {
        CHAINLINK,
        CONSTANT,
        
    }
    
    struct AssetInfo {
        OracleType t;
        
    }
    
    struct AssetOracleStorage {
        address baseAsset;
        
    }
    
    constructor(string memory name_, uint256 version_) MellowACL(name_, version_) {}

    function getAssetPrice(address asset) public view returns (uint256) {

    }

}
