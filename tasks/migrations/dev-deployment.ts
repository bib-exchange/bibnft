import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { eContractid } from '../../helpers/types';
import { getEthersSigners } from '../../helpers/contracts-helpers';
import { checkVerification } from '../../helpers/etherscan-verification';
require('dotenv').config();

task('dev-deployment', 'Deployment in hardhat')
  .addFlag('verify', 'Verify BIBToken and InitializableAdminUpgradeabilityProxy contract.')
  .setAction(async ({ admin, verify }, localBRE) => {
    const DRE: HardhatRuntimeEnvironment = await localBRE.run('set-dre');

    // If admin parameter is NOT set, the BIB Admin will be the
    // second account provided via buidler config.
    const [, secondaryWallet] = await getEthersSigners();
    const BIBAdmin = admin || (await secondaryWallet.getAddress());

    console.log('BIB ADMIN', BIBAdmin);

    // If Etherscan verification is enabled, check needed enviroments to prevent loss of gas in failed deployments.
    if (verify) {
      checkVerification();
    }

    console.log('\n👷 Finished the deployment of the BIB  Development Enviroment. 👷');
  });
