import BigNumber from 'bignumber.js';
import { eEthereumNetwork } from './types-common';

export enum eContractid {
  MockBib="MockBIB",
  MockBusd = "MockBUSD",
  MockBibOracle = "MockBIBOracle",
  IERC20Detailed = 'IERC20Detailed',
  SoccerStarNft = "SoccerStarNft",
  StakedSoccerStarNftV2 = "StakedSoccerStarNftV2",
  InitializableAdminUpgradeabilityProxy = "InitializableAdminUpgradeabilityProxy"
}

export enum ProtocolErrors {}

export type tEthereumAddress = string;
export type tStringTokenBigUnits = string; // 1 ETH, or 10e6 USDC or 10e18 DAI
export type tBigNumberTokenBigUnits = BigNumber;
export type tStringTokenSmallUnits = string; // 1 wei, or 1 basic unit of USDC, or 1 basic unit of DAI
export type tBigNumberTokenSmallUnits = BigNumber;

export interface iParamsPerNetwork<T> {
  [eEthereumNetwork.coverage]: T;
  [eEthereumNetwork.hardhat]: T;
  [eEthereumNetwork.bsc_test]: T;
  [eEthereumNetwork.bsc]: T;
}
