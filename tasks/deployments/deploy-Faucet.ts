import { task } from 'hardhat/config';
import {
  deployFaucet,
  registerContractInJsonDb,
} from '../../helpers/contracts-helpers';
import { eContractid } from '../../helpers/types';
import { getAllClaimInfo } from '../../helpers/constants';
import { waitForTx } from '../../helpers/misc-utils';

const { Faucet } = eContractid;

task('deploy-Faucet', 'Deployment in shibuya network')
.addFlag('verify', 'Verify faucet contract.')
  .setAction(async ({ verify }, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\n- ${Faucet} deployment`);

    console.log(`\tDeploying ${Faucet} implementation ...`);
    const faucetImpl = await deployFaucet(verify);
    await registerContractInJsonDb(Faucet, faucetImpl);
  
    console.log('\n✔️ Finished the deployment of the faucet Shibuya Enviroment. ✔️');

    const assets = getAllClaimInfo();

    await waitForTx(
      await faucetImpl.addAssets(
        assets
      )
    );
    console.log('\n✔️ Finished the configration of the faucet. ✔️');
  });