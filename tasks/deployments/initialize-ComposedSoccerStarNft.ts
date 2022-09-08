import { InitializableAdminUpgradeabilityProxy } from './../../types/InitializableAdminUpgradeabilityProxy.d';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getSoccerStarNft,
  getComposedSoccerStarNft,
  getComposedSoccerStarNftImpl,
  getContract,
  getITokenDividendTracker
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  getBIBTokenPerNetwork,
  getBUSDTokenPerNetwork,
  getSwapRoterPerNetwork,
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork,
  getTokenDividendTrackerPerNetwork,
  getRevealWalletPerNetwork
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
      await getSwapRoterPerNetwork(network)
    ]);

    await waitForTx(
      await composedSoccerStarNftProxy['initialize(address,address,bytes)'](
        composedSoccerStarNftImpl.address,
        admin,
        encodedInitialize
      )
    );

    const revealWallet = await getRevealWalletPerNetwork(network);
    console.log(`\tAllow reveal wallet ${revealWallet} to call ${ComposedSoccerStarNft} proxy`);
    await waitForTx(
      await composedSoccerStarNft.setAllowToCall(revealWallet, true)
    );

    console.log(`\tExclude ${ComposedSoccerStarNft} from devidend list`);
    const tokenTracker = await getITokenDividendTracker(getTokenDividendTrackerPerNetwork(network));
    await waitForTx(
      await tokenTracker.excludeFromDividends(composedSoccerStarNft.address)
    );
    console.log(`\tFinished ${ComposedSoccerStarNft} proxy initialize`);
  });
