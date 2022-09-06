import { tEthereumAddress } from './types';
import { getParamPerNetwork } from './misc-utils';
import { eEthereumNetwork } from './types-common';
import {BigNumber} from "bignumber.js";
import {BytesLike, ethers} from "ethers";

export const BUIDLEREVM_CHAINID = 31337;
export const COVERAGE_CHAINID = 1337;

export const ZERO_ADDRESS: tEthereumAddress = '0x0000000000000000000000000000000000000000';
export const ONE_ADDRESS = '0x0000000000000000000000000000000000000001';
export const MAX_UINT_AMOUNT =
  '115792089237316195423570985008687907853269984665640564039457584007913129639935';
export const MOCK_ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
export const WAD = Math.pow(10, 18).toString();

export const SUPPORTED_ETHERSCAN_NETWORKS = ['main', 'bsc', 'bsc_test'];

export const MAX_NFT_QUOTA = "29930";
export const EMISSION_PER_SECONDS = "50735667174023340000"; // 16% * 40% = 6400000000 * 1e18/ (4 * 365 * 24 * 3600)
export const DISTRIBUTION_END = "126144000"; // (4 * 365 * 24 * 3600)
export const MIN_BUSD_SWAP_THRESHOLD = ethers.utils.parseUnits('400');
export const MIN_BNB_SWAP_THRESHOLD = ethers.utils.parseUnits('2');
export const MIN_BIB_SWAP_THRESHOLD = ethers.utils.parseUnits('1000000');
export const DRIP_RATE_PER_SECOND = "69761542364282085000"; // 16%*55% = 8800000000 * 1e18/ (4 * 365 * 24 * 3600)
export const getBIBTokenDomainSeparatorPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
  getParamPerNetwork<tEthereumAddress>(
    {
      [eEthereumNetwork.coverage]:
        '0x6334ce07fc771d21f0634439a587b364f00756c209bb425d2c4873b672e6d265',
      [eEthereumNetwork.hardhat]:
        '0x199a7af9929982744df0725704a9dcbfc5809292509419575dca5613a7d9fb91',
      [eEthereumNetwork.bsc_test]: '',
      [eEthereumNetwork.bsc]: '',
    },
    network
  );

// BIBProtoGovernance address as admin of BIBToken and Migrator
export const getBIBAdminPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
  getParamPerNetwork<tEthereumAddress>(
    {
      [eEthereumNetwork.coverage]: "0xA1198B5dE887cd2916817C6D5d902ddfE210aBe9",
      [eEthereumNetwork.hardhat]: '0xA1198B5dE887cd2916817C6D5d902ddfE210aBe9',
      [eEthereumNetwork.bsc_test]: '0xA1198B5dE887cd2916817C6D5d902ddfE210aBe9',
      [eEthereumNetwork.bsc]: '0x54DbDcd52680b4B90b35Fe64c7833890981c8c80',//bsc safe
    },
    network
  );

export const getBIBTokenPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
getParamPerNetwork<tEthereumAddress>(
  {
    [eEthereumNetwork.coverage]: ZERO_ADDRESS,
    [eEthereumNetwork.hardhat]: '0x9dA2E2a429A8233f683AE0b7414862f390C7eE9C',
    [eEthereumNetwork.bsc_test]: '0x1180fd0Be0559C8300fa6aD88E3348dB418DBEfF', // TODO: need to replace
    [eEthereumNetwork.bsc]: '0x2B339d46e157Cf93De6A919Aa05350e952F67359',
  },
  network
);

export const getTokenDividendTrackerPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
getParamPerNetwork<tEthereumAddress>(
  {
    [eEthereumNetwork.coverage]: ZERO_ADDRESS,
    [eEthereumNetwork.hardhat]: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3',
    [eEthereumNetwork.bsc_test]: '0x973345Ca3d4C30547C8ED450F80E1d4EC071b165', // TODO: need to replace
    [eEthereumNetwork.bsc]: '0xdab8D9C8B25175C041F327FF6c4687Db673023Db',
  },
  network
);

export const getBUSDTokenPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
getParamPerNetwork<tEthereumAddress>(
  {
    [eEthereumNetwork.coverage]: ZERO_ADDRESS,
    [eEthereumNetwork.hardhat]: '0x9555f1998C31D4387c044582869c77B2EB4bb2cc',
    [eEthereumNetwork.bsc_test]: '0x9555f1998C31D4387c044582869c77B2EB4bb2cc', // TODO: need to replace
    [eEthereumNetwork.bsc]: '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
  },
  network
);

export const getMockOraclePerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
getParamPerNetwork<tEthereumAddress>(
  {
    [eEthereumNetwork.coverage]: ZERO_ADDRESS,
    [eEthereumNetwork.hardhat]: ZERO_ADDRESS,
    [eEthereumNetwork.bsc_test]: '0x75cC59A3974c6eDd47840489A430A2cE1cedD9BC', // TODO: need to replace
    [eEthereumNetwork.bsc]: ZERO_ADDRESS,
  },
  network
);

export const getTreasuryPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
getParamPerNetwork<tEthereumAddress>(
  {
    [eEthereumNetwork.coverage]: ZERO_ADDRESS,
    [eEthereumNetwork.hardhat]: '0xD2F3c942Bc1AaEaD58C38801B46535fc7Bd3aA0c',
    [eEthereumNetwork.bsc_test]: '0xD2F3c942Bc1AaEaD58C38801B46535fc7Bd3aA0c', // TODO: need to replace
    [eEthereumNetwork.bsc]: '0x32519133f990860b901297966748a002bDcb4d38',
  },
  network
);

export const getRewardVaultPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
getParamPerNetwork<tEthereumAddress>(
  {
    [eEthereumNetwork.coverage]: ZERO_ADDRESS,
    [eEthereumNetwork.hardhat]: '0xD2F3c942Bc1AaEaD58C38801B46535fc7Bd3aA0c',
    [eEthereumNetwork.bsc_test]: '0xD2F3c942Bc1AaEaD58C38801B46535fc7Bd3aA0c', // TODO: need to replace
    [eEthereumNetwork.bsc]: '0x482A6D54119412FD76e36B5A8c20dF656b52FA76',
  },
  network
);

export const getSwapRoterPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
getParamPerNetwork<tEthereumAddress>(
  {
    [eEthereumNetwork.coverage]: ZERO_ADDRESS,
    [eEthereumNetwork.hardhat]: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3',
    [eEthereumNetwork.bsc_test]: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3', // TODO: need to replace
    [eEthereumNetwork.bsc]: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
  },
  network
);

type BN = ethers.BigNumberish;

type ClaimInfo = {
  asset: string,
  addr: tEthereumAddress,
  frozenDuration: BN,
  maxToClaimed: BN,
  decimals:number,
};

export const getAllClaimInfo = ():ClaimInfo[] =>{
  return [ {
      asset: "BIB",
      addr: '0x1180fd0Be0559C8300fa6aD88E3348dB418DBEfF',
      frozenDuration: '86400',
      decimals:18,
      maxToClaimed: ethers.utils.parseUnits("10000"),
    },
    {
      asset: "BUSD",
      addr: '0x9555f1998C31D4387c044582869c77B2EB4bb2cc',
      frozenDuration: '86400',
      decimals:18,
      maxToClaimed: ethers.utils.parseUnits("100"),
    }
  ]
};

