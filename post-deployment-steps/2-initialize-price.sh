#!/bin/bash
# Step 2: Initialize pool price

set -e

# Source environment if not already done
[ -z "$FACTORY" ] && source "$(dirname "$0")/0-setup-env.sh"
[ -z "$POOL" ] && [ -f .env.local ] && source .env.local

echo "=== Step 2: Initialize Pool Price ==="
echo "Pool: $POOL"

# Calculate sqrtPriceX96 for initial price
# P = price = token1 per token0 (e.g., if 1 SSV = 100 USDC, then P=100)
# For simplicity, starting with 1:1 (P=1.0)
# You can adjust P in the Python script below to change the initial price

echo "Computing sqrtPriceX96 for initial price P=1.01 (1 TOKEN0 = 1.01 TOKEN1)..."
echo "Note: Using P=1.01 instead of 1.0 to avoid tick 0 edge case"
export INIT_PRICE=$(python3 << 'PY'
import math
P = 1.01  # Set your initial price: token1 per token0 (avoid tick 0)
sqrtPriceX96 = int(math.sqrt(P) * (1<<96))
print(hex(sqrtPriceX96))
PY
)

echo "Initial sqrtPriceX96: $INIT_PRICE"

# Initialize the pool (only once; will revert if already initialized)
echo ""
echo "Executing: cast send \$POOL \"initialize(uint160)\" \$INIT_PRICE"
cast send $POOL "initialize(uint160)" $INIT_PRICE \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY || {
  echo "⚠️  Initialize may have failed (pool might already be initialized). Continuing..."
}

# Verify initialization
echo ""
echo "Verifying initialization..."
cast call $POOL "slot0()(uint160,int24,uint16,uint16,uint16,uint8,bool)" --rpc-url $RPC_URL

echo "✅ Step 2 complete!"

