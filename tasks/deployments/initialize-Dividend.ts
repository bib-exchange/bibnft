import { InitializableAdminUpgradeabilityProxy } from './../../types/InitializableAdminUpgradeabilityProxy.d';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getFeeCollector,
  getFeeCollectorImpl,
  getStakedDividendTracker,
  getStakedSoccerStarNftV2,
  getSoccerStarNftMarket,
  getContract
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  MAX_NFT_QUOTA,
  getBIBTokenPerNetwork,
  getBUSDTokenPerNetwork,
  getMockOraclePerNetwork,
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork
 } from '../../helpers/constants';

const {
    StakedDividendTracker,
    FeeCollector,
    FeeCollectorImpl,
    StakedSoccerStarNftV2,
    SoccerStarNftMarket
} = eContractid;

task(`initialize-dividend`, `Initialize dividend contracts`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');


    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    
    const network = localBRE.network.name as eEthereumNetwork;

    const admin = await getBIBAdminPerNetwork(network);
    const stakeDividendTracker = await getStakedDividendTracker();
    const feeCollector = await getFeeCollector();
    const feeCollectorImpl = await getFeeCollectorImpl();

    console.log(`\tInitialzie dividend proxy`);
    const feeCollectorProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      feeCollector.address
    );

    const encodedInitialize = feeCollectorImpl.interface.encodeFunctionData('initialize', [
      await getTreasuryPerNetwork(network),
      await getBIBTokenPerNetwork(network),
      await getBUSDTokenPerNetwork(network),
      stakeDividendTracker.address,
      ZERO_ADDRESS,
      ZERO_ADDRESS,
    ]);

    await waitForTx(
      await feeCollectorProxy['initialize(address,address,bytes)'](
        feeCollectorImpl.address,
        admin,
        encodedInitialize
      )
    );

    console.log(`\tbind ${StakedDividendTracker} tracker to ${StakedSoccerStarNftV2}`);
    const stakedSoccerStarNftV2 = await getStakedSoccerStarNftV2();
    await waitForTx(
        await stakedSoccerStarNftV2.setBalanceHook(stakeDividendTracker.address));

    console.log(`\tbind ${FeeCollector}  to ${SoccerStarNftMarket}`);
    const soccerStarNftMarket = await getSoccerStarNftMarket();
    await waitForTx(
        await soccerStarNftMarket.setFeeCollector(feeCollector.address));
    
    console.log(`\tFinished dividend proxy initialize`);
  });
