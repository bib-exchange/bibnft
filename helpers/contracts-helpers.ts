
import { Contract, Signer, utils, ethers } from 'ethers';

import { getDb, DRE, waitForTx } from './misc-utils';
import { tEthereumAddress, eContractid, tStringTokenSmallUnits } from './types';
import { MOCK_ETH_ADDRESS, SUPPORTED_ETHERSCAN_NETWORKS } from './constants';
import BigNumber from 'bignumber.js';
import { InitializableAdminUpgradeabilityProxy } from '../types/InitializableAdminUpgradeabilityProxy';
import { signTypedData_v4, TypedData } from 'eth-sig-util';
import { fromRpcSig, ECDSASignature } from 'ethereumjs-util';
import { verifyContract } from './etherscan-verification';
import { MockBib } from '../types/MockBib';
import { MockBusd } from '../types/MockBusd';
import { MockBibOracle } from '../types/MockBibOracle';
import {Ierc20Detailed} from '../types/Ierc20Detailed';
import {SoccerStarNft} from '../types/SoccerStarNft';
import {StakedSoccerStarNftV2} from '../types/StakedSoccerStarNftV2';

export const registerContractInJsonDb = async (contractId: string, contractInstance: Contract) => {
  const currentNetwork = DRE.network.name;
  if (currentNetwork !== 'hardhat' && currentNetwork !== 'coverage') {
    console.log(`\n\t  *** ${contractId} ***\n`);
    console.log(`\t  Network: ${currentNetwork}`);
    console.log(`\t  tx: ${contractInstance.deployTransaction.hash}`);
    console.log(`\t  contract address: ${contractInstance.address}`);
    console.log(`\t  deployer address: ${contractInstance.deployTransaction.from}`);
    console.log(`\t  gas price: ${contractInstance.deployTransaction.gasPrice}`);
    console.log(`\t  gas used: ${contractInstance.deployTransaction.gasLimit}`);
    console.log(`\t  ******`);
    console.log();
  }

  await getDb()
    .set(`${contractId}.${currentNetwork}`, {
      address: contractInstance.address,
      deployer: contractInstance.deployTransaction.from,
    })
    .write();
};

export const insertContractAddressInDb = async (id: eContractid, address: tEthereumAddress) =>
  await getDb()
    .set(`${id}.${DRE.network.name}`, {
      address,
    })
    .write();

export const getEthersSigners = async (): Promise<Signer[]> =>
  await Promise.all(await DRE.ethers.getSigners());

export const getEthersSignersAddresses = async (): Promise<tEthereumAddress[]> =>
  await Promise.all((await DRE.ethers.getSigners()).map((signer) => signer.getAddress()));

export const getCurrentBlock = async () => {
  return DRE.ethers.provider.getBlockNumber();
};

export const getCurrentBlockTimestamp = async (blockNumber:number) => {
  return (await DRE.ethers.provider.getBlock(blockNumber)).timestamp;
};
 

export const decodeAbiNumber = (data: string): number =>
  parseInt(utils.defaultAbiCoder.decode(['uint256'], data).toString());

const deployContract = async <ContractType extends Contract>(
  contractName: string,
  args: any[]
): Promise<ContractType> => {
  const contract = (await (
    await DRE.ethers.getContractFactory(contractName)
  ).deploy(...args)) as ContractType;
  await waitForTx(contract.deployTransaction);
  await registerContractInJsonDb(<eContractid>contractName, contract);
  return contract;
};

