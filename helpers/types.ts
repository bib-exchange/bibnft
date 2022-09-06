import BigNumber from 'bignumber.js';
import { eEthereumNetwork } from './types-common';

export enum eContractid {
  MockBib="MockBIB",
  MockBusd = "MockBUSD",
  MockBibOracle = "MockBIBOracle",
  BibOracle = "BibOracle",
  IterableMapping = "IterableMapping",
  IERC20Detailed = 'IERC20Detailed',
  SoccerStarNft = "SoccerStarNft",
  SoccerStarNftImpl = "SoccerStarNftImpl",
  DividendCollector = "DividendCollector",
  DividendCollectorImpl = "DividendCollectorImpl",
  ComposedSoccerStarNft = "ComposedSoccerStarNft",
  ComposedSoccerStarNftImpl = "ComposedSoccerStarNftImpl",
  SoccerStarNftMarket = "SoccerStarNftMarket",
  SoccerStarNftMarketImpl = "SoccerStarNftMarketImpl",
  StakedSoccerStarNftV2 = "StakedSoccerStarNftV2",
  StakedSoccerStarNftV2Impl = "StakedSoccerStarNftV2Impl",
  StakedDividendTracker = "StakedDividendTracker",
  StakedDividendTrackerImpl = "StakedDividendTrackerImpl",
  FeeCollector = "FeeCollector",
  FeeCollectorImpl = 'FeeCollectorImpl',
  InitializableAdminUpgradeabilityProxy = "InitializableAdminUpgradeabilityProxy",
  StakedRewardUiDataProvider = "StakedRewardUiDataProvider",
  BIBNode = "BIBNode",
  BIBNodeImpl = "BIBNodeImpl",
  BIBDividend = "BIBDividend",
  BIBDividendImpl = "BIBDividendImpl",
  BIBStaking = "BIBStaking",
  BIBStakingImpl = "BIBStakingImpl",
  Faucet = "Faucet",
  IFreezeToken = "IFreezeToken",
  ITokenDividendTracker = "ITokenDividendTracker"
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
