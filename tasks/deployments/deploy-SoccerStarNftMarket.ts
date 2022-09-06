import { task } from 'hardhat/config';
import { eContractid } from '../../helpers/types';
import {
  deploySoccerStarNftMarket,
  registerContractInJsonDb,
  deployInitializableAdminUpgradeabilityProxy
} from '../../helpers/contracts-helpers';

const { SoccerStarNftMarket, SoccerStarNftMarketImpl } = eContractid;

task(`deploy-${SoccerStarNftMarket}`, `Deploy the ${SoccerStarNftMarket} contract`)
  .addFlag('verify', 'Proceed with the Etherscan verification')
  .setAction(async ({ verify }, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\n- ${SoccerStarNftMarket} deployment`);

    console.log(`\tDeploying ${SoccerStarNftMarket} implementation ...`);
    const soccerStarNftMarketImpl = await deploySoccerStarNftMarket(verify);
    await registerContractInJsonDb(SoccerStarNftMarketImpl, soccerStarNftMarketImpl);

    console.log(`\tDeploying ${SoccerStarNftMarket} Transparent Proxy ...`);
    const soccerStarNftMarketProxy = await deployInitializableAdminUpgradeabilityProxy(verify);
    await registerContractInJsonDb(SoccerStarNftMarket, soccerStarNftMarketProxy);

    console.log(`\tFinished ${SoccerStarNftMarket} proxy and implementation deployment`);
  });
