# Post-Deployment Steps for Uniswap V3 Pool Setup

This directory contains scripts and commands to set up a Uniswap V3 pool with SSV and USDC tokens on Hoodi testnet.

## Quick Start

1. **Set up environment variables:**
   ```bash
   source 0-setup-env.sh
   ```

2. **Run the steps sequentially:**
   - `1-create-pool.sh` - Create the pool
   - `2-initialize-price.sh` - Initialize pool price
   - `3-approve-tokens.sh` - Approve tokens for NPM
   - `4-mint-liquidity.sh` - Mint liquidity position
   - `5-approve-router.sh` - Approve router for swap (required before step 6)
   - `6-execute-swap.sh` - Execute the swap

Or run all steps in sequence:
```bash
./run-all.sh
```

## Token Setup

- **TOKEN0 (SSV)**: 0x619b5EAD9A00795E1AB8Ef41E7f1B81c850Ab0C6
- **TOKEN1 (USDC)**: 0xFf32778D4d3d6E1Ac9A859eBACB360F5118F837C
- **Fee Tier**: 3000 (0.3%)

## Contract Addresses

All addresses are pre-configured from `hoodi-deployments.md`:
- Factory: 0xdc05CD9246d3aF18628E3303b6a579659e9B1F9b
- NonfungiblePositionManager: 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09
- SwapRouter02: 0x301906A8A6F393870390B50A0E2A8891B026e6Fc
- QuoterV2: 0x018FC7828A094375ae6C46B2E66d6bEEB9d2D7B5

## Manual Steps Guide

For a detailed walkthrough with explanations, see `STEPS.md`.

