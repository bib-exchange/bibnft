import { InitializableAdminUpgradeabilityProxy } from '../../types/InitializableAdminUpgradeabilityProxy';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getBIBDividend,
  getBIBDividendImpl,
  getBIBNode,
  getBIBNodeImpl,
  getBIBStaking,
  getBIBStakingImpl,
  getSoccerStarNft,
  getFeeCollector,
  getStakedSoccerStarNftV2,
  getSoccerStarNftMarket,
  getContract,
  getIFreezeToken,
  getITokenDividendTracker,
  getStakedDividendTracker,
  getStakedRewardUiDataProvider,
  getComposedSoccerStarNft,
  getIWhiteListInterface
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  getBIBTokenPerNetwork,
 } from '../../helpers/constants';

const { 
  SoccerStarNft,
  StakedSoccerStarNftV2,
  StakedDividendTracker,
  ComposedSoccerStarNft,
  SoccerStarNftMarket,
  BIBDividend, 
  BIBNode, 
  BIBStaking , 
  FeeCollector,
  StakedRewardUiDataProvider,
} = eContractid;

interface ContractToExclude {
  id: eContractid,
  address: string
}

task(`run:exclude-fee`, `Initialize the CommunityNode proxy contract`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    console.log(`Run excluding contract from chargeing fee`);
    
    const contractsToExclude:ContractToExclude[] = [
      {
        id: SoccerStarNft,
        address: (await getSoccerStarNft()).address
      },
      {
        id: StakedSoccerStarNftV2,
        address: (await getStakedSoccerStarNftV2()).address
      },
      {
        id: StakedDividendTracker,
        address: (await getStakedDividendTracker()).address
      },
      {
        id: SoccerStarNftMarket,
        address: (await getSoccerStarNftMarket()).address
      },
      {
        id: ComposedSoccerStarNft,
        address: (await getComposedSoccerStarNft()).address
      },
      {
        id: BIBNode,
        address: (await getBIBNode()).address
      },
      {
        id: BIBStaking,
        address: (await getBIBStaking()).address
      },
      {
        id: BIBDividend,
        address: (await getBIBDividend()).address
      },
      {
        id: FeeCollector,
        address: (await getFeeCollector()).address
      },
      {
        id: StakedRewardUiDataProvider,
        address: (await getStakedRewardUiDataProvider()).address
      },
    ] as ContractToExclude[];

    const network = localBRE.network.name as eEthereumNetwork;

    for(const {id, address} of contractsToExclude){
      const whiteLitInterface = await getIWhiteListInterface(await getBIBTokenPerNetwork(network));
      if(!(await whiteLitInterface.isFromWhiteList(address))) {
        console.log(`\tExclude ${id} in from list`);
        await waitForTx(
          await whiteLitInterface.setFeeWhiteList(address, true, true)
        );
      }
      if(!(await whiteLitInterface.isToWhiteList(address))) {
        console.log(`\tExclude ${id} in to list`);
        await waitForTx(
          await whiteLitInterface.setFeeWhiteList(address, true, false)
        );
      }
    }

  });
