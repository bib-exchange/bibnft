import { InitializableAdminUpgradeabilityProxy } from './../../types/InitializableAdminUpgradeabilityProxy.d';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getSoccerStarNft,
  getComposedSoccerStarNft,
  getComposedSoccerStarNftImpl,
  getContract
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  getBIBTokenPerNetwork,
  getBUSDTokenPerNetwork,
  getMockOraclePerNetwork,
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork
 } from '../../helpers/constants';

const { ComposedSoccerStarNft, SoccerStarNft } = eContractid;

task(`initialize-${ComposedSoccerStarNft}`, `Initialize the ${ComposedSoccerStarNft} proxy contract`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\n- Initialzie ${ComposedSoccerStarNft} proxy`);
    
    const network = localBRE.network.name as eEthereumNetwork;
    
    const admin = await getBIBAdminPerNetwork(network);
    const soccerStarNft = await getSoccerStarNft();
    const composedSoccerStarNft = await getComposedSoccerStarNft();
    const composedSoccerStarNftImpl = await getComposedSoccerStarNftImpl();

    const composedSoccerStarNftProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      composedSoccerStarNft.address
    );

    const encodedInitialize = composedSoccerStarNftImpl.interface.encodeFunctionData('initialize', [
      soccerStarNft.address,
      await getBIBTokenPerNetwork(network),
      await getBUSDTokenPerNetwork(network),
      await getTreasuryPerNetwork(network),
      await getMockOraclePerNetwork(network) // TODO: replace with DEX SWATP
    ]);

    await waitForTx(
      await composedSoccerStarNftProxy['initialize(address,address,bytes)'](
        composedSoccerStarNftImpl.address,
        admin,
        encodedInitialize
      )
    );

    console.log(`\tFinished ${ComposedSoccerStarNft} proxy initialize`);
  });
