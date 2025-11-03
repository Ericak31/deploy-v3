#!/bin/bash
# Step 3: Approve tokens to NonfungiblePositionManager (for minting liquidity)

set -e

# Source environment if not already done
[ -z "$FACTORY" ] && source "$(dirname "$0")/0-setup-env.sh"

echo "=== Step 3: Approve Tokens for NPM ==="

# Amounts you want to deposit (raw units)
# Adjust these based on your token decimals:
# - SSV (TOKEN0): 18 decimals - e.g., 100000 tokens = 100000000000000000000000
# - USDC (TOKEN1): 18 decimals - e.g., 100000 tokens = 100000000000000000000000

export AMT0_DESIRED=100000000000000000000000     # 100000 SSV (18 decimals)
export AMT1_DESIRED=100000000000000000000000     # 100000 USDC (18 decimals)

# Safety minimums (slippage on mint)
export AMT0_MIN=0
export AMT1_MIN=0

echo "Approving TOKEN0 (SSV)..."
echo "Executing: cast send \$TOKEN0 \"approve(address,uint256)\" \$NPM \$AMT0_DESIRED"
cast send $TOKEN0 "approve(address,uint256)" $NPM $AMT0_DESIRED \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

echo ""
echo "Approving TOKEN1 (USDC)..."
echo "Executing: cast send \$TOKEN1 \"approve(address,uint256)\" \$NPM \$AMT1_DESIRED"
cast send $TOKEN1 "approve(address,uint256)" $NPM $AMT1_DESIRED \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Save for later steps
echo "export AMT0_DESIRED=$AMT0_DESIRED" >> .env.local
echo "export AMT1_DESIRED=$AMT1_DESIRED" >> .env.local
echo "export AMT0_MIN=$AMT0_MIN" >> .env.local
echo "export AMT1_MIN=$AMT1_MIN" >> .env.local

echo "✅ Step 3 complete!"

