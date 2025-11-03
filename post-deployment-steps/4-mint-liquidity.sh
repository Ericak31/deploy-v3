#!/bin/bash
# Step 4: Mint a concentrated liquidity position (via NPM)

set -e

# Source environment if not already done
[ -z "$FACTORY" ] && source "$(dirname "$0")/0-setup-env.sh"
[ -f .env.local ] && source .env.local

echo "=== Step 4: Mint Liquidity Position ==="

# Ensure we have all required variables
if [ -z "$TICK_LOWER" ] || [ -z "$TICK_UPPER" ]; then
  echo "⚠️  Tick bounds not set. Using presets from 0-setup-env.sh (full-range)."
  source "$(dirname "$0")/0-setup-env.sh"
fi

if [ -z "$AMT0_DESIRED" ] || [ -z "$AMT1_DESIRED" ]; then
  echo "⚠️  Amounts not set. Running token approval first..."
  bash "$(dirname "$0")/3-approve-tokens.sh"
  source .env.local
fi

if [ -z "$POOL" ]; then
  echo "⚠️  Pool not set. Running step 1 first..."
  bash "$(dirname "$0")/1-create-pool.sh"
  source .env.local
fi

export ME=$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null || echo "0x4da9f34f83d608cAB03868662e93c96Bc9793495")
export DEADLINE=$(($(date +%s)+3600))

# Pre-flight checks
echo "Running pre-flight checks..."
echo ""

# Check pool is initialized
echo "1. Checking pool initialization..."
SLOT0=$(cast call $POOL "slot0()(uint160,int24,uint16,uint16,uint16,uint8,bool)" --rpc-url $RPC_URL 2>/dev/null || echo "")
if [ -z "$SLOT0" ] || echo "$SLOT0" | grep -q "0 0 0 0 0 0 false"; then
  echo "   ❌ Pool is not initialized. Please run step 2 (2-initialize-price.sh) first."
  exit 1
fi
echo "   ✅ Pool is initialized"

# Check token balances
echo "2. Checking token balances..."
BALANCE0=$(cast call $TOKEN0 "balanceOf(address)(uint256)" $ME --rpc-url $RPC_URL | tr -d ' \r\n' | sed 's/\[.*\]//')
BALANCE1=$(cast call $TOKEN1 "balanceOf(address)(uint256)" $ME --rpc-url $RPC_URL | tr -d ' \r\n' | sed 's/\[.*\]//')
echo "   TOKEN0 balance: $BALANCE0 (need: $AMT0_DESIRED)"
echo "   TOKEN1 balance: $BALANCE1 (need: $AMT1_DESIRED)"

# Simple heuristic check: just verify balances exist and are non-zero
# Full numeric comparison is complex with very large numbers, so we'll let the contract revert if insufficient
BALANCE0_CLEAN=$(echo "$BALANCE0" | grep -oE '[0-9]+' | head -1)
AMT0_CLEAN=$(echo "$AMT0_DESIRED" | grep -oE '[0-9]+' | head -1)
BALANCE1_CLEAN=$(echo "$BALANCE1" | grep -oE '[0-9]+' | head -1)
AMT1_CLEAN=$(echo "$AMT1_DESIRED" | grep -oE '[0-9]+' | head -1)

