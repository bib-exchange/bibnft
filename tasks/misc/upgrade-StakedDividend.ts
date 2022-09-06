import { 
    InitializableAdminUpgradeabilityProxy 
} from '../../types/InitializableAdminUpgradeabilityProxy';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getContract,
  getStakedDividendTracker,
  getStakedDividendTrackerImpl,
  deployStakedDividendTracker,
  getFirstSigner,
  insertContractAddressInDb,
} from '../../helpers/contracts-helpers';
import { waitForTx , DRE} from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  MAX_NFT_QUOTA,
  getBIBTokenPerNetwork,
  getBUSDTokenPerNetwork,
  getSwapRoterPerNetwork,
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork,
 } from '../../helpers/constants';
import { ethers } from 'ethers';
import { Provider } from '@ethersproject/abstract-provider';

const {StakedDividendTracker,StakedDividendTrackerImpl}  = eContractid;

task(`upgrade:stakedDividendImpl`, `Update the specific contract to a higher version`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    const network = localBRE.network.name as eEthereumNetwork;

    // TODO: replace the target contract before update
    const adminKey = '';
    const stakedDividendTracker = await getStakedDividendTracker();
    const stakedDividendTrackerImpl = await deployStakedDividendTracker();
    await insertContractAddressInDb(StakedDividendTracker, stakedDividendTracker.address);
    await insertContractAddressInDb(StakedDividendTrackerImpl, stakedDividendTrackerImpl.address);

    const signer = (new DRE.ethers.Wallet(adminKey)).connect(DRE.ethers.provider);

    console.log(`\n- Upgrade ${StakedDividendTracker} to ${stakedDividendTrackerImpl.address}`);

    const stakedDividendTrackerProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
        eContractid.InitializableAdminUpgradeabilityProxy,
        stakedDividendTracker.address
      );

    await waitForTx(
    await stakedDividendTrackerProxy.connect(signer).upgradeTo(
        stakedDividendTrackerImpl.address,
        {gasLimit:2e6, gasPrice:10e9}
    )
    );

    console.log(`\tFinished updgrade ${eContractid.StakedDividendTracker} proxy initialize`);
  });
