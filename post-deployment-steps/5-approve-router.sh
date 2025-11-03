#!/bin/bash
# Step 5: Approve tokenIn to the Router

set -e

# Source environment if not already done
[ -z "$FACTORY" ] && source "$(dirname "$0")/0-setup-env.sh"
[ -f .env.local ] && source .env.local

# Default if not set
[ -z "$TOKEN_IN" ] && export TOKEN_IN=$TOKEN0
[ -z "$AMOUNT_IN" ] && export AMOUNT_IN=10000000000000000000  # 10 tokens (default)

echo "=== Step 5: Approve Router for Swap ==="
echo "Approving \$TOKEN_IN (token to swap) to router..."

echo "Executing: cast send \$TOKEN_IN \"approve(address,uint256)\" \$ROUTER \$AMOUNT_IN"
cast send $TOKEN_IN "approve(address,uint256)" $ROUTER $AMOUNT_IN \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

echo "✅ Step 5 complete!"
