// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IEtherFiLiquidityPool {
  function requestWithdraw(address recipient, uint256 amount) external returns (uint256);
}

interface IWEETH {
  function unwrap(uint256 _weETHAmount) external returns (uint256);
}

interface IWithdrawRequestNFT {
  function claimWithdraw(uint256 tokenId) external;
}