import { task } from 'hardhat/config';
import { eContractid } from '../../helpers/types';
import {
  deploySoccerStarNft,
  registerContractInJsonDb,
  deployInitializableAdminUpgradeabilityProxy
} from '../../helpers/contracts-helpers';

const { SoccerStarNft, SoccerStarNftImpl } = eContractid;

task(`deploy-${SoccerStarNft}`, `Deploy the ${SoccerStarNft} contract`)
  .addFlag('verify', 'Proceed with the Etherscan verification')
  .setAction(async ({ verify }, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\n- ${SoccerStarNft} deployment`);

    console.log(`\tDeploying ${SoccerStarNft} implementation ...`);
    const soccerStarNftImpl = await deploySoccerStarNft(verify);
    await registerContractInJsonDb(SoccerStarNftImpl, soccerStarNftImpl);

    console.log(`\tDeploying ${SoccerStarNft} Transparent Proxy ...`);
    const soccerStarNftProxy = await deployInitializableAdminUpgradeabilityProxy(verify);
    await registerContractInJsonDb(SoccerStarNft, soccerStarNftProxy);

    console.log(`\tFinished ${SoccerStarNft} proxy and implementation deployment`);
  });
