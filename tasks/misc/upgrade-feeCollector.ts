import { 
    InitializableAdminUpgradeabilityProxy 
} from '../../types/InitializableAdminUpgradeabilityProxy';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getContract,
  getFeeCollector,
  deployFeeCollector,
  insertContractAddressInDb,
} from '../../helpers/contracts-helpers';
import { waitForTx , DRE} from '../../helpers/misc-utils';

const {FeeCollector,FeeCollectorImpl}  = eContractid;

task(`upgrade:fee-collector`, `Update the specific contract to a higher version`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    const network = localBRE.network.name as eEthereumNetwork;

    // TODO: replace the target contract before update
    const adminKey = '1569e8b0f240e813178da4ed85890921dfbb75097218ca457d75ffc74b71358f';
    const targetContractName = eContractid.FeeCollector;
    const feeCollector = await getFeeCollector();
    const feeCollectorImpl = await deployFeeCollector();
    await insertContractAddressInDb(FeeCollector, feeCollector.address);
    await insertContractAddressInDb(FeeCollectorImpl, feeCollectorImpl.address);

    const signer = (new DRE.ethers.Wallet(adminKey)).connect(DRE.ethers.provider);

    console.log(`\n- Upgrade ${targetContractName} to ${feeCollectorImpl.address}`);

    const feeCollectorProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
        eContractid.InitializableAdminUpgradeabilityProxy,
        feeCollector.address
      );
  
    await waitForTx(
    await feeCollectorProxy.connect(signer).upgradeTo(
        feeCollectorImpl.address,
        {gasLimit:2e6, gasPrice:10e9})
    );

    console.log(`\tFinished updgrade ${eContractid.FeeCollector} proxy initialize`);
  });
