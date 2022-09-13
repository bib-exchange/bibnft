## Introduction

## Getting Started

Pin the npm version for compilling

```bash
npm -g -i npm@8.5.5
```

## Setup env
Create `.env` to include deployer && api kess
```bash
mv .env.example .env
```

Setup MNEMONIC && ETHERSCAN_KEY
wherein, MNEMONIC is configured for deployer key (`in mnemonic`), ETHERSCAN_KEY configured for bsc-scan api key
   
## Some usfull Commands
1. To install required node.js modules
```bash
npm ci:clean
```

2. To compile the solidity source code
```bash
npm run compile
```

3. To run test
```bash
npm run test
```

4. To deploy the smart contract on bsc testnet
```bash
npm run bsc-test:deployment
```


5. To deploy the smart contract on bsc mainnet
```bash
npm run bsc:deployment
```

6. To open console on testnet
```bash
npm run --network bsc-test console
```

7. To open console on mainnet
```bash
npm run --network bsc console
```
8. To deploy the single nft contract
```bash
npm run bsc:deploy-nft
```

## Deployed Contract Address
TBD