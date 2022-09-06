import { 
    InitializableAdminUpgradeabilityProxy 
} from '../../types/InitializableAdminUpgradeabilityProxy';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getSoccerStarNft,
  deploySoccerStarNft,
  getContract,
  insertContractAddressInDb,
} from '../../helpers/contracts-helpers';
import { waitForTx , DRE} from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  MAX_NFT_QUOTA
 } from '../../helpers/constants';
import { ethers } from 'ethers';
import { Provider } from '@ethersproject/abstract-provider';

const {SoccerStarNft,SoccerStarNftImpl}  = eContractid;

task(`upgrade:soccerStarNftImpl`, `Update the specific contract to a higher version`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    const network = localBRE.network.name as eEthereumNetwork;
    
    // TODO: replace the target contract before update
    const adminKey = '1569e8b0f240e813178da4ed85890921dfbb75097218ca457d75ffc74b71358f';
    const soccerStarNft = await getSoccerStarNft();
    const soccerStarNftImpl = await deploySoccerStarNft();
    await insertContractAddressInDb(SoccerStarNft, soccerStarNft.address);
    await insertContractAddressInDb(SoccerStarNftImpl, soccerStarNftImpl.address);

    const signer = (new DRE.ethers.Wallet(adminKey)).connect(DRE.ethers.provider);

    console.log(`\n- Upgrade ${SoccerStarNft} to ${soccerStarNftImpl.address}`);

    const stakedSoccerStarNftV2Proxy = await getContract<InitializableAdminUpgradeabilityProxy>(
        eContractid.InitializableAdminUpgradeabilityProxy,
        soccerStarNft.address
      );

    await waitForTx(
    await stakedSoccerStarNftV2Proxy.connect(signer).upgradeTo(
        soccerStarNftImpl.address,
        {gasLimit:3e6, gasPrice:12e9}
    )
    );

    console.log(`\tFinished updgrade ${eContractid.SoccerStarNft} proxy initialize`);
  });
