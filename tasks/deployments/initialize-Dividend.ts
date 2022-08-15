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
  MIN_BUSD_SWAP_THRESHOLD,
  MIN_BNB_SWAP_THRESHOLD,
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

    // config swap thresh hold
    console.log(`\tConfig ${FeeCollector} thresholds`);
    await waitForTx(
      await feeCollector.setSwapThreshHold(
        MIN_BUSD_SWAP_THRESHOLD,
        MIN_BNB_SWAP_THRESHOLD
      )
    );

    // set staken receiver
    console.log(`\tset ${FeeCollector} fee receiver to ${StakedDividendTracker}`);
    await waitForTx(
      await feeCollector.setFeeReceiver(
        stakeDividendTracker.address,
        ZERO_ADDRESS, // TODO: replace with final addresses
        ZERO_ADDRESS // TODO: replace with final addresses
        ));
  
    // brige market and staken 
    console.log(`\tset ${StakedDividendTracker} fee sender to ${FeeCollector}`);
    await waitForTx(
      await stakeDividendTracker.setFeeSender(feeCollector.address));

    console.log(`\tbind ${FeeCollector}  to ${SoccerStarNftMarket}`);
    const soccerStarNftMarket = await getSoccerStarNftMarket();
    await waitForTx(
      await soccerStarNftMarket.setFeeCollector(feeCollector.address));

    // add market to allow caller list
    console.log(`\tadd ${SoccerStarNftMarket} to ${FeeCollector} as allow caller`);
    await waitForTx(
      await feeCollector.setAllowCall(
        soccerStarNftMarket.address,
        true
        ));

    console.log(`\tFinished dividend proxy initialize`);
  });
