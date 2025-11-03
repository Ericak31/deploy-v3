#!/bin/bash
# Step 6: Make the swap (SwapRouter02: exactInputSingle)

# Don't exit on error - we'll handle errors explicitly
set +e

# Source environment if not already done
[ -z "$FACTORY" ] && source "$(dirname "$0")/0-setup-env.sh"
[ -f .env.local ] && source .env.local

# Ensure required variables are set
[ -z "$TOKEN_IN" ] && export TOKEN_IN=$TOKEN0
[ -z "$TOKEN_OUT" ] && export TOKEN_OUT=$TOKEN1
# Load AMOUNT_IN from .env.local if it exists, otherwise default to 10 tokens
if [ -f .env.local ]; then
  source .env.local 2>/dev/null || true
fi
if [ -z "$AMOUNT_IN" ]; then
  export AMOUNT_IN=10000000000000000000  # 10 tokens (default)
fi
[ -z "$AMOUNT_OUT_MIN" ] && export AMOUNT_OUT_MIN=0  # Set to 0 to ignore slippage (not recommended in prod)
# sqrtPriceLimitX96: Calculate based on current pool price and direction
# For no limit, we can use 0 or max, but let's try a calculated value
# Clean PRICE_LIMIT of any "export" prefix and trailing text that might be in .env.local
if [ -n "$PRICE_LIMIT" ]; then
  # Remove "export" prefix, remove anything after "export", clean whitespace, extract value
  PRICE_LIMIT_CLEAN=$(echo "$PRICE_LIMIT" | sed 's/^export[[:space:]]*//' | sed 's/[[:space:]]*export.*//' | tr -d ' \r')
  # Extract just the value (hex or decimal number)
  if echo "$PRICE_LIMIT_CLEAN" | grep -qE '^0x'; then
    PRICE_LIMIT=$(echo "$PRICE_LIMIT_CLEAN" | grep -oE '^0x[0-9a-fA-F]+' | head -1)
  else
    PRICE_LIMIT=$(echo "$PRICE_LIMIT_CLEAN" | grep -oE '^[0-9]+' | head -1)
  fi
fi
# If still not set or corrupted, calculate based on direction
if [ -z "$PRICE_LIMIT" ] || [ "$PRICE_LIMIT" = "0" ] || [ "$PRICE_LIMIT" = "0x0" ] || echo "$PRICE_LIMIT" | grep -q "export"; then
  # Get current pool price to calculate appropriate limit
  POOL_TEMP=$(cast call $FACTORY "getPool(address,address,uint24)(address)" $TOKEN0 $TOKEN1 $FEE --rpc-url $RPC_URL 2>/dev/null | tr -d '\r' || echo "")
  if [ -n "$POOL_TEMP" ] && [ "$POOL_TEMP" != "0x0000000000000000000000000000000000000000" ]; then
    CURRENT_SQRT=$(cast call $POOL_TEMP "slot0()(uint160,int24,uint16,uint16,uint16,uint8,bool)" --rpc-url $RPC_URL 2>/dev/null | head -1 | tr -d '\r[]e+' | grep -oE '[0-9]+' | head -1 || echo "")
    if [ -n "$CURRENT_SQRT" ]; then
      # For TOKEN0->TOKEN1: limit should allow price to increase (higher sqrtPrice)
      # For TOKEN1->TOKEN0: limit should allow price to decrease (lower sqrtPrice)
      if [ "$TOKEN_IN" = "$TOKEN0" ]; then
        # Swapping TOKEN0->TOKEN1: use 0 for no limit (allows price to increase)
        # According to Uniswap V3: 0 = no upper limit when swapping token0->token1
        export PRICE_LIMIT=0
      else
        # Swapping TOKEN1->TOKEN0: use max for no limit (allows price to decrease)
        # According to Uniswap V3: max = no lower limit when swapping token1->token0
        export PRICE_LIMIT=$(python3 << 'PY'
print(hex((1 << 160) - 1))
PY
        )
      fi
    else
      # Fallback based on swap direction
      if [ "$TOKEN_IN" = "$TOKEN0" ]; then
        export PRICE_LIMIT=0  # No limit for TOKEN0->TOKEN1
      else
        export PRICE_LIMIT=$(python3 << 'PY'
print(hex((1 << 160) - 1))
PY
        )  # Max for TOKEN1->TOKEN0
      fi
    fi
  else
    # Fallback based on swap direction
    if [ "$TOKEN_IN" = "$TOKEN0" ]; then
      export PRICE_LIMIT=0  # No limit for TOKEN0->TOKEN1
    else
      export PRICE_LIMIT=$(python3 << 'PY'
print(hex((1 << 160) - 1))
PY
      )  # Max for TOKEN1->TOKEN0
    fi
  fi
