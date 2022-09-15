
import { Contract, Signer, utils, ethers } from 'ethers';
import { Artifact } from 'hardhat/types';
import { Artifact as BuidlerArtifact } from '@nomiclabs/buidler/types';
import { readArtifact as buidlerReadArtifact } from '@nomiclabs/buidler/plugins';
import { getDb, DRE, waitForTx } from './misc-utils';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {eEthereumNetwork} from "./types-common";
import { eContractid, tStringTokenSmallUnits,tEthereumAddress } from './types';
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
import {ComposedSoccerStarNft} from '../types/ComposedSoccerStarNft';
import {StakedSoccerStarNftV2} from '../types/StakedSoccerStarNftV2';
import {SoccerStarNftMarket} from '../types/SoccerStarNftMarket';
import {StakedDividendTracker} from '../types/StakedDividendTracker';
import {FeeCollector} from '../types/FeeCollector';
import {StakedRewardUiDataProvider} from '../types/StakedRewardUiDataProvider';
import {BibNode} from '../types/BibNode';
import {BibDividend} from '../types/BibDividend';
import {BibStaking} from '../types/BibStaking';
import {DividendCollector} from '../types/DividendCollector';
import { BibDividendLibraryAddresses, BibDividend__factory } from '../types/factories/BibDividend__factory';
import { Faucet } from '../types';
import { IFreezeToken } from '../types';
import {ITokenDividendTracker} from '../types';
import { IWhiteList } from '../types';

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

export const getFirstSigner = async () => (await getEthersSigners())[0];

export const getEthersSignersAddresses = async (): Promise<tEthereumAddress[]> =>
  await Promise.all((await DRE.ethers.getSigners()).map((signer) => signer.getAddress()));

export const getCurrentBlock = async () => {
  return DRE.ethers.provider.getBlockNumber();
};

export const getCurrentBlockTimestamp = async (blockNumber:number) => {
  return (await DRE.ethers.provider.getBlock(blockNumber)).timestamp;
};
 
