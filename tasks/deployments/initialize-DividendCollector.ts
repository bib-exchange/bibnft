import { InitializableAdminUpgradeabilityProxy } from './../../types/InitializableAdminUpgradeabilityProxy.d';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getDividendCollector,
  getDividendCollectorImpl,
  getContract,
  getITokenDividendTracker
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  MAX_NFT_QUOTA,
  getBIBTokenPerNetwork,
  getBIBAdminPerNetwork,
  getTokenDividendTrackerPerNetwork
 } from '../../helpers/constants';

const { DividendCollector} = eContractid;

task(`initialize-${DividendCollector}`, `Initialize the ${DividendCollector} proxy contract`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\n- Initialzie ${DividendCollector} proxy`);
    
    const network = localBRE.network.name as eEthereumNetwork;

    const admin = await getBIBAdminPerNetwork(network);
    const dividendCollector = await getDividendCollector();
    const dividendCollectorImpl = await getDividendCollectorImpl();

    const dividendCollectorProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      dividendCollector.address
    );

    const encodedInitialize = dividendCollectorImpl.interface.encodeFunctionData('initialize', [
      await getBIBTokenPerNetwork(network)
    ]);

    await waitForTx(
      await dividendCollectorProxy['initialize(address,address,bytes)'](
        dividendCollectorImpl.address,
        admin,
        encodedInitialize
      )
    );

    console.log(`\tExclude ${DividendCollector} from devidend list`);
    const tokenTracker = await getITokenDividendTracker(getTokenDividendTrackerPerNetwork(network));
    await waitForTx(
      await tokenTracker.excludeFromDividends(dividendCollector.address)
    );

    console.log(`\tFinished ${DividendCollector} proxy initialize`);
  });
