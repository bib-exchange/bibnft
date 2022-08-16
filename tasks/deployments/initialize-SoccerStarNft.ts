import { InitializableAdminUpgradeabilityProxy } from './../../types/InitializableAdminUpgradeabilityProxy.d';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getSoccerStarNft,
  getSoccerStarNftImpl,
  getContract
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  MAX_NFT_QUOTA,
  getBIBTokenPerNetwork,
  getBUSDTokenPerNetwork,
  getSwapRoterPerNetwork,
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork
 } from '../../helpers/constants';

const { SoccerStarNft } = eContractid;

task(`initialize-${SoccerStarNft}`, `Initialize the ${SoccerStarNft} proxy contract`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\Initialzie ${SoccerStarNft} proxy`);
    
    const network = localBRE.network.name as eEthereumNetwork;

    const admin = await getBIBAdminPerNetwork(network);
    const soccerStarNft = await getSoccerStarNft();
    const soccerStarNftImpl = await getSoccerStarNftImpl();

    const soccerStarNftProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      soccerStarNft.address
    );

    const encodedInitialize = soccerStarNftImpl.interface.encodeFunctionData('initialize', [
      MAX_NFT_QUOTA,
      await getBIBTokenPerNetwork(network),
      await getBUSDTokenPerNetwork(network),
      await getTreasuryPerNetwork(network),
      await getSwapRoterPerNetwork(network)
    ]);

    await waitForTx(
      await soccerStarNftProxy['initialize(address,address,bytes)'](
        soccerStarNftImpl.address,
        admin,
        encodedInitialize
      )
    );

    console.log(`\tFinished ${SoccerStarNft} proxy initialize`);
  });
