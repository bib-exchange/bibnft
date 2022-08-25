import { InitializableAdminUpgradeabilityProxy } from './../../types/InitializableAdminUpgradeabilityProxy.d';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getFeeCollector,
  getFeeCollectorImpl,
  getStakedDividendTracker,
  getStakedDividendTrackerImpl,
  getStakedSoccerStarNftV2,
  getSoccerStarNftMarket,
  getBIBDividend,
  getDividendCollector,
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
    const stakeDividendTrackerImpl = await getStakedDividendTrackerImpl();
    const bibDividend = await getBIBDividend();

    const feeCollector = await getFeeCollector();
    const feeCollectorImpl = await getFeeCollectorImpl();

    console.log(`\n- Initialzie dividend proxy`);
    const stakeDividendTrackerProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      stakeDividendTracker.address
    );
    let encodedInitialize = stakeDividendTrackerImpl.interface.encodeFunctionData('initialize', [
      await getBIBTokenPerNetwork(network),
    ]);

    await waitForTx(
      await stakeDividendTrackerProxy['initialize(address,address,bytes)'](
        stakeDividendTrackerImpl.address,
        admin,
        encodedInitialize
      )
    );
    console.log(`\tFinished dividend proxy initialize`);

    console.log(`\n- Initialzie fee collector proxy`);
    const feeCollectorProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      feeCollector.address
    );

    encodedInitialize = feeCollectorImpl.interface.encodeFunctionData('initialize', [
      await getTreasuryPerNetwork(network),
      await getBIBTokenPerNetwork(network),
      await getBUSDTokenPerNetwork(network),
      stakeDividendTracker.address,
      (await getDividendCollector()).address,
      bibDividend.address,
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

    // 2. allow fee collecter to distribute dividend
    console.log(`\tallow ${FeeCollector} to call ${StakedDividendTracker} to distribute dividend`);
    await waitForTx(
      await stakeDividendTracker.setAllowToCall(feeCollector.address, true));
    
    // 3. allow the market to distribute dividend to the fee collector
    console.log(`\tadd ${SoccerStarNftMarket} to ${FeeCollector} as allow caller`);
    const soccerStarNftMarket = await getSoccerStarNftMarket();
    await waitForTx(
      await feeCollector.setAllowToCall(
          soccerStarNftMarket.address,
          true));

    // 4. allow staked module to update balance
    const stakedSoccerStarNftV2 = await getStakedSoccerStarNftV2();
    console.log(`\tallow ${StakedDividendTracker} to call ${StakedDividendTracker}`);
    await waitForTx(
      await stakeDividendTracker.setAllowToCall(stakedSoccerStarNftV2.address, true));

    console.log(`\tFinished dividend initialize`);
  });
