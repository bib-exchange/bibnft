import { task } from 'hardhat/config';
import { eContractid } from '../../helpers/types';
import {
  deploySoccerStarNft,
  registerContractInJsonDb,
} from '../../helpers/contracts-helpers';
import { InitializableAdminUpgradeabilityProxy } from '../../types/InitializableAdminUpgradeabilityProxy';

const { SoccerStarNft } = eContractid;

task(`deploy-${SoccerStarNft}`, `Deploy the ${SoccerStarNft} contract`)
  .addFlag('verify', 'Proceed with the Etherscan verification')
  .setAction(async ({ verify }, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
  });
