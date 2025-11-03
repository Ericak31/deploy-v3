#!/bin/bash
# Environment setup - Source this file before running other scripts

# --- REQUIRED ENV ---
export RPC_URL="https://rpc.hoodi.ethpandaops.io"
export PRIVATE_KEY="0x"

# --- CORE CONTRACTS ---
export FACTORY=0xdc05CD9246d3aF18628E3303b6a579659e9B1F9b
export NPM=0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09
export ROUTER=0x301906A8A6F393870390B50A0E2A8891B026e6Fc
export QUOTER=0x018FC7828A094375ae6C46B2E66d6bEEB9d2D7B5
export TICKLENS=0x53DEFba66202C8A3c92da19228c0e00A2C689401

# --- TOKENS & FEES ---
# TOKEN0 must be < TOKEN1 by address (Uniswap V3 requirement)
export TOKEN0=0x619b5EAD9A00795E1AB8Ef41E7f1B81c850Ab0C6  # SSV (lower address)
export TOKEN1=0xFf32778D4d3d6E1Ac9A859eBACB360F5118F837C  # USDC (higher address)
export FEE=500  # 0.05% fee tier

# --- PRESET FULL-RANGE TICKS (for FEE=500; tickSpacing=10) ---
# Use full-range for testing to avoid computing bounds
export TICK_LOWER=-887270
export TICK_UPPER=887270

# --- DEPLOYER ADDRESS ---
export ME=$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null || echo "0x4da9f34f83d608cAB03868662e93c96Bc9793495")

# --- DEADLINE (1 hour from now) ---
export DEADLINE=$(($(date +%s)+3600))

echo "Environment variables set!"
echo "RPC_URL: $RPC_URL"
echo "Deployer: $ME"
echo "TOKEN0 (SSV): $TOKEN0"
echo "TOKEN1 (USDC): $TOKEN1"
echo "Fee Tier: $FEE"
echo "Ticks: [$TICK_LOWER, $TICK_UPPER] (full-range)"

