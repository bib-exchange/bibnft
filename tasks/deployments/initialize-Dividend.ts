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
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork
 } from '../../helpers/constants';

const {
    StakedDividendTracker,
    FeeCollector,
    SoccerStarNftMarket,
    StakedSoccerStarNftV2
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

    // 1 config swap thresh hold
    console.log(`\tConfig ${FeeCollector} thresholds`);
    await waitForTx(
      await feeCollector.setSwapThreshHold(
        MIN_BUSD_SWAP_THRESHOLD,
        MIN_BNB_SWAP_THRESHOLD
      )
    );

    //  2 set fee collector receiver
    console.log(`\tset ${FeeCollector} fee receiver to ${StakedDividendTracker}`);
    await waitForTx(
      await feeCollector.setFeeReceiver(
          stakeDividendTracker.address,
          ZERO_ADDRESS, // TODO: replace with final addresses
          ZERO_ADDRESS // TODO: replace with final addresses
        ));

    // 3. allow fee collecter to distribute dividend
    console.log(`\tallow ${FeeCollector} to call ${StakedDividendTracker} to distribute dividend`);
    await waitForTx(
      await stakeDividendTracker.setAllowToCall(feeCollector.address, true));
    
    // 4. set market fee collector
    console.log(`\tbind ${FeeCollector}  to ${SoccerStarNftMarket}`);
    const soccerStarNftMarket = await getSoccerStarNftMarket();
    await waitForTx(
      await soccerStarNftMarket.setFeeCollector(feeCollector.address));

    // 5. allow the market to distribute dividend to the fee collector
    console.log(`\tadd ${SoccerStarNftMarket} to ${FeeCollector} as allow caller`);
    await waitForTx(
      await feeCollector.setAllowToCall(
          soccerStarNftMarket.address,
          true));

    // 6.  set staked balance hook to the dividend
    const stakedSoccerStarNftV2= await getStakedSoccerStarNftV2();
    console.log(`\tbind ${StakedDividendTracker} tracker to ${StakedSoccerStarNftV2}`);
    await waitForTx(
      await stakedSoccerStarNftV2.setBalanceHook(stakeDividendTracker.address));

    // 7. allow staked module to update balance
    console.log(`\tallow ${StakedDividendTracker} to call ${StakedDividendTracker}`);
    await waitForTx(
      await stakeDividendTracker.setAllowToCall(stakedSoccerStarNftV2.address, true));

    console.log(`\tFinished dividend proxy initialize`);
  });