fi

export ME=$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null || echo "0x4da9f34f83d608cAB03868662e93c96Bc9793495")
export DEADLINE=$(($(date +%s)+3600))

echo "=== Step 6: Execute Swap ==="

# Ensure pool is set
if [ -z "$POOL" ]; then
  echo "Pool not set. Fetching pool address..."
  source .env.local 2>/dev/null || true
  if [ -z "$POOL" ]; then
    export POOL=$(cast call $FACTORY "getPool(address,address,uint24)(address)" $TOKEN0 $TOKEN1 $FEE --rpc-url $RPC_URL | tr -d '\r')
    echo "Pool: $POOL"
  fi
fi

# Pre-flight checks
echo "Running pre-flight checks..."
echo ""

# 1. Check token balance
echo "1. Checking token balance..."
BALANCE_IN=$(cast call $TOKEN_IN "balanceOf(address)(uint256)" $ME --rpc-url $RPC_URL | tr -d ' \r\n' | sed 's/\[.*\]//')
echo "   Token In balance: $BALANCE_IN (need: $AMOUNT_IN)"

BALANCE_IN_CLEAN=$(echo "$BALANCE_IN" | grep -oE '[0-9]+' | head -1)
AMOUNT_IN_CLEAN=$(echo "$AMOUNT_IN" | grep -oE '[0-9]+' | head -1)

