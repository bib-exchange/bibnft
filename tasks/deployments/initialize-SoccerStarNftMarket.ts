import { InitializableAdminUpgradeabilityProxy } from './../../types/InitializableAdminUpgradeabilityProxy.d';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getSoccerStarNftMarket,
  getSoccerStarNftMarketImpl,
  getSoccerStarNft,
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

const { SoccerStarNftMarket } = eContractid;

task(`initialize-${SoccerStarNftMarket}`, `Initialize the ${SoccerStarNftMarket} proxy contract`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }

    console.log(`\n- Initialzie ${SoccerStarNftMarket} proxy`);
    
    const network = localBRE.network.name as eEthereumNetwork;

    const admin = await getBIBAdminPerNetwork(network);
    const soccerStarNft = await getSoccerStarNft();

    const soccerStarNftMarketNft = await getSoccerStarNftMarket();
    const soccerStarNftMarketNftImpl = await getSoccerStarNftMarketImpl();

    const soccerStarNftMarketNftProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      soccerStarNftMarketNft.address
    );

    const encodedInitialize = soccerStarNftMarketNftImpl.interface.encodeFunctionData('initialize', [
      soccerStarNft.address,
      await getBIBTokenPerNetwork(network),
      await getBUSDTokenPerNetwork(network),
      await getTreasuryPerNetwork(network),
    ]);

    await waitForTx(
      await soccerStarNftMarketNftProxy['initialize(address,address,bytes)'](
        soccerStarNftMarketNftImpl.address,
        admin,
        encodedInitialize
      )
    );

    console.log(`\tFinished ${SoccerStarNftMarket} proxy initialize`);
  });