export const deployStakedSoccerStarNftV2 = async (verify?: boolean) => {
  const id = eContractid.StakedSoccerStarNftV2;
  const args: string[] = [];
  const instance = await deployContract<StakedSoccerStarNftV2>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const deploySoccerStarNft = async ([_maxMintSupply, _bibContract, _busdContract, _treasury, _priceOracle]:[string, string, string, string, string],verify?: boolean) => {
  const id = eContractid.SoccerStarNft;
  const args: string[] = [_maxMintSupply, _bibContract, _busdContract, _treasury, _priceOracle];
  const instance = await deployContract<SoccerStarNft>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const getContract = async <ContractType extends Contract>(
  contractName: string,
  address: string
): Promise<ContractType> => (await DRE.ethers.getContractAt(contractName, address)) as ContractType;

export const deployMockBIBToken = async (verify?: boolean) => {
  const id = eContractid.MockBib;
  const args: string[] = [];
  const instance = await deployContract<MockBib>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const deployMockBUSDToken = async (verify?: boolean) => {
  const id = eContractid.MockBusd;
  const args: string[] = [];
  const instance = await deployContract<MockBusd>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const deployMockOracleToken = async (verify?: boolean) => {
  const id = eContractid.MockBibOracle;
  const args: string[] = [];
  const instance = await deployContract<MockBibOracle>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const getMockBIBToken = async (address?: tEthereumAddress) => {
  return await getContract<MockBib>(
    eContractid.MockBib,
    address || (await getDb().get(`${eContractid.MockBib}.${DRE.network.name}`).value()).address
  );
};

export const getMockBUSDToken = async (address?: tEthereumAddress) => {
  return await getContract<MockBusd>(
    eContractid.MockBusd,
    address || (await getDb().get(`${eContractid.MockBusd}.${DRE.network.name}`).value()).address
  );
};

export const getMockOracleToken = async (address?: tEthereumAddress) => {
  return await getContract<MockBibOracle>(
    eContractid.MockBibOracle,
    address || (await getDb().get(`${eContractid.MockBibOracle}.${DRE.network.name}`).value()).address
  );
};

export const getSoccerStarNft = async (address?: tEthereumAddress) => {
  return await getContract<SoccerStarNft>(
    eContractid.SoccerStarNft,
    address || (await getDb().get(`${eContractid.SoccerStarNft}.${DRE.network.name}`).value()).address
  );
};

export const getInitializableAdminUpgradeabilityProxy = async (address: tEthereumAddress) => {
  return await getContract<InitializableAdminUpgradeabilityProxy>(
    eContractid.InitializableAdminUpgradeabilityProxy,
    address ||
      (
        await getDb()
          .get(`${eContractid.InitializableAdminUpgradeabilityProxy}.${DRE.network.name}`)
          .value()
      ).address
  );
};

export const getIErc20Detailed = async (address: tEthereumAddress) => {
  return await getContract<Ierc20Detailed>(
    eContractid.IERC20Detailed,
    address ||
      (
        await getDb().get(`${eContractid.IERC20Detailed}.${DRE.network.name}`).value()
      ).address
  );
};

export const convertToCurrencyDecimals = async (tokenAddress: tEthereumAddress, amount: string) => {
  const isEth = tokenAddress === MOCK_ETH_ADDRESS;
  let decimals = '18';

  if (!isEth) {
    const token = await getIErc20Detailed(tokenAddress);
    decimals = (await token.decimals()).toString();
  }

  return ethers.utils.parseUnits(amount, decimals);
};

export const convertToCurrencyUnits = async (tokenAddress: string, amount: string) => {
  const isEth = tokenAddress === MOCK_ETH_ADDRESS;

  let decimals = new BigNumber(18);
  if (!isEth) {
    const token = await getIErc20Detailed(tokenAddress);
    decimals = new BigNumber(await token.decimals());
  }
  const currencyUnit = new BigNumber(10).pow(decimals);
  const amountInCurrencyUnits = new BigNumber(amount).div(currencyUnit);
  return amountInCurrencyUnits.toFixed();
};

export const buildPermitParams = (
  chainId: number,
  BIBToken: tEthereumAddress,
  owner: tEthereumAddress,
  spender: tEthereumAddress,
  nonce: number,
  deadline: string,
  value: tStringTokenSmallUnits
) => ({
  types: {
    EIP712Domain: [
      { name: 'name', type: 'string' },
      { name: 'version', type: 'string' },
      { name: 'chainId', type: 'uint256' },
      { name: 'verifyingContract', type: 'address' },
    ],
    Permit: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' },
    ],
  },
  primaryType: 'Permit' as const,
  domain: {
    name: 'BIB Token',
    version: '1',
    chainId: chainId,
    verifyingContract: BIBToken,
  },
  message: {
    owner,
    spender,
    value,
    nonce,
    deadline,
  },
});

export const buildDelegateByTypeParams = (
  chainId: number,
  BIBToken: tEthereumAddress,
  delegatee: tEthereumAddress,
  type: string,
  nonce: string,
  expiry: string
) => ({
  types: {
    EIP712Domain: [
      { name: 'name', type: 'string' },
      { name: 'version', type: 'string' },
      { name: 'chainId', type: 'uint256' },
      { name: 'verifyingContract', type: 'address' },
    ],
    DelegateByType: [
      { name: 'delegatee', type: 'address' },
      { name: 'type', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'expiry', type: 'uint256' },
    ],
  },
  primaryType: 'DelegateByType' as const,
  domain: {
    name: 'BIB Token',
    version: '1',
    chainId: chainId,
    verifyingContract: BIBToken,
  },
  message: {
    delegatee,
    type,
    nonce,
    expiry,
  },
});

export const buildDelegateParams = (
  chainId: number,
  BIBToken: tEthereumAddress,
  delegatee: tEthereumAddress,
  nonce: string,
  expiry: string
) => ({
  types: {
    EIP712Domain: [
      { name: 'name', type: 'string' },
      { name: 'version', type: 'string' },
      { name: 'chainId', type: 'uint256' },
      { name: 'verifyingContract', type: 'address' },
    ],
    Delegate: [
      { name: 'delegatee', type: 'address' },
      { name: 'nonce', type: 'uint256' },
      { name: 'expiry', type: 'uint256' },
    ],
  },
  primaryType: 'Delegate' as const,
  domain: {
    name: 'BIB Token',
    version: '1',
    chainId: chainId,
    verifyingContract: BIBToken,
  },
  message: {
    delegatee,
    nonce,
    expiry,
  },
});

export const getSignatureFromTypedData = (
  privateKey: string,
  typedData: any // TODO: should be TypedData, from eth-sig-utils, but TS doesn't accept it
): ECDSASignature => {
  const signature = signTypedData_v4(Buffer.from(privateKey.substring(2, 66), 'hex'), {
    data: typedData,
  });
  return fromRpcSig(signature);
};
