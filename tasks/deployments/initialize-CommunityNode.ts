import { InitializableAdminUpgradeabilityProxy } from './../../types/InitializableAdminUpgradeabilityProxy.d';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getBIBDividend,
  getBIBDividendImpl,
  getBIBNode,
  getBIBNodeImpl,
  getBIBStaking,
  getBIBStakingImpl,
  getSoccerStarNft,
  getFeeCollector,
  getStakedSoccerStarNftV2,
  getSoccerStarNftMarket,
  getContract
} from '../../helpers/contracts-helpers';
import { waitForTx } from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  getBIBTokenPerNetwork,
  getBUSDTokenPerNetwork,
  getSwapRoterPerNetwork,
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork,
  DRIP_RATE_PER_SECOND
 } from '../../helpers/constants';

const { BIBDividend, BIBNode, BIBStaking , FeeCollector} = eContractid;

task(`initialize-CommunityNode`, `Initialize the CommunityNode proxy contract`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    
    const network = localBRE.network.name as eEthereumNetwork;

    const admin = await getBIBAdminPerNetwork(network);
    const soccerStarNft = await getSoccerStarNft();
    const soccerStakedNft = await getStakedSoccerStarNftV2();
    const soccerStartNftMarket = await getSoccerStarNftMarket();

    const bibNode = await getBIBNode();
    const bibNodeImpl = await getBIBNodeImpl();

    const bibStaking = await getBIBStaking();
    const bibStakingImpl = await getBIBStakingImpl();

    const bibDividend = await getBIBDividend();
    const bibDividendImpl = await getBIBDividendImpl();

    console.log(`\n- Initialzie ${BIBDividend} proxy`);
    const bibDividendProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      bibDividend.address
    );
    let encodedInitialize = bibDividendImpl.interface.encodeFunctionData('initialize', [
      await getBIBTokenPerNetwork(network),
      DRIP_RATE_PER_SECOND
    ]);
    await waitForTx(
      await bibDividendProxy['initialize(address,address,bytes)'](
        bibDividendImpl.address,
        admin,
        encodedInitialize
      )
    );
    console.log(`\tFinished ${BIBDividend} proxy initialize`);

    console.log(`\n- Initialzie ${BIBNode} proxy`);
    const bibNodeProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      bibNode.address
    );
    encodedInitialize = bibNodeImpl.interface.encodeFunctionData('initialize', [
        soccerStakedNft.address,
        soccerStarNft.address,
        await getBIBTokenPerNetwork(network),
        bibStaking.address,
        soccerStartNftMarket.address
    ]);
    await waitForTx(
      await bibNodeProxy['initialize(address,address,bytes)'](
        bibNodeImpl.address,
        admin,
        encodedInitialize
      )
    );
    console.log(`\tFinished ${BIBNode} proxy initialize`);

    console.log(`\n- Initialzie ${BIBStaking} proxy`);
    const bibStakingProxy = await getContract<InitializableAdminUpgradeabilityProxy>(
      eContractid.InitializableAdminUpgradeabilityProxy,
      bibStaking.address
    );
    encodedInitialize = bibStakingImpl.interface.encodeFunctionData('initialize', [
        await getBIBTokenPerNetwork(network),
        bibNode.address,
        bibDividend.address,
        soccerStarNft.address,
    ]);
    await waitForTx(
      await bibStakingProxy['initialize(address,address,bytes)'](
        bibStakingImpl.address,
        admin,
        encodedInitialize
      )
    );
    console.log(`\tFinished ${BIBStaking} proxy initialize`);

    // 1 set dividend controller
    console.log(`\tConfig ${BIBDividend} controller`);
    await waitForTx(
      await bibDividend.setController(
        bibStaking.address
      )
    );

    // 2 allow fee collector to call
    const feeCollector = await getFeeCollector();
    console.log(`\tAllow ${FeeCollector} to call ${BIBDividend}`)
    await waitForTx(
      await bibDividend.setDividendSetter(feeCollector.address)
    );
  });
