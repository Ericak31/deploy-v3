#!/usr/bin/env bash
set -euo pipefail

RPC_URL=${RPC_URL:-"https://rpc.hoodi.ethpandaops.io"}
PRIVATE_KEY=${PRIVATE_KEY:-"0x"}

forge build

# Deploy SSV: constructor(string n, string s, uint256 supply)
SSV_OUTPUT=$(forge create src/SSV.sol:SSV \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --constructor-args "SSV Token" "SSV" 1000000ether \
  --broadcast 2>&1 || true)

echo "$SSV_OUTPUT"
SSV_ADDR=$(echo "$SSV_OUTPUT" | grep -E "Deployed to: 0x[0-9a-fA-F]{40}" | tail -n1 | awk '{print $3}')

# Deploy USDC18: no constructor args
USDC_OUTPUT=$(forge create src/USDC.sol:USDC18 \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast 2>&1 || true)

echo "$USDC_OUTPUT"
USDC_ADDR=$(echo "$USDC_OUTPUT" | grep -E "Deployed to: 0x[0-9a-fA-F]{40}" | tail -n1 | awk '{print $3}')

if [ -n "${SSV_ADDR:-}" ]; then echo "$SSV_ADDR" > .last_deploy_ssv; fi
if [ -n "${USDC_ADDR:-}" ]; then echo "$USDC_ADDR" > .last_deploy_usdc; fi

echo "SSV address: ${SSV_ADDR:-<unknown>}"
echo "USDC address: ${USDC_ADDR:-<unknown>}"
