import chalk from 'chalk';

import { 
    InitializableAdminUpgradeabilityProxy 
} from '../../types/InitializableAdminUpgradeabilityProxy';
import { task } from 'hardhat/config';
import { eContractid} from '../../helpers/types';
import { eEthereumNetwork } from '../../helpers/types-common';
import {
  getSoccerStarNft,
  getComposedSoccerStarNft,
  getStakedSoccerStarNftV2,
  deployStakedSoccerStarNftV2,
  getSoccerStarNftMarketImpl,
  getFirstSigner,
  insertContractAddressInDb,
  getBIBNode,
  getITokenDividendTracker
} from '../../helpers/contracts-helpers';
import { waitForTx , DRE} from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  MAX_NFT_QUOTA,
  getBIBTokenPerNetwork,
  getBUSDTokenPerNetwork,
  getSwapRoterPerNetwork,
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork,
  getTokenDividendTrackerPerNetwork
 } from '../../helpers/constants';
import { ethers } from 'ethers';
import { Provider } from '@ethersproject/abstract-provider';

const {
    SoccerStarNft,
    ComposedSoccerStarNft,
    StakedSoccerStarNftV2,
    BIBNode
    }  = eContractid;

function verify(msg:string, checked: boolean){
    if(checked){
        console.log(chalk.green(`Checked${msg} ✔`));
    } else {
        console.log(chalk.red(`Checked${msg} ✘`));
    }
}

task(`run:check`, `Check configurations of deployed contracts`)
  .setAction(async ({}, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    const network = localBRE.network.name as eEthereumNetwork;
    const composerNft = await getComposedSoccerStarNft();
    const soccerStarNft = await getSoccerStarNft();
    const stakedNft = await getStakedSoccerStarNftV2();
    const bibNode = await getBIBNode();
    const tokenTracker = await getITokenDividendTracker(getTokenDividendTrackerPerNetwork(network));
    
    console.log(chalk.bgBlue('Check configurations...'));

    console.log(chalk.bgGray(`Checking ${SoccerStarNft}...`));
    let checked:boolean = false;

    checked = (await soccerStarNft.getMaxMintSupply()).toString() === MAX_NFT_QUOTA;
    verify("\tMAX_NFT_QUOTA", checked);

    checked = (await soccerStarNft.bibContract()).toString().toLocaleLowerCase() === getBIBTokenPerNetwork(network).toLocaleLowerCase();
    verify("\tBIB Token address", checked);

    checked = (await soccerStarNft.busdContract()).toString().toLocaleLowerCase() === getBUSDTokenPerNetwork(network).toLocaleLowerCase();
    verify("\tBUSD Token address", checked);

    checked = (await soccerStarNft.treasury()).toString().toLocaleLowerCase() === getTreasuryPerNetwork(network).toLocaleLowerCase();
    verify("\ttreasury address", checked);

    checked = (await soccerStarNft.router()).toString().toLocaleLowerCase() === getSwapRoterPerNetwork(network).toLocaleLowerCase();
    verify("\tuniswap router address", checked);

    checked = (await soccerStarNft.name()) === "SoccerStarNft";
    verify("\tNFT name", checked);
    
    checked = (await soccerStarNft.symbol()) === "SCSTAR";
    verify("\tNFT symbol", checked);
    
    checked = await soccerStarNft.allowProtocolToCallTb(composerNft.address);
    verify(`\tAllow ${StakedSoccerStarNftV2} to call`, checked);

    checked = await soccerStarNft.allowProtocolToCallTb(stakedNft.address);
    verify(`\tAllow ${ComposedSoccerStarNft} to call`, checked);

    checked = await soccerStarNft.allowProtocolToCallTb(bibNode.address);
    verify(`\tAllow ${BIBNode} to call`, checked);
    console.log(chalk.bgGray(`Check ${SoccerStarNft} done`));
    
  
   
    console.log(chalk.bgBlue('Check configurations ended'));
  });
