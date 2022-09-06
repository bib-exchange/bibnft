import { task } from 'hardhat/config';
import { eContractid } from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import { waitForTx } from '../../helpers/misc-utils';
import {
  deployStakedDividendTracker,
  deployFeeCollector,
  registerContractInJsonDb,
  deployInitializableAdminUpgradeabilityProxy,
  getStakedSoccerStarNftV2,
} from '../../helpers/contracts-helpers';

const { 
  StakedDividendTracker,
  StakedDividendTrackerImpl,
  FeeCollector,
  FeeCollectorImpl,
  StakedSoccerStarNftV2
} = eContractid;

import { ZERO_ADDRESS,
  getBIBTokenPerNetwork,
 } from '../../helpers/constants';

task(`deploy-dividend`, `Deploy dividend contracts`)
  .addFlag('verify', 'Proceed with the Etherscan verification')
  .setAction(async ({ verify }, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    // 1
    console.log(`\n- ${StakedDividendTracker} deployment`);
    console.log(`\tDeploying ${StakedDividendTracker} implementation ...`);
    const stakedDividendTrackerImpl = await deployStakedDividendTracker(verify);
    await registerContractInJsonDb(StakedDividendTrackerImpl, stakedDividendTrackerImpl);

    console.log(`\tDeploying ${StakedDividendTracker} Transparent Proxy ...`);
    const stakedDividendTrackerrProxy = await deployInitializableAdminUpgradeabilityProxy(verify);
    await registerContractInJsonDb(StakedDividendTracker, stakedDividendTrackerrProxy);
    console.log(`\tFinished ${StakedDividendTracker} proxy and implementation deployment`);


    // 2
    console.log(`\n- ${FeeCollector} deployment`);
    console.log(`\tDeploying ${FeeCollector} implementation ...`);
    const feeCollector = await deployFeeCollector(verify);
    await registerContractInJsonDb(FeeCollectorImpl, feeCollector);

    console.log(`\tDeploying ${FeeCollector} Transparent Proxy ...`);
    const feeCollectorProxy = await deployInitializableAdminUpgradeabilityProxy(verify);
    await registerContractInJsonDb(FeeCollector, feeCollectorProxy);

    console.log(`\tFinished ${FeeCollector} proxy and implementation deployment`);
  });
