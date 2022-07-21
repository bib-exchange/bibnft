// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.0;

import {IBIBOracle} from  "../interfaces/IBIBOracle.sol";

/**
 * @title IBIBOracle interface
 * @notice Interface for the BIB oracle.
 **/

contract BIBOracle is IBIBOracle {
  function BASE_CURRENCY() public pure  override returns (address){
      return address(0);
  }

  function BASE_CURRENCY_UNIT() public pure override returns (uint256){
      return 1e18;
  }

  function getAssetPrice(address asset) public pure override returns (uint256){
      asset = asset;
      return 2 * 1e18;
  }
}
