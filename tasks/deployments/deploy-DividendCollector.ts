import { task } from 'hardhat/config';
import { eContractid } from '../../helpers/types';
import {
  deployDividendCollector,
  registerContractInJsonDb,
  deployInitializableAdminUpgradeabilityProxy
} from '../../helpers/contracts-helpers';

const { DividendCollector, DividendCollectorImpl } = eContractid;

task(`deploy-${DividendCollector}`, `Deploy the ${DividendCollector} contract`)
  .addFlag('verify', 'Proceed with the Etherscan verification')
  .setAction(async ({ verify }, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\n- ${DividendCollector} deployment`);

    console.log(`\tDeploying ${DividendCollector} implementation ...`);
    const dividendCollectorImpl = await deployDividendCollector(verify);
    await registerContractInJsonDb(DividendCollectorImpl, dividendCollectorImpl);

    console.log(`\tDeploying ${DividendCollector} Transparent Proxy ...`);
    const dividendCollectorProxy = await deployInitializableAdminUpgradeabilityProxy(verify);
    await registerContractInJsonDb(DividendCollector, dividendCollectorProxy);

    console.log(`\tFinished ${DividendCollector} proxy and implementation deployment`);
  });
