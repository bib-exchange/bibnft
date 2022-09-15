import { InitializableAdminUpgradeabilityProxy } from './../../types/InitializableAdminUpgradeabilityProxy.d';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getSoccerStarNftMarket,
  getSoccerStarNftMarketImpl,
  getSoccerStarNft,
  getFeeCollector,
  getContract,
  getITokenDividendTracker
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  getBIBTokenPerNetwork,
  getBUSDTokenPerNetwork,
  getMockOraclePerNetwork,
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork,
  getTokenDividendTrackerPerNetwork
 } from '../../helpers/constants';

const { SoccerStarNftMarket, FeeCollector } = eContractid;

task(`initialize-${SoccerStarNftMarket}`, `Initialize the ${SoccerStarNftMarket} proxy contract`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\n- Initialzie ${SoccerStarNftMarket} proxy`);
    
    const network = localBRE.network.name as eEthereumNetwork;

    const admin = await getBIBAdminPerNetwork(network);
    const soccerStarNft = await getSoccerStarNft();

    const soccerStarNftMarketNft = await getSoccerStarNftMarket();
    const soccerStarNftMarketNftImpl = await getSoccerStarNftMarketImpl();

    const soccerStarNftMarketNftProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      soccerStarNftMarketNft.address
    );

    const encodedInitialize = soccerStarNftMarketNftImpl.interface.encodeFunctionData('initialize', [
      soccerStarNft.address,
      await getBIBTokenPerNetwork(network),
      await getBUSDTokenPerNetwork(network),
      await getTreasuryPerNetwork(network),
    ]);

    await waitForTx(
      await soccerStarNftMarketNftProxy['initialize(address,address,bytes)'](
        soccerStarNftMarketNftImpl.address,
        admin,
        encodedInitialize
      )
    );

    // 3. set market fee collector
    console.log(`\tbind ${FeeCollector}  to ${SoccerStarNftMarket}`);
    const feeCollector = await getFeeCollector();
    await waitForTx(
      await soccerStarNftMarketNft.setFeeCollector(feeCollector.address));

    console.log(`\tExclude ${SoccerStarNftMarket} from devidend list`);
    const tokenTracker = await getITokenDividendTracker(getTokenDividendTrackerPerNetwork(network));
    await waitForTx(
      await tokenTracker.excludeFromDividends(soccerStarNftMarketNft.address)
    );
    console.log(`\tFinished ${SoccerStarNftMarket} proxy initialize`);
  });
