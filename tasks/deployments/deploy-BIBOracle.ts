import { task } from 'hardhat/config';
import { eContractid } from '../../helpers/types';
import {
  deploySoccerStarNft,
  registerContractInJsonDb,
} from '../../helpers/contracts-helpers';
import { InitializableAdminUpgradeabilityProxy } from '../../types/InitializableAdminUpgradeabilityProxy';

const { BibOracle } = eContractid;

task(`deploy-${BibOracle}`, `Deploy the ${BibOracle} contract`)
  .addFlag('verify', 'Proceed with the Etherscan verification')
  .setAction(async ({ verify }, localBRE) => {


  });