#!/usr/bin/env bash
set -euo pipefail

# Config
RPC_URL=${RPC_URL:-"https://0xrpc.io/hoodi"}
PRIVATE_KEY=${PRIVATE_KEY:-"0x"}

# Compile & deploy
forge --version >/dev/null 2>&1 || { echo "forge not found. Install foundry first (see setup.sh)"; exit 1; }

forge build

# Use forge create to deploy and capture the deployed address from output
OUTPUT=$(forge create src/WETH9.sol:WETH9 \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast 2>&1 || true)

echo "$OUTPUT"

ADDR=$(echo "$OUTPUT" | grep -E "Deployed to: 0x[0-9a-fA-F]{40}" | awk '{print $3}')
if [ -n "${ADDR:-}" ]; then
  echo "Contract address: $ADDR"
  echo "$ADDR" > .last_deploy_address
  exit 0
fi

# Fallback: compute deterministic address if broadcast failed (e.g., insufficient funds)
EOA=$(cast wallet address --private-key "$PRIVATE_KEY")
NONCE=$(cast nonce "$EOA" --rpc-url "$RPC_URL")
PREDICTED=$(cast compute-address "$EOA" "$NONCE")
echo "Predicted contract address (on next successful nonce): $PREDICTED"
echo "$PREDICTED" > .predicted_address
