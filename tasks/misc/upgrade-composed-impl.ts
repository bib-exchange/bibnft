import { 
    InitializableAdminUpgradeabilityProxy 
} from '../../types/InitializableAdminUpgradeabilityProxy';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getContract,
  getComposedSoccerStarNft,
  getStakedSoccerStarNftV2,
  getSoccerStarNftMarket,
  deploySoccerStarNftMarket,
  deployComposedSoccerStarNft,
  getSoccerStarNftMarketImpl,
  getFirstSigner,
  insertContractAddressInDb,
} from '../../helpers/contracts-helpers';
import { waitForTx , DRE} from '../../helpers/misc-utils';

const {ComposedSoccerStarNft, ComposedSoccerStarNftImpl}  = eContractid;

task(`upgrade:composedImpl`, `Update the specific contract to a higher version`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    const network = localBRE.network.name as eEthereumNetwork;

    // TODO: replace the target contract before update
    const adminKey = '';
    const targetContractName = eContractid.SoccerStarNftMarket;
    const composedSoccerStarNft = await getComposedSoccerStarNft();
    const composedSoccerStarNftImpl = await deployComposedSoccerStarNft();
    await insertContractAddressInDb(ComposedSoccerStarNft, composedSoccerStarNft.address);
    await insertContractAddressInDb(ComposedSoccerStarNftImpl, composedSoccerStarNftImpl.address);

    const signer = (new DRE.ethers.Wallet(adminKey)).connect(DRE.ethers.provider);

    console.log(`\n- Upgrade ${targetContractName} to ${composedSoccerStarNftImpl.address}`);

    const composedSoccerStarNftProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
        eContractid.InitializableAdminUpgradeabilityProxy,
        composedSoccerStarNft.address
      );

  
    await waitForTx(
    await composedSoccerStarNftProxy.connect(signer).upgradeTo(
        composedSoccerStarNftImpl.address,
        {gasLimit:2e6, gasPrice:10e9}
    )
    );

    console.log(`\tFinished updgrade ${eContractid.ComposedSoccerStarNft} proxy initialize`);
  });