# Basic check: if balance is shorter than amount, it's definitely insufficient
if [ -n "$BALANCE0_CLEAN" ] && [ -n "$AMT0_CLEAN" ] && [ ${#BALANCE0_CLEAN} -lt ${#AMT0_CLEAN} ]; then
  echo "   ❌ Insufficient TOKEN0 balance (balance shorter than required)"
  exit 1
fi
if [ -n "$BALANCE1_CLEAN" ] && [ -n "$AMT1_CLEAN" ] && [ ${#BALANCE1_CLEAN} -lt ${#AMT1_CLEAN} ]; then
  echo "   ❌ Insufficient TOKEN1 balance (balance shorter than required)"
  exit 1
fi

# If lengths are equal, do basic string comparison (works for integers)
if [ ${#BALANCE0_CLEAN} -eq ${#AMT0_CLEAN} ] && [ "$BALANCE0_CLEAN" \< "$AMT0_CLEAN" ]; then
  echo "   ❌ Insufficient TOKEN0 balance"
  exit 1
fi
if [ ${#BALANCE1_CLEAN} -eq ${#AMT1_CLEAN} ] && [ "$BALANCE1_CLEAN" \< "$AMT1_CLEAN" ]; then
  echo "   ❌ Insufficient TOKEN1 balance"
  exit 1
fi

echo "   ✅ Balance check passed"

# Check approvals
echo "3. Checking token approvals..."
ALLOWANCE0=$(cast call $TOKEN0 "allowance(address,address)(uint256)" $ME $NPM --rpc-url $RPC_URL | tr -d ' \r\n' | sed 's/\[.*\]//')
ALLOWANCE1=$(cast call $TOKEN1 "allowance(address,address)(uint256)" $ME $NPM --rpc-url $RPC_URL | tr -d ' \r\n' | sed 's/\[.*\]//')
echo "   TOKEN0 allowance: $ALLOWANCE0 (need: $AMT0_DESIRED)"
echo "   TOKEN1 allowance: $ALLOWANCE1 (need: $AMT1_DESIRED)"

# Simple heuristic check for approvals (similar to balance check)
ALLOWANCE0_CLEAN=$(echo "$ALLOWANCE0" | grep -oE '[0-9]+' | head -1)
AMT0_CLEAN=$(echo "$AMT0_DESIRED" | grep -oE '[0-9]+' | head -1)
ALLOWANCE1_CLEAN=$(echo "$ALLOWANCE1" | grep -oE '[0-9]+' | head -1)
AMT1_CLEAN=$(echo "$AMT1_DESIRED" | grep -oE '[0-9]+' | head -1)

# Check if allowance is insufficient
if [ -n "$ALLOWANCE0_CLEAN" ] && [ -n "$AMT0_CLEAN" ]; then
  if [ ${#ALLOWANCE0_CLEAN} -lt ${#AMT0_CLEAN} ] || ([ ${#ALLOWANCE0_CLEAN} -eq ${#AMT0_CLEAN} ] && [ "$ALLOWANCE0_CLEAN" \< "$AMT0_CLEAN" ]); then
    echo "   ⚠️  Insufficient TOKEN0 allowance. Attempting to approve..."
    cast send $TOKEN0 "approve(address,uint256)" $NPM $AMT0_DESIRED \
      --rpc-url $RPC_URL --private-key $PRIVATE_KEY || echo "   ⚠️  Approval failed, but continuing..."
  fi
fi

if [ -n "$ALLOWANCE1_CLEAN" ] && [ -n "$AMT1_CLEAN" ]; then
  if [ ${#ALLOWANCE1_CLEAN} -lt ${#AMT1_CLEAN} ] || ([ ${#ALLOWANCE1_CLEAN} -eq ${#AMT1_CLEAN} ] && [ "$ALLOWANCE1_CLEAN" \< "$AMT1_CLEAN" ]); then
    echo "   ⚠️  Insufficient TOKEN1 allowance. Attempting to approve..."
    cast send $TOKEN1 "approve(address,uint256)" $NPM $AMT1_DESIRED \
      --rpc-url $RPC_URL --private-key $PRIVATE_KEY || echo "   ⚠️  Approval failed, but continuing..."
  fi
fi

echo "   ✅ Approvals checked"

echo ""
echo "Minting position with:"
echo "  TOKEN0: $TOKEN0"
echo "  TOKEN1: $TOKEN1"
echo "  Fee: $FEE"
echo "  Tick Lower: $TICK_LOWER"
echo "  Tick Upper: $TICK_UPPER"
echo "  Amount0 Desired: $AMT0_DESIRED"
echo "  Amount1 Desired: $AMT1_DESIRED"
echo "  Recipient: $ME"
echo "  Deadline: $DEADLINE"

echo ""
echo "Executing: cast send \$NPM \"mint(...)\""
cast send $NPM \
"mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))" \
"($TOKEN0,$TOKEN1,$FEE,$TICK_LOWER,$TICK_UPPER,$AMT0_DESIRED,$AMT1_DESIRED,$AMT0_MIN,$AMT1_MIN,$ME,$DEADLINE)" \
--rpc-url $RPC_URL --private-key $PRIVATE_KEY

echo ""
echo "Checking NFT balance..."
NFT_BALANCE=$(cast call $NPM "balanceOf(address)(uint256)" $ME --rpc-url $RPC_URL)
echo "NFTs owned: $NFT_BALANCE"

echo ""
echo "Checking pool liquidity..."
POOL_LIQUIDITY=$(cast call $POOL "liquidity()(uint128)" --rpc-url $RPC_URL)
echo "Total pool liquidity: $POOL_LIQUIDITY"

echo "✅ Step 4 complete!"