export const deployInitializableAdminUpgradeabilityProxy = async (verify?: boolean) => {
  const id = eContractid.InitializableAdminUpgradeabilityProxy;
  const args: string[] = [];
  const instance = await deployContract<InitializableAdminUpgradeabilityProxy>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
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

export const deployStakedRewardUiDataProvider = async (staked:string, dividend:string, verify?: boolean) => {
  const id = eContractid.StakedRewardUiDataProvider;
  const args: string[] = [staked, dividend];
  const instance = await deployContract<StakedRewardUiDataProvider>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const deployStakedDividendTracker = async (verify?: boolean) => {
  const id = eContractid.StakedDividendTracker;
  const args: string[] = [];
  const instance = await deployContract<StakedDividendTracker>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const deployFeeCollector = async (verify?: boolean) => {
  const id = eContractid.FeeCollector;
  const args: string[] = [];
  const instance = await deployContract<FeeCollector>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
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

export const deploySoccerStarNft = async (verify?: boolean) => {
  const id = eContractid.SoccerStarNft;
  const args: string[] = [];
  const instance = await deployContract<SoccerStarNft>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const deployDividendCollector = async (verify?: boolean) => {
  const id = eContractid.DividendCollector;
  const args: string[] = [];
  const instance = await deployContract<DividendCollector>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

const readArtifact = async (id: string) => {
  if (DRE.network.name === eEthereumNetwork.buidlerevm) {
    return buidlerReadArtifact(DRE.config.paths.artifacts, id);
  }
  return (DRE as HardhatRuntimeEnvironment).artifacts.readArtifact(id);
};

export const linkBytecode = (artifact: BuidlerArtifact | Artifact, libraries: any) => {
  let bytecode = artifact.bytecode;

  for (const [fileName, fileReferences] of Object.entries(artifact.linkReferences)) {
    for (const [libName, fixups] of Object.entries(fileReferences)) {
      const addr = libraries[libName];

      if (addr === undefined) {
        continue;
      }

      for (const fixup of fixups) {
        bytecode =
          bytecode.substr(0, 2 + fixup.start * 2) +
          addr.substr(2) +
          bytecode.substr(2 + (fixup.start + fixup.length) * 2);
      }
    }
  }

  return bytecode;
};

export const deployBIBNode = async (verify?: boolean) => {
  const id = eContractid.BIBNode;
  const args: string[] = [];
  const instance = await deployContract<BibNode>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const depIterableMappingLibrary = async (verify?: boolean) =>{
    const iterableMappingArtifact = await readArtifact(eContractid.IterableMapping);
    
    const iterableMappingFactory = await DRE.ethers.getContractFactory(
      iterableMappingArtifact.abi,
      iterableMappingArtifact.bytecode
    );
    
    const iterableMapping = await (
      await iterableMappingFactory.connect(await getFirstSigner()).deploy()
    ).deployed();
    return withSaveAndVerify(iterableMapping, eContractid.IterableMapping, [], verify);
  };
  
  export const deployLibraries = async (
    verify?: boolean
  ): Promise<BibDividendLibraryAddresses> => {
    const iterableMapping = await depIterableMappingLibrary(verify);
  
    return {
      ['__$4b09164eaf8a84d7a8044fedc88418fa6b$__']: iterableMapping.address,
    };
  };

export const deployBIBDividend = async (verify?: boolean) => {
  const id = eContractid.BIBDividend;
  
  const libraries = await deployLibraries(verify);
  const bibDividendlImpl = await new BibDividend__factory(libraries, await getFirstSigner()).deploy();
  await insertContractAddressInDb(eContractid.BIBDividendImpl, bibDividendlImpl.address);
  return withSaveAndVerify(bibDividendlImpl, eContractid.BIBDividend, [], verify);
};

export const withSaveAndVerify = async <ContractType extends Contract>(
  instance: ContractType,
  id: string,
  args: (string | string[])[],
  verify?: boolean
): Promise<ContractType> => {
  await waitForTx(instance.deployTransaction);
  await registerContractInJsonDb(id, instance);
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const deployBIBStaking = async (verify?: boolean) => {
  const id = eContractid.BIBStaking;
  const args: string[] = [];
  const instance = await deployContract<BibStaking>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const deploySoccerStarNftMarket = async (verify?: boolean) => {
  const id = eContractid.SoccerStarNftMarket;
  const args: string[] = [];
  const instance = await deployContract<SoccerStarNftMarket>(id, args);
  await instance.deployTransaction.wait();
  if (verify) {
    await verifyContract(id, instance.address, args);
  }
  return instance;
};

export const deployComposedSoccerStarNft = async (verify?: boolean) => {
  const id = eContractid.ComposedSoccerStarNft;
  const args: string[] = [];
  const instance = await deployContract<ComposedSoccerStarNft>(id, args);
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


export const deployFaucet = async (verify?: boolean) => {
  const id = eContractid.Faucet;
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

export const getStakedRewardUiDataProvider= async (address?: tEthereumAddress) => {
  return await getContract<StakedRewardUiDataProvider>(
    eContractid.StakedRewardUiDataProvider,
    address || (await getDb().get(`${eContractid.StakedRewardUiDataProvider}.${DRE.network.name}`).value()).address
  );
};

export const getSoccerStarNft = async (address?: tEthereumAddress) => {
  return await getContract<SoccerStarNft>(
    eContractid.SoccerStarNft,
    address || (await getDb().get(`${eContractid.SoccerStarNft}.${DRE.network.name}`).value()).address
  );
};

export const getSoccerStarNftImpl = async (address?: tEthereumAddress) => {
  return await getContract<SoccerStarNft>(
    eContractid.SoccerStarNft,
    address || (await getDb().get(`${eContractid.SoccerStarNftImpl}.${DRE.network.name}`).value()).address
  );
};

export const getComposedSoccerStarNft = async (address?: tEthereumAddress) => {
  return await getContract<ComposedSoccerStarNft>(
    eContractid.ComposedSoccerStarNft,
    address || (await getDb().get(`${eContractid.ComposedSoccerStarNft}.${DRE.network.name}`).value()).address
  );
};

export const getComposedSoccerStarNftImpl = async (address?: tEthereumAddress) => {
  return await getContract<ComposedSoccerStarNft>(
    eContractid.ComposedSoccerStarNft,
    address || (await getDb().get(`${eContractid.ComposedSoccerStarNftImpl}.${DRE.network.name}`).value()).address
  );
};

export const getSoccerStarNftMarket = async (address?: tEthereumAddress) => {
  return await getContract<SoccerStarNftMarket>(
    eContractid.SoccerStarNftMarket,
    address || (await getDb().get(`${eContractid.SoccerStarNftMarket}.${DRE.network.name}`).value()).address
  );
};

export const getSoccerStarNftMarketImpl = async (address?: tEthereumAddress) => {
  return await getContract<SoccerStarNftMarket>(
    eContractid.SoccerStarNftMarket,
    address || (await getDb().get(`${eContractid.SoccerStarNftMarketImpl}.${DRE.network.name}`).value()).address
  );
};

export const getStakedSoccerStarNftV2 = async (address?: tEthereumAddress) => {
  return await getContract<StakedSoccerStarNftV2>(
    eContractid.StakedSoccerStarNftV2,
    address || (await getDb().get(`${eContractid.StakedSoccerStarNftV2}.${DRE.network.name}`).value()).address
  );
};

export const getStakedSoccerStarNftV2Impl = async (address?: tEthereumAddress) => {
  return await getContract<StakedSoccerStarNftV2>(
    eContractid.StakedSoccerStarNftV2,
    address || (await getDb().get(`${eContractid.StakedSoccerStarNftV2Impl}.${DRE.network.name}`).value()).address
  );
};

export const getFeeCollector = async (address?: tEthereumAddress) => {
  return await getContract<FeeCollector>(
    eContractid.FeeCollector,
    address || (await getDb().get(`${eContractid.FeeCollector}.${DRE.network.name}`).value()).address
  );
};

export const getFeeCollectorImpl = async (address?: tEthereumAddress) => {
  return await getContract<FeeCollector>(
    eContractid.FeeCollector,
    address || (await getDb().get(`${eContractid.FeeCollectorImpl}.${DRE.network.name}`).value()).address
  );
};

export const getDividendCollector = async (address?: tEthereumAddress) => {
  return await getContract<DividendCollector>(
    eContractid.DividendCollector,
    address || (await getDb().get(`${eContractid.DividendCollector}.${DRE.network.name}`).value()).address
  );
};

export const getDividendCollectorImpl = async (address?: tEthereumAddress) => {
  return await getContract<DividendCollector>(
    eContractid.DividendCollector,
    address || (await getDb().get(`${eContractid.DividendCollectorImpl}.${DRE.network.name}`).value()).address
  );
};

export const getStakedDividendTracker = async (address?: tEthereumAddress) => {
  return await getContract<StakedDividendTracker>(
    eContractid.StakedDividendTracker,
    address || (await getDb().get(`${eContractid.StakedDividendTracker}.${DRE.network.name}`).value()).address
  );
};

export const getStakedDividendTrackerImpl = async (address?: tEthereumAddress) => {
  return await getContract<StakedDividendTracker>(
    eContractid.StakedDividendTracker,
    address || (await getDb().get(`${eContractid.StakedDividendTrackerImpl}.${DRE.network.name}`).value()).address
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

export const getIFreezeToken = async (address: tEthereumAddress) => {
  return await getContract<IFreezeToken>(
    eContractid.IFreezeToken,
    address ||
      (
        await getDb().get(`${eContractid.IFreezeToken}.${DRE.network.name}`).value()
      ).address
  );
};

export const getITokenDividendTracker = async (address: tEthereumAddress) => {
  return await getContract<ITokenDividendTracker>(
    eContractid.ITokenDividendTracker,
    address ||
      (
        await getDb().get(`${eContractid.ITokenDividendTracker}.${DRE.network.name}`).value()
      ).address
  );
};

export const getIWhiteListInterface = async (address: tEthereumAddress) => {
  return await getContract<IWhiteList>(
    eContractid.IWhiteList,
    address ||
      (
        await getDb().get(`${eContractid.IWhiteList}.${DRE.network.name}`).value()
      ).address
  );
};

export const getFaucet= async (address?: tEthereumAddress) => {
  return await getContract<Faucet>(
    eContractid.Faucet,
    address ||
      (
        await getDb().get(`${eContractid.Faucet}.${DRE.network.name}`).value()
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

export const getBIBDividend = async (address?: tEthereumAddress) => {
  return await getContract<BibDividend>(
    eContractid.BIBDividend,
    address || (await getDb().get(`${eContractid.BIBDividend}.${DRE.network.name}`).value()).address
  );
};

export const getBIBDividendImpl = async (address?: tEthereumAddress) => {
  return await getContract<BibDividend>(
    eContractid.BIBDividend,
    address || (await getDb().get(`${eContractid.BIBDividendImpl}.${DRE.network.name}`).value()).address
  );
};

export const getBIBNode= async (address?: tEthereumAddress) => {
  return await getContract<BibNode>(
    eContractid.BIBNode,
    address || (await getDb().get(`${eContractid.BIBNode}.${DRE.network.name}`).value()).address
  );
};

export const getBIBNodeImpl = async (address?: tEthereumAddress) => {
  return await getContract<BibNode>(
    eContractid.BIBNode,
    address || (await getDb().get(`${eContractid.BIBNodeImpl}.${DRE.network.name}`).value()).address
  );
};

export const getBIBStaking= async (address?: tEthereumAddress) => {
  return await getContract<BibStaking>(
    eContractid.BIBStaking,
    address || (await getDb().get(`${eContractid.BIBStaking}.${DRE.network.name}`).value()).address
  );
};

export const getBIBStakingImpl = async (address?: tEthereumAddress) => {
  return await getContract<BibStaking>(
    eContractid.BIBStaking,
    address || (await getDb().get(`${eContractid.BIBStakingImpl}.${DRE.network.name}`).value()).address
  );
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
