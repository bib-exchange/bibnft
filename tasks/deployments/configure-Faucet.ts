import { task } from 'hardhat/config';
import {
  getFaucet,
  registerContractInJsonDb,
} from '../../helpers/contracts-helpers';
import { eContractid } from '../../helpers/types';
import { getAllClaimInfo } from '../../helpers/constants';
import { waitForTx } from '../../helpers/misc-utils';

const { Faucet } = eContractid;

task('configure-Faucet', 'Congiure the faucet assets in shibuya network')
.addFlag('verify', 'Verify faucet contract.')
  .setAction(async ({ verify }, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\Congiure ${Faucet} implementation ...`);
    const faucetImpl = await getFaucet();
  
    console.log('\n✔️ Finished the deployment of the faucet Shibuya Enviroment. ✔️');

    const assets = getAllClaimInfo();
    console.log(JSON.stringify(assets, null, 2))

    await waitForTx(
      await faucetImpl.addAssets(
        assets
      )
    );
    console.log('\n✔️ Finished the configration of the faucet. ✔️');
  });