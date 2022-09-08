import { 
    InitializableAdminUpgradeabilityProxy 
} from '../../types/InitializableAdminUpgradeabilityProxy';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getSoccerStarNft,
  getSoccerStarNftImpl,
  getContract,
  getComposedSoccerStarNft,
  getStakedSoccerStarNftV2,
  getSoccerStarNftMarket,
  deploySoccerStarNftMarket,
  getSoccerStarNftMarketImpl,
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

const {SoccerStarNftMarket,SoccerStarNftMarketImpl}  = eContractid;

task(`upgrade:marketImpl`, `Update the specific contract to a higher version`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    const network = localBRE.network.name as eEthereumNetwork;

    // TODO: replace the target contract before update
    const adminKey = '';
    const targetContractName = eContractid.SoccerStarNftMarket;
    const soccerStarNftMarketNft = await getSoccerStarNftMarket();
    const soccerStarNftMarketNftImpl = await deploySoccerStarNftMarket();
    await insertContractAddressInDb(SoccerStarNftMarket, soccerStarNftMarketNft.address);
    await insertContractAddressInDb(SoccerStarNftMarketImpl, soccerStarNftMarketNftImpl.address);

    const signer = (new DRE.ethers.Wallet(adminKey)).connect(DRE.ethers.provider);

    console.log(`\n- Upgrade ${targetContractName} to ${soccerStarNftMarketNftImpl.address}`);

    const soccerStarNftMarketNftProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
        eContractid.InitializableAdminUpgradeabilityProxy,
        soccerStarNftMarketNft.address
      );

  
    await waitForTx(
    await soccerStarNftMarketNftProxy.connect(signer).upgradeTo(
        soccerStarNftMarketNftImpl.address,
        {gasLimit:2e6, gasPrice:10e9}
    )
    );

    console.log(`\tFinished updgrade ${eContractid.SoccerStarNftMarket} proxy initialize`);
  });