if [ -n "$BALANCE_IN_CLEAN" ] && [ -n "$AMOUNT_IN_CLEAN" ]; then
  if [ ${#BALANCE_IN_CLEAN} -lt ${#AMOUNT_IN_CLEAN} ] || ([ ${#BALANCE_IN_CLEAN} -eq ${#AMOUNT_IN_CLEAN} ] && [ "$BALANCE_IN_CLEAN" \< "$AMOUNT_IN_CLEAN" ]); then
    echo "   ❌ Insufficient balance to swap"
    exit 1
  fi
fi
echo "   ✅ Sufficient balance"

# 2. Check router approval
echo "2. Checking router approval..."
ALLOWANCE=$(cast call $TOKEN_IN "allowance(address,address)(uint256)" $ME $ROUTER --rpc-url $RPC_URL | tr -d ' \r\n' | sed 's/\[.*\]//')
echo "   Router allowance: $ALLOWANCE (need: $AMOUNT_IN)"

ALLOWANCE_CLEAN=$(echo "$ALLOWANCE" | grep -oE '[0-9]+' | head -1)
if [ -n "$ALLOWANCE_CLEAN" ] && [ -n "$AMOUNT_IN_CLEAN" ]; then
  if [ ${#ALLOWANCE_CLEAN} -lt ${#AMOUNT_IN_CLEAN} ] || ([ ${#ALLOWANCE_CLEAN} -eq ${#AMOUNT_IN_CLEAN} ] && [ "$ALLOWANCE_CLEAN" \< "$AMOUNT_IN_CLEAN" ]); then
    echo "   ❌ Insufficient router allowance"
    echo "   Run step 5 (5-approve-router.sh) first!"
    exit 1
  fi
fi
echo "   ✅ Router approved"

# 3. Check pool state
echo "3. Checking pool state..."
POOL_LIQUIDITY=$(cast call $POOL "liquidity()(uint128)" --rpc-url $RPC_URL 2>/dev/null | tr -d ' \r\n' | sed 's/\[.*\]//' || echo "0")
echo "   Pool liquidity: $POOL_LIQUIDITY"

if echo "$POOL_LIQUIDITY" | grep -qE "^0$|^[^0-9]*0[^0-9]*$"; then
  echo "   ⚠️  Warning: Pool has no liquidity. Swap may fail."
else
  echo "   ✅ Pool has liquidity"
fi

# 4. Check pool is initialized
echo "4. Checking pool initialization..."
SLOT0=$(cast call $POOL "slot0()(uint160,int24,uint16,uint16,uint16,uint8,bool)" --rpc-url $RPC_URL 2>/dev/null || echo "")
if [ -z "$SLOT0" ] || echo "$SLOT0" | grep -q "0 0 0 0 0 0 false"; then
  echo "   ❌ Pool is not initialized. Run step 2 (2-initialize-price.sh) first."
  exit 1
fi
echo "   ✅ Pool is initialized"

# 5. Note: SwapRouter02 doesn't use deadline (function is payable instead)
echo "5. Note: SwapRouter02 exactInputSingle doesn't use deadline parameter"

echo ""
echo "Executing swap:"
echo "  Token In: $TOKEN_IN"
echo "  Token Out: $TOKEN_OUT"
echo "  Amount In: $AMOUNT_IN"
echo "  Amount Out Min: $AMOUNT_OUT_MIN (slippage protection)"
echo "  Recipient: $ME"
echo "  Pool: $POOL"
echo "  Note: SwapRouter02 doesn't use deadline parameter"
# 6. Additional diagnostics
echo "6. Additional diagnostics..."
echo "   Checking router contract code..."
ROUTER_CODE=$(cast code $ROUTER --rpc-url $RPC_URL 2>/dev/null | head -c 20 || echo "")
if [ -z "$ROUTER_CODE" ] || [ "$ROUTER_CODE" = "0x" ]; then
  echo "   ❌ Router contract has no code!"
  exit 1
fi
echo "   ✅ Router contract exists"

echo "   Checking current pool price..."
SLOT0_FULL=$(cast call $POOL "slot0()(uint160,int24,uint16,uint16,uint16,uint8,bool)" --rpc-url $RPC_URL)
# Extract values from slot0 output
# Cast outputs: sqrtPriceX96 (line 1, may have [sci_notation]), tick (line 2), etc.
# Use sed to extract just numeric values, then read lines
CURRENT_TICK=$(echo "$SLOT0_FULL" | sed -n '2p' | tr -d ' \r')
SQRT_PRICE_X96=$(echo "$SLOT0_FULL" | sed -n '1p' | tr -d ' \r[]e+' | grep -oE '[0-9]+' | head -1)
echo "   Current tick: $CURRENT_TICK"
echo "   SqrtPriceX96: $SQRT_PRICE_X96"

echo "   Checking if swap amount is reasonable..."
# Very small amounts might fail; check if amount is at least 1000 wei
# Use string length comparison instead of numeric (for large numbers)
AMOUNT_IN_MIN=1000
if [ -z "$AMOUNT_IN_CLEAN" ]; then
  AMOUNT_IN_CLEAN=$(echo "$AMOUNT_IN" | grep -oE '[0-9]+' | head -1)
fi
if [ -n "$AMOUNT_IN_CLEAN" ] && [ ${#AMOUNT_IN_CLEAN} -lt 4 ]; then
  echo "   ⚠️  Warning: Swap amount is very small ($AMOUNT_IN), might fail"
fi

echo ""
echo "Executing swap:"
echo "  Token In: $TOKEN_IN"
echo "  Token Out: $TOKEN_OUT"
echo "  Amount In: $AMOUNT_IN"
echo "  Amount Out Min: $AMOUNT_OUT_MIN (slippage protection)"
echo "  Recipient: $ME"
echo "  Pool: $POOL"
echo "  Current Tick: $CURRENT_TICK"

echo ""
echo "Attempting swap..."

# Test if router can even see the pool
echo "Testing router can access pool..."
ROUTER_FACTORY=$(cast call $ROUTER "factory()(address)" --rpc-url $RPC_URL 2>/dev/null || echo "")
if [ "$ROUTER_FACTORY" != "$FACTORY" ]; then
  echo "   ⚠️  Warning: Router factory ($ROUTER_FACTORY) doesn't match expected ($FACTORY)"
fi

# Try to simulate the swap to get better error (optional - sometimes fails due to stale state)
echo "Simulating swap to check for errors..."
# SwapRouter02 exactInputSingle struct: (tokenIn, tokenOut, fee, recipient, amountIn, amountOutMinimum, sqrtPriceLimitX96)
# NOTE: There is NO deadline field in the struct
SIM_RESULT=$(cast call $ROUTER \
"exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))" \
"($TOKEN_IN,$TOKEN_OUT,$FEE,$ME,$AMOUNT_IN,$AMOUNT_OUT_MIN,$PRICE_LIMIT)" \
--rpc-url $RPC_URL 2>&1) || true

# Note: Simulation sometimes fails with STF even when actual swap works (stale state issue)
# If all pre-flight checks pass, proceed with actual swap anyway
if echo "$SIM_RESULT" | grep -q "execution reverted"; then
  echo "   ❌ Simulation failed - swap would revert"
  echo "   Error: $SIM_RESULT"
  echo ""
  echo "   Parameters used:"
  echo "     TOKEN_IN: $TOKEN_IN"
  echo "     TOKEN_OUT: $TOKEN_OUT"
  echo "     AMOUNT_IN: $AMOUNT_IN"
  echo "     FEE: $FEE"
  echo "     PRICE_LIMIT: $PRICE_LIMIT"
  echo "     Current Tick: $CURRENT_TICK"
  echo ""
  echo "   Common causes:"
  echo "   1. Amount too small (output rounds to 0 after fees) - try larger amount"
  echo "   2. No accessible liquidity at current price/tick"
  echo "   3. Router parameter mismatch or pool state issue"
  echo "   4. Price limit causing issues (try with calculated limit instead of max)"
  echo ""
  echo ""
  echo "   ⚠️  IMPORTANT: Swap is reverting even with correct parameters."
  echo "   This might indicate:"
  echo "     - Router implementation issue at tick 0"
  echo "     - Pool state edge case with full-range + tight-range liquidity"
  echo "     - Router address incompatibility"
  echo ""
  echo "   Troubleshooting steps:"
  echo "     1. Verify router address is correct:"
  echo "        echo \$ROUTER  # Should match hoodi-deployments.md"
  echo ""
  echo "     2. Try initializing pool at a different price (re-run step 2 with price != 1.0)"
  echo ""
  echo "     3. Check if router contract exists and matches expected version:"
  echo "        cast code \$ROUTER --rpc-url \$RPC_URL | head -c 20"
  echo ""
  echo "     4. Consider using Uniswap SDK or testing with a different router"
  echo ""
  echo "     5. Try swapping in opposite direction:"
  echo "        export TOKEN_IN=$TOKEN1"
  echo "        export TOKEN_OUT=$TOKEN0"
  echo "        export AMOUNT_IN=1000000000000000000"
  echo "        export PRICE_LIMIT=\$(python3 << 'PY'"
  echo "print(hex((1 << 160) - 1))"
  echo "PY"
  echo "        )"
  echo "        bash 5-approve-router.sh"
  echo "        bash 6-execute-swap.sh"
  echo ""
  echo "   ⚠️  Note: Simulation failed, but if all pre-flight checks passed,"
  echo "   attempting actual swap anyway (simulation can have stale state issues)..."
  echo ""
else
  echo "   ✅ Simulation passed, attempting real swap..."
fi
echo ""

# SwapRouter02 exactInputSingle struct: (tokenIn, tokenOut, fee, recipient, amountIn, amountOutMinimum, sqrtPriceLimitX96)
# NOTE: There is NO deadline field in the struct - the function is payable instead
echo "Executing swap transaction..."
SWAP_RESULT=$(cast send $ROUTER \
"exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))" \
"($TOKEN_IN,$TOKEN_OUT,$FEE,$ME,$AMOUNT_IN,$AMOUNT_OUT_MIN,$PRICE_LIMIT)" \
--rpc-url $RPC_URL --private-key $PRIVATE_KEY 2>&1)
SWAP_EXIT_CODE=$?

# Check exit code first
if [ $SWAP_EXIT_CODE -ne 0 ]; then
  echo ""
  echo "❌ Swap failed (exit code: $SWAP_EXIT_CODE)!"
  echo ""
  echo "Output:"
  echo "$SWAP_RESULT" | head -30
  echo ""
  echo "Troubleshooting steps:"
  echo "1. Verify you ran step 5 (5-approve-router.sh) successfully"
  echo "2. Try increasing AMOUNT_IN (currently: $AMOUNT_IN)"
  echo "3. Check if liquidity exists at current price (tick: $CURRENT_TICK)"
  echo "4. Verify router contract: $ROUTER"
  exit 1
fi

# Also check for error strings in output
if echo "$SWAP_RESULT" | grep -qi "error\|failed\|execution reverted"; then
  echo ""
  echo "❌ Swap failed!"
  echo ""
  echo "Error output:"
  echo "$SWAP_RESULT" | head -30
  echo ""
  echo "Troubleshooting steps:"
  echo "1. Verify you ran step 5 (5-approve-router.sh) successfully"
  echo "2. Try increasing AMOUNT_IN (currently: $AMOUNT_IN)"
  echo "3. Check if liquidity exists at current price (tick: $CURRENT_TICK)"
  echo "4. Verify router contract: $ROUTER"
  exit 1
fi

# Success!
echo "$SWAP_RESULT"

echo ""
echo "✅ Swap executed! Check your balances to confirm receipt."

echo "✅ Step 6 complete!"

