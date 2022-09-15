import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { eEthereumNetwork } from '../../helpers/types-common';
import { eContractid } from '../../helpers/types';
import { checkVerification } from '../../helpers/etherscan-verification';
import { getBIBAdminPerNetwork } from '../../helpers/constants';
require('dotenv').config();

task('run:deploy-nft', 'Deployment in bsc-test network')
  .addFlag(
    'verify',
    'Verify contract.'
  )
  .setAction(async ({ verify }, localBRE) => {
    const DRE: HardhatRuntimeEnvironment = await localBRE.run('set-dre');
    const network = DRE.network.name as eEthereumNetwork;
    const admin = getBIBAdminPerNetwork(network);

    if (!admin) {
      throw Error(
        'The --admin parameter must be set for bsc-test network. Set an Ethereum address as --admin parameter input.'
      );
    }

    // If Etherscan verification is enabled, check needed enviroments to prevent loss of gas in failed deployments.
    if (verify) {
      checkVerification();
    }

    // 1. deploy SoccerStarNft
    await DRE.run(`deploy-${eContractid.SoccerStarNft}`, { verify });


    // 2
    await DRE.run(`initialize-${eContractid.SoccerStarNft}`, { verify, init:true, configure:false });

    console.log(`\n✔️ Finished the deployment for ${eContractid.SoccerStarNft}. ✔️`);
  });
