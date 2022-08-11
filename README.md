## Introduction

## Getting Started

Spin the npm version for compilling

```bash
npm -g -i npm@8.5.5
```

This is a hardhat project. To install required node.js modules

```bash
npm ci
```

To compile the solidity source code

```bash
npm run compile
```

To run test

```bash
npm run test
```

To deploy the smart contract on bsc testnet

```bash
npm run bsc-test:deployment
```


To deploy the smart contract on bsc mainnet
```bash
npm run bsc:deployment
```

To open console on testnet

```bash
npm run --network bsc-test console
```

To open console on mainnet
```bash
npm run --network bsc console
```

## Deployed Contract Address