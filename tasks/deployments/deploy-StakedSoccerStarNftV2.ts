import { task } from 'hardhat/config';
import { eContractid } from '../../helpers/types';
import {
  deployStakedSoccerStarNftV2,
  registerContractInJsonDb,
  deployInitializableAdminUpgradeabilityProxy
} from '../../helpers/contracts-helpers';

const { StakedSoccerStarNftV2, StakedSoccerStarNftV2Impl } = eContractid;

task(`deploy-${StakedSoccerStarNftV2}`, `Deploy the ${StakedSoccerStarNftV2} contract`)
  .addFlag('verify', 'Proceed with the Etherscan verification')
  .setAction(async ({ verify }, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\n- ${StakedSoccerStarNftV2} deployment`);

    console.log(`\tDeploying ${StakedSoccerStarNftV2} implementation ...`);
    const stakedSoccerStarNftV2Impl = await deployStakedSoccerStarNftV2(verify);
    await registerContractInJsonDb(StakedSoccerStarNftV2Impl, stakedSoccerStarNftV2Impl);

    console.log(`\tDeploying ${StakedSoccerStarNftV2} Transparent Proxy ...`);
    const soccerStarNftProxy = await deployInitializableAdminUpgradeabilityProxy(verify);
    await registerContractInJsonDb(StakedSoccerStarNftV2, soccerStarNftProxy);

    console.log(`\tFinished ${StakedSoccerStarNftV2} proxy and implementation deployment`);
  });
