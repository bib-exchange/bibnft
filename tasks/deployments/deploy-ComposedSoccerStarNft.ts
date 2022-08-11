import { task } from 'hardhat/config';
import { eContractid } from '../../helpers/types';
import {
  deployComposedSoccerStarNft,
  registerContractInJsonDb,
  deployInitializableAdminUpgradeabilityProxy
} from '../../helpers/contracts-helpers';

const { ComposedSoccerStarNft, ComposedSoccerStarNftImpl } = eContractid;

task(`deploy-${ComposedSoccerStarNft}`, `Deploy the ${ComposedSoccerStarNft} contract`)
  .addFlag('verify', 'Proceed with the Etherscan verification')
  .setAction(async ({ verify }, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\n- ${ComposedSoccerStarNft} deployment`);

    console.log(`\tDeploying ${ComposedSoccerStarNft} implementation ...`);
    const composedSoccerStarNftImpl = await deployComposedSoccerStarNft(verify);
    await registerContractInJsonDb(ComposedSoccerStarNftImpl, composedSoccerStarNftImpl);
    console.log(`\tDeploying ${ComposedSoccerStarNft} Transparent Proxy ...`);
    const composedSoccerStarNftProxy = await deployInitializableAdminUpgradeabilityProxy(verify);
    await registerContractInJsonDb(ComposedSoccerStarNft, composedSoccerStarNftProxy);

    console.log(`\tFinished ${ComposedSoccerStarNft} proxy and implementation deployment`);
  });
