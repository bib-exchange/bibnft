import { InitializableAdminUpgradeabilityProxy } from './../../types/InitializableAdminUpgradeabilityProxy.d';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getSoccerStarNft,
  getContract,
  getStakedSoccerStarNftV2,
  getStakedSoccerStarNftV2Impl
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  getBIBTokenPerNetwork,
  getBUSDTokenPerNetwork,
  getMockOraclePerNetwork,
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork,
  getRewardVaultPerNetwork,
  EMISSION_PER_SECONDS,
  DISTRIBUTION_END
 } from '../../helpers/constants';

const {StakedSoccerStarNftV2} = eContractid;

task(`initialize-${StakedSoccerStarNftV2}`, `Initialize the ${StakedSoccerStarNftV2} proxy contract`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');


    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\tInitialzie ${StakedSoccerStarNftV2} proxy`);
    
    const network = localBRE.network.name as eEthereumNetwork;

    const admin = await getBIBAdminPerNetwork(network);
    const soccerStarNft = await getSoccerStarNft();

    const stakedSoccerStarNftV2 = await getStakedSoccerStarNftV2();
    const stakedSoccerStarNftV2Impl = await getStakedSoccerStarNftV2Impl();

    const stakedSoccerStarNftV2Proxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      stakedSoccerStarNftV2.address
    );
    
    const encodedInitialize = stakedSoccerStarNftV2Impl.interface.encodeFunctionData('initialize', [
        soccerStarNft.address,
        await getBIBTokenPerNetwork(network),
        await getRewardVaultPerNetwork(network),
        DISTRIBUTION_END
    ]);

    await waitForTx(
      await stakedSoccerStarNftV2Proxy['initialize(address,address,bytes)'](
        stakedSoccerStarNftV2Impl.address,
        admin,
        encodedInitialize
      )
    );

    // config emission
    const rewardEmission:{
      emissionPerSecond: string,
      totalPower: string,
      underlyingAsset: string
    } = {
      emissionPerSecond: EMISSION_PER_SECONDS,
      totalPower: "0",
      underlyingAsset: stakedSoccerStarNftV2.address
    };
    console.log(`configure emission:
      ${rewardEmission}
    `);
    await waitForTx( 
      await stakedSoccerStarNftV2.configureAssets([rewardEmission]));

    console.log(`\tFinished ${StakedSoccerStarNftV2} proxy initialize`);
  });
