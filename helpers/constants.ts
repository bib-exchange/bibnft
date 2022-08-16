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
export const EMISSION_PER_SECONDS = 10000; // TODO: need change once confirmed
export const DISTRIBUTION_END = 1000000; // TODO: need change once confirmed
export const MIN_BUSD_SWAP_THRESHOLD = ethers.utils.parseUnits('10');
export const MIN_BNB_SWAP_THRESHOLD = ethers.utils.parseUnits('0.01');

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
      [eEthereumNetwork.hardhat]: ZERO_ADDRESS,
      [eEthereumNetwork.bsc_test]: '0xA1198B5dE887cd2916817C6D5d902ddfE210aBe9',
      [eEthereumNetwork.bsc]: '0x3b681f97Acd15eF59FE9A229eDf16458c94f1F43',//bsc safe
    },
    network
  );

  type BN = ethers.BigNumberish;

export const getBIBTokenPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
getParamPerNetwork<tEthereumAddress>(
  {
    [eEthereumNetwork.coverage]: ZERO_ADDRESS,
    [eEthereumNetwork.hardhat]: ZERO_ADDRESS,
    [eEthereumNetwork.bsc_test]: '0x9dA2E2a429A8233f683AE0b7414862f390C7eE9C', // TODO: need to replace
    [eEthereumNetwork.bsc]: ZERO_ADDRESS,
  },
  network
);

export const getBUSDTokenPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
getParamPerNetwork<tEthereumAddress>(
  {
    [eEthereumNetwork.coverage]: ZERO_ADDRESS,
    [eEthereumNetwork.hardhat]: ZERO_ADDRESS,
    [eEthereumNetwork.bsc_test]: '0x9555f1998C31D4387c044582869c77B2EB4bb2cc', // TODO: need to replace
    [eEthereumNetwork.bsc]: ZERO_ADDRESS,
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
    [eEthereumNetwork.hardhat]: ZERO_ADDRESS,
    [eEthereumNetwork.bsc_test]: '0xD2F3c942Bc1AaEaD58C38801B46535fc7Bd3aA0c', // TODO: need to replace
    [eEthereumNetwork.bsc]: ZERO_ADDRESS,
  },
  network
);

export const getRewardVaultPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
getParamPerNetwork<tEthereumAddress>(
  {
    [eEthereumNetwork.coverage]: ZERO_ADDRESS,
    [eEthereumNetwork.hardhat]: ZERO_ADDRESS,
    [eEthereumNetwork.bsc_test]: '0xD2F3c942Bc1AaEaD58C38801B46535fc7Bd3aA0c', // TODO: need to replace
    [eEthereumNetwork.bsc]: ZERO_ADDRESS,
  },
  network
);

export const getSwapRoterPerNetwork = (network: eEthereumNetwork): tEthereumAddress =>
getParamPerNetwork<tEthereumAddress>(
  {
    [eEthereumNetwork.coverage]: ZERO_ADDRESS,
    [eEthereumNetwork.hardhat]: ZERO_ADDRESS,
    [eEthereumNetwork.bsc_test]: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3', // TODO: need to replace
    [eEthereumNetwork.bsc]: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
  },
  network
);


