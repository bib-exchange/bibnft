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
  getITokenDividendTracker,
  getSoccerStarNftMarket,
  getFeeCollector,
  getStakedDividendTracker,
  getBIBNodeImpl,
  getBIBStaking,
  getBIBDividend,
  getIFreezeToken
} from '../../helpers/contracts-helpers';
import { waitForTx , DRE} from '../../helpers/misc-utils';
import { ZERO_ADDRESS,
  MAX_NFT_QUOTA,
  getBIBTokenPerNetwork,
  getBUSDTokenPerNetwork,
  getSwapRoterPerNetwork,
  getTreasuryPerNetwork,
  getBIBAdminPerNetwork,
  getTokenDividendTrackerPerNetwork,
  getRevealWalletPerNetwork,
  DISTRIBUTION_END,
  getRewardVaultPerNetwork,
  EMISSION_PER_SECONDS,
 } from '../../helpers/constants';
import { BibStaking, StakedDividendTracker } from '../../types';

const {
    SoccerStarNft,
    ComposedSoccerStarNft,
    StakedSoccerStarNftV2,
    BIBNode,
    BIBStaking,
    BIBDividend,
    SoccerStarNftMarket,
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
    const revealWallet = await getRevealWalletPerNetwork(network);
    const composerNft = await getComposedSoccerStarNft();
    const soccerStarNft = await getSoccerStarNft();
    const stakedNft = await getStakedSoccerStarNftV2();
    const stakedDividendTracker = await getStakedDividendTracker();
    const bibNode = await getBIBNode();
    const bibStaked = await getBIBStaking();
    const bibDividend = await getBIBDividend();
    const feeCollector = await getFeeCollector();
    const soccerStarNftMarket = await getSoccerStarNftMarket();
    const tokenTracker = await getITokenDividendTracker(getTokenDividendTrackerPerNetwork(network));
    let checked:boolean = false;
    
    console.log(chalk.bgBlue('Check configurations...'));

    console.log(chalk.bgGray(`Checking ${SoccerStarNft}...`));

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

    checked = await soccerStarNft.allowToCallTb(revealWallet);
    verify(`\tAllow reveal wallet to call`, checked);
    
    checked = await soccerStarNft.allowProtocolToCallTb(composerNft.address);
    verify(`\tAllow ${StakedSoccerStarNftV2} to call`, checked);

    checked = await soccerStarNft.allowProtocolToCallTb(stakedNft.address);
    verify(`\tAllow ${ComposedSoccerStarNft} to call`, checked);

    checked = await soccerStarNft.allowProtocolToCallTb(bibNode.address);
    verify(`\tAllow ${BIBNode} to call`, checked);
    
    checked = await tokenTracker.excludedFromDividends(soccerStarNft.address);
    verify(`\tExclude ${SoccerStarNft} from bib dividend`, checked);
    console.log(chalk.bgGray(`Check ${SoccerStarNft} done`));
   
    console.log(chalk.bgGray(`Checking ${ComposedSoccerStarNft}...`));
    checked = (await composerNft.bibContract()).toString().toLocaleLowerCase() === getBIBTokenPerNetwork(network).toLocaleLowerCase();
    verify("\tBIB Token address", checked);

    checked = (await composerNft.busdContract()).toString().toLocaleLowerCase() === getBUSDTokenPerNetwork(network).toLocaleLowerCase();
    verify("\tBUSD Token address", checked);

    checked = (await composerNft.treasury()).toString().toLocaleLowerCase() === getTreasuryPerNetwork(network).toLocaleLowerCase();
    verify("\ttreasury address", checked);

    checked = (await composerNft.router()).toString().toLocaleLowerCase() === getSwapRoterPerNetwork(network).toLocaleLowerCase();
    verify("\tuniswap router address", checked);

    checked = await tokenTracker.excludedFromDividends(composerNft.address);
    verify(`\tExclude ${ComposedSoccerStarNft} from bib dividend`, checked);
    console.log(chalk.bgGray(`Check ${ComposedSoccerStarNft} done`));

    console.log(chalk.bgGray(`Checking ${SoccerStarNftMarket}...`));
    checked = (await soccerStarNftMarket.tokenContract()).toString().toLocaleLowerCase() === soccerStarNft.address.toLocaleLowerCase();
    verify("\tNFT address", checked);

    checked = (await soccerStarNftMarket.bibContract()).toString().toLocaleLowerCase() === getBIBTokenPerNetwork(network).toLocaleLowerCase();
    verify("\tBIB Token address", checked);

    checked = (await soccerStarNftMarket.busdContract()).toString().toLocaleLowerCase() === getBUSDTokenPerNetwork(network).toLocaleLowerCase();
    verify("\tBUSD Token address", checked);

    checked = (await soccerStarNftMarket.treasury()).toString().toLocaleLowerCase() === getTreasuryPerNetwork(network).toLocaleLowerCase();
    verify("\ttreasury address", checked);

    checked = (await soccerStarNftMarket.feeCollector()).toString().toLocaleLowerCase() === feeCollector.address.toLocaleLowerCase();
    verify("\tfeeCollector address", checked);

    checked = await tokenTracker.excludedFromDividends(soccerStarNftMarket.address);
    verify(`\tExclude ${SoccerStarNftMarket} from bib dividend`, checked);
    console.log(chalk.bgGray(`Check ${SoccerStarNftMarket} done`));

    console.log(chalk.bgGray(`Checking ${StakedSoccerStarNftV2}...`));

    checked = (await stakedNft.NODE()).toString().toLocaleLowerCase() === bibNode.address.toLocaleLowerCase();
    verify("\tbib node address", checked);

    checked = (await stakedNft.STAKED_TOKEN()).toString().toLocaleLowerCase() === soccerStarNft.address.toLocaleLowerCase();
    verify("\tstaked token address", checked);

    checked = (await stakedNft.REWARD_TOKEN()).toString().toLocaleLowerCase() === getBIBTokenPerNetwork(network).toLocaleLowerCase();
    verify("\treward wallet address", checked);

    const distribute_config = await stakedNft.assets(stakedNft.address);
    checked = (distribute_config.emissionPerSecond.toString() === EMISSION_PER_SECONDS);
    verify("\temission configuration", checked);

    checked = (await stakedNft.allowProtocolToCallTb(bibNode.address));
    verify("\tallow bib node to call", checked);

    checked = (await stakedNft.balanceHook()).toLocaleLowerCase() === 
    stakedDividendTracker.address.toLocaleLowerCase();
    verify("\tbalance hook", checked);

    checked = await tokenTracker.excludedFromDividends(stakedNft.address);
    verify(`\tExclude ${StakedSoccerStarNftV2} from bib dividend`, checked);

    console.log(chalk.bgGray(`Check ${BIBNode} done`));
    checked = (await bibNode.cardNFTStake()).toLocaleLowerCase() === stakedNft.address.toLocaleLowerCase();
    verify("\tnft staked token address", checked);

    checked = (await bibNode.soccerStarNft()).toLocaleLowerCase() === soccerStarNft.address.toLocaleLowerCase();
    verify("\tnft token address", checked);

    checked = (await bibNode.BIBToken()).toLocaleLowerCase() === getBIBTokenPerNetwork(network).toLocaleLowerCase();
    verify("\tbib token address", checked);

    checked = (await bibNode.BIBStaking()).toLocaleLowerCase() === bibStaked.address.toLocaleLowerCase();
    verify("\tbib staked address", checked);

    checked = (await bibNode.soccerStartNftMarket()).toLocaleLowerCase() === soccerStarNftMarket.address.toLocaleLowerCase();
    verify("\tnft market address", checked);

    checked = await tokenTracker.excludedFromDividends(bibNode.address);
    verify(`\tExclude ${BIBNode} from bib dividend`, checked);

    console.log(chalk.bgGray(`Checking ${BIBNode} done`));

    console.log(chalk.bgGray(`Check ${BIBStaking}...`));
    checked = (await bibStaked.BIBToken()).toLocaleLowerCase() === getBIBTokenPerNetwork(network).toLocaleLowerCase();
    verify("\tbib token address", checked);

    checked = (await bibStaked.BIBNode()).toLocaleLowerCase() === bibNode.address.toLocaleLowerCase();
    verify("\tbib token address", checked);

    checked = (await bibStaked.BIBDividend()).toLocaleLowerCase() === bibDividend.address.toLocaleLowerCase();
    verify("\tbib token address", checked);

    checked = (await bibStaked.soccerStarNft()).toLocaleLowerCase() === soccerStarNft.address.toLocaleLowerCase();
    verify("\tnft token address", checked);

    checked = await tokenTracker.excludedFromDividends(bibStaked.address);
    verify(`\tExclude ${BIBStaking} from bib dividend`, checked);
    console.log(chalk.bgGray(`Check ${BIBStaking} done`));

    console.log(chalk.bgGray(`Checking ${BIBDividend}...`));
    checked = await tokenTracker.excludedFromDividends(bibDividend.address);
    verify(`\tExclude ${BIBStaking} from bib dividend`, checked);
    console.log(chalk.bgGray(`Check ${BIBDividend} done`));

    console.log(chalk.bgBlue('Check configurations ended'));
  });
