## Compose Network Uniswap full deployment steps 

NOTE: This is setup to do one chain at a time, so it makes sense to do the whole flow for rollup A, confirm a swap works with the script, then continue to rollup B. 

1. Deploy Uniswap contracts

This deploy-v3 repo is the official v3 deployment repo from Uniswap, all we need to have ready is a WETH contract deployed, the private key ready, and the rpc. 

Deploy commands:

``` bash 
npm i 

node dist/index.js \
  --private-key 0x \
  --json-rpc https://0xrpc.io/hoodi \
  --weth9-address 0x14cd52D4FCe18CC4ffADb9E2356740c9507B0eC9 \
  --native-currency-label ETH \
  --owner-address 0x4da9f34f83d608cAB03868662e93c96Bc9793495
```

The contract addresses should be output to state.json if deployed correctly. Make a note of these as they are needed in the next step.

2. Perform post deployment steps

I've put the scripts for this in /post-deployment-steps/

Before running the run-all.sh script you must populate the 0-setup-env.sh with the correct variables.

These include:
- Private key and rpc
- uniswap addresses that we have just deployed
- The two tokens we wish to create the pool with 

**Run the steps sequentially:**
   - `1-create-pool.sh` - Creates the Uniswap V3 pool if it doesn't exist
   - `2-initialize-price.sh` - Initializes the pool with an initial price. Must be done once before adding liquidity.
   - `3-approve-tokens.sh` - Approves the NonfungiblePositionManager to spend tokens for minting liquidity.
   - `4-mint-liquidity.sh` - Mints a concentrated liquidity position (NFT)
   - `5-approve-router.sh` - Approve router for swap 
   - `6-execute-swap.sh` - Execute the swap

Or run all steps in sequence:
```bash
bash run-all.sh
```



## Use case

```
Flash loan 1000 USDC
Trade 1000 USDC <> 1 WETH 
Bridge 1 WETH to Rollup B 
Trade 1 WETH for 1010 USDC
Bridge 1010 USDC to Rollup B 
Pay back loan with 1000 USDC
Keep 10 USDC (-fees)
```

Rollup A: 
USDC <> WETH 

Rollup B: 
USDC <> WETH 