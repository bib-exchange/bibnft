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
  getComposedSoccerStarNft
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  getBIBTokenPerNetwork,
  getBIBAdminPerNetwork,
  getTokenDividendTrackerPerNetwork,
  DRIP_RATE_PER_SECOND
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
  StakedRewardUiDataProvider
} = eContractid;

task(`run:exclude-dividend`, `Initialize the CommunityNode proxy contract`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    
    const network = localBRE.network.name as eEthereumNetwork;
    const soccerStarNft = await getSoccerStarNft();
    const stakedSoccerStarNftV2 = await getStakedSoccerStarNftV2();
    const stakedDividendTracker = await getStakedDividendTracker();
    const soccerStartNftMarket = await getSoccerStarNftMarket();
    const composedSoccerStarNft = await getComposedSoccerStarNft();
    const bibNode = await getBIBNode();
    const bibStaking = await getBIBStaking();
    const bibDividend = await getBIBDividend();
    const feeCollector = await getFeeCollector();
    const stakedRewardUiDataProvider = await getStakedRewardUiDataProvider()

    const tokenTracker = await getITokenDividendTracker(getTokenDividendTrackerPerNetwork(network));
    
    console.log(`\tExclude ${SoccerStarNft} from devidend list`);
    await waitForTx(
      await tokenTracker.excludeFromDividends(soccerStarNft.address)
    );

    console.log(`\tExclude ${StakedSoccerStarNftV2} from devidend list`);
    await waitForTx(
      await tokenTracker.excludeFromDividends(stakedSoccerStarNftV2.address)
    );

    console.log(`\tExclude ${StakedDividendTracker} from devidend list`);
    await waitForTx(
      await tokenTracker.excludeFromDividends(stakedDividendTracker.address)
    );

    console.log(`\tExclude ${ComposedSoccerStarNft} from devidend list`);
    await waitForTx(
      await tokenTracker.excludeFromDividends(composedSoccerStarNft.address)
    );

    console.log(`\tExclude ${SoccerStarNftMarket} from devidend list`);
    await waitForTx(
      await tokenTracker.excludeFromDividends(soccerStartNftMarket.address)
    );

    console.log(`\tExclude ${BIBNode} from devidend list`);
    await waitForTx(
      await tokenTracker.excludeFromDividends(bibNode.address)
    );

    console.log(`\tExclude ${BIBStaking} from devidend list`);
    await waitForTx(
      await tokenTracker.excludeFromDividends(bibStaking.address)
    );

    console.log(`\tExclude ${BIBDividend} from devidend list`);
    await waitForTx(
      await tokenTracker.excludeFromDividends(bibDividend.address)
    );

    console.log(`\tExclude ${FeeCollector} from devidend list`);
    await waitForTx(
      await tokenTracker.excludeFromDividends(feeCollector.address)
    );
    
    console.log(`\tExclude ${StakedRewardUiDataProvider} from devidend list`);
    await waitForTx(
      await tokenTracker.excludeFromDividends(stakedRewardUiDataProvider.address)
    );
  });
