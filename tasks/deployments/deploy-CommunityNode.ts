import { task } from 'hardhat/config';
import { eContractid } from '../../helpers/types';
import {
  deployBIBDividend,
  deployBIBNode,
  deployBIBStaking,
  registerContractInJsonDb,
  deployInitializableAdminUpgradeabilityProxy
} from '../../helpers/contracts-helpers';

const { 
  BIBNode, 
  BIBNodeImpl,
  BIBStaking, 
  BIBStakingImpl,
  BIBDividend,
  BIBDividendImpl
} = eContractid;

task(`deploy-CommunityNode`, `Deploy the community nodes`)
  .addFlag('verify', 'Proceed with the Etherscan verification')
  .setAction(async ({ verify }, localBRE) => {
    await localBRE.run('set-dre');

    if (!localBRE.network.config.chainId) {
      throw new Error('INVALID_CHAIN_ID');
    }
    // 1 node
    console.log(`\tDeploying ${BIBNode} implementation ...`);
    const bibNodeImpl = await deployBIBNode(verify);
    await registerContractInJsonDb(BIBNodeImpl, bibNodeImpl);

    console.log(`\tDeploying ${BIBNode} Transparent Proxy ...`);
    const bibNodeProxy = await deployInitializableAdminUpgradeabilityProxy(verify);
    await registerContractInJsonDb(BIBNode, bibNodeProxy);
    console.log(`\tFinished ${BIBNode} proxy and implementation deployment`);

    // 2 dividend
    console.log(`\tDeploying ${BIBDividend} implementation ...`);
    const bibDividendImpl = await deployBIBDividend(verify);
    await registerContractInJsonDb(BIBDividendImpl, bibDividendImpl);

    console.log(`\tDeploying ${BIBDividend} Transparent Proxy ...`);
    const bibDividendProxy = await deployInitializableAdminUpgradeabilityProxy(verify);
    await registerContractInJsonDb(BIBDividend, bibDividendProxy);
    console.log(`\tFinished ${BIBDividend} proxy and implementation deployment`);

    // 3 staken
    console.log(`\tDeploying ${BIBStaking} implementation ...`);
    const bibStakingImpl = await deployBIBStaking(verify);
    await registerContractInJsonDb(BIBStakingImpl, bibStakingImpl);

    console.log(`\tDeploying ${BIBStaking} Transparent Proxy ...`);
    const bibStakingProxy = await deployInitializableAdminUpgradeabilityProxy(verify);
    await registerContractInJsonDb(BIBStaking, bibStakingProxy);
    console.log(`\tFinished ${BIBStaking} proxy and implementation deployment`);
  });
