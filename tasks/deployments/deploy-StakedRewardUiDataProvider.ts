import { InitializableAdminUpgradeabilityProxy } from '../../types/InitializableAdminUpgradeabilityProxy';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  registerContractInJsonDb,
  getStakedSoccerStarNftV2,
  getStakedDividendTracker,
  deployStakedRewardUiDataProvider
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  MAX_NFT_QUOTA,
  getBIBTokenPerNetwork,
  getBUSDTokenPerNetwork,
  getMockOraclePerNetwork,
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork
 } from '../../helpers/constants';

const { StakedRewardUiDataProvider } = eContractid;

task(`deploy-${StakedRewardUiDataProvider}`, `Initialize the ${StakedRewardUiDataProvider} proxy contract`)
.addFlag('verify', 'Proceed with the Etherscan verification')  
.setAction(async ({verify}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\n- ${StakedRewardUiDataProvider} deployment`);

    const network = localBRE.network.name as eEthereumNetwork;

    const staked = await getStakedSoccerStarNftV2();
    const dividend = await getStakedDividendTracker();

    console.log(`\tDeploying ${StakedRewardUiDataProvider} implementation ...`);
    const stakedRewardUiDataProvider = await deployStakedRewardUiDataProvider(
      staked.address, dividend.address, verify);
    await registerContractInJsonDb(StakedRewardUiDataProvider, stakedRewardUiDataProvider);

    console.log(`\tFinished ${StakedRewardUiDataProvider} implementation deployment`);
  });
