#!/bin/bash
# Run all steps in sequence

# Don't exit on error - let individual scripts handle errors
set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Running All Post-Deployment Steps ==="
echo ""

# Step 0: Setup environment
echo "📋 Step 0: Setting up environment..."
source "$SCRIPT_DIR/0-setup-env.sh"

# Step 1: Create pool
echo ""
echo "📋 Step 1: Creating pool..."
if ! bash "$SCRIPT_DIR/1-create-pool.sh"; then
  echo "❌ Step 1 failed!"
  exit 1
fi
source "$SCRIPT_DIR/.env.local" 2>/dev/null || true

# Step 2: Initialize price
echo ""
echo "📋 Step 2: Initializing pool price..."
if ! bash "$SCRIPT_DIR/2-initialize-price.sh"; then
  echo "❌ Step 2 failed!"
  exit 1
fi

# Step 3: Approve tokens
echo ""
echo "📋 Step 3: Approving tokens..."
if ! bash "$SCRIPT_DIR/3-approve-tokens.sh"; then
  echo "❌ Step 3 failed!"
  exit 1
fi
source "$SCRIPT_DIR/.env.local" 2>/dev/null || true

# Step 4: Mint liquidity
echo ""
echo "📋 Step 4: Minting liquidity position..."
if ! bash "$SCRIPT_DIR/4-mint-liquidity.sh"; then
  echo "❌ Step 4 failed!"
  exit 1
fi

# Step 5: Approve router
echo ""
echo "📋 Step 5: Approving router..."
if ! bash "$SCRIPT_DIR/5-approve-router.sh"; then
  echo "❌ Step 5 failed!"
  exit 1
fi

# Step 6: Execute swap
echo ""
echo "📋 Step 6: Executing swap..."
if ! bash "$SCRIPT_DIR/6-execute-swap.sh"; then
  echo "❌ Step 6 failed!"
  exit 1
fi

echo ""
echo "✅ All steps completed!"
echo ""
echo "Summary:"
echo "  Pool: $POOL"
echo "  TOKEN0 (SSV): $TOKEN0"
echo "  TOKEN1 (USDC): $TOKEN1"
echo "  Fee Tier: $FEE"

