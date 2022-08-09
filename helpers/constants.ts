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

export const SUPPORTED_ETHERSCAN_NETWORKS = ['main', 'ropsten', 'kovan'];

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
      [eEthereumNetwork.coverage]: ZERO_ADDRESS,
      [eEthereumNetwork.hardhat]: ZERO_ADDRESS,
      [eEthereumNetwork.bsc_test]: '0xA1198B5dE887cd2916817C6D5d902ddfE210aBe9',
      [eEthereumNetwork.bsc]: '0x3b681f97Acd15eF59FE9A229eDf16458c94f1F43',//astar safe
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

