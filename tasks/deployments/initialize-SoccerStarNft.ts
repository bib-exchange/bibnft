import { InitializableAdminUpgradeabilityProxy } from './../../types/InitializableAdminUpgradeabilityProxy.d';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getSoccerStarNft,
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  
 } from '../../helpers/constants';

const { SoccerStarNft } = eContractid;

task(`initialize-${SoccerStarNft}`, `Initialize the ${SoccerStarNft} proxy contract`)
  .addParam('admin', `The address to be added as an Admin role in ${SoccerStarNft} Transparent Proxy.`)
  .addFlag('onlyProxy', 'Initialize only the proxy contract, not the implementation contract')
  .setAction(async ({ admin: BIBAdmin, onlyProxy }, localBRE) => {
    await localBRE.run('set-dre');

    if (!BIBAdmin) {
      throw new Error(
        `Missing --admin parameter to add the Admin Role to ${SoccerStarNft} Transparent Proxy`
      );
    }

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    const network = localBRE.network.name as eEthereumNetwork;
  });
