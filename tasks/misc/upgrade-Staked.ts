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
  deployStakedSoccerStarNftV2,
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

const {StakedSoccerStarNftV2,StakedSoccerStarNftV2Impl}  = eContractid;

task(`upgrade:stakedImpl`, `Update the specific contract to a higher version`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    const network = localBRE.network.name as eEthereumNetwork;

    // TODO: replace the target contract before update
    const adminKey = '1569e8b0f240e813178da4ed85890921dfbb75097218ca457d75ffc74b71358f';
    const stakedSoccerStarNftV2 = await getStakedSoccerStarNftV2();
    const stakedSoccerStarNftV2Impl = await deployStakedSoccerStarNftV2();
    await insertContractAddressInDb(StakedSoccerStarNftV2, stakedSoccerStarNftV2.address);
    await insertContractAddressInDb(StakedSoccerStarNftV2Impl, stakedSoccerStarNftV2Impl.address);

    const signer = (new DRE.ethers.Wallet(adminKey)).connect(DRE.ethers.provider);

    console.log(`\n- Upgrade ${StakedSoccerStarNftV2} to ${stakedSoccerStarNftV2Impl.address}`);

    const stakedSoccerStarNftV2Proxy = await getContract<InitializableAdminUpgradeabilityProxy>(
        eContractid.InitializableAdminUpgradeabilityProxy,
        stakedSoccerStarNftV2.address
      );

    await waitForTx(
    await stakedSoccerStarNftV2Proxy.connect(signer).upgradeTo(
        stakedSoccerStarNftV2Impl.address,
        {gasLimit:2e6, gasPrice:10e9}
    )
    );

    console.log(`\tFinished updgrade ${eContractid.StakedSoccerStarNftV2} proxy initialize`);
  });
