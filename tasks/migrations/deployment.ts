import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { eEthereumNetwork } from '../../helpers/types-common';
import { eContractid } from '../../helpers/types';
import { checkVerification } from '../../helpers/etherscan-verification';
import { getBIBAdminPerNetwork } from '../../helpers/constants';
require('dotenv').config();

task('deployment', 'Deployment in bsc-test network')
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

    // // 2. deploy ComposedSoccerStarNft
    await DRE.run(`deploy-${eContractid.ComposedSoccerStarNft}`, { verify });

    // // 3. deploy SoccerStarNftMarket
    await DRE.run(`deploy-${eContractid.SoccerStarNftMarket}`, { verify });

    // // 4. deploy StakedSoccerStarNftV2
    await DRE.run(`deploy-${eContractid.StakedSoccerStarNftV2}`, { verify });

    // // 5. deploy StakedDividendTracker
    await DRE.run(`deploy-dividend`, { verify });

    // 6. deploy deploy-${StakedRewardUiDataProvider}
    await DRE.run(`deploy-${eContractid.StakedRewardUiDataProvider}`, {verify})

    // 7. deploy deploy-CommunityNode
    await DRE.run(`deploy-CommunityNode`, {verify});

    // 8. deploy DividendCollector
    await DRE.run(`deploy-DividendCollector`, {verify});


    // 1
    await DRE.run(`initialize-${eContractid.SoccerStarNft}`, { verify });
    // 2
    await DRE.run(`initialize-${eContractid.ComposedSoccerStarNft}`, { verify });
    // 3
    await DRE.run(`initialize-${eContractid.SoccerStarNftMarket}`, { verify });
    // 4
    await DRE.run(`initialize-${eContractid.StakedSoccerStarNftV2}`, { verify });
    // 5
    await DRE.run(`initialize-dividend`, { verify });
    // 6
    await DRE.run(`initialize-CommunityNode`, {verify});
    // 7
    await DRE.run(`initialize-DividendCollector`, {verify});

    console.log(`\n✔️ Finished the deployment for ${network}. ✔️`);
  });
