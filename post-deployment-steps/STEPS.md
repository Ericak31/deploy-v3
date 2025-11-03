# Detailed Step-by-Step Guide

This guide walks through each step with explanations and commands you can copy-paste.

## Prerequisites

1. Foundry (cast) installed and in PATH
2. Environment variables set (run `source 0-setup-env.sh`)
3. Tokens (SSV and USDC) deployed on Hoodi
4. Sufficient balance for gas fees

## Step 0: Environment Setup

**File:** `0-setup-env.sh`

Sets all required environment variables:
- RPC endpoint
- Private key
- Contract addresses (Factory, NPM, Router, Quoter)
- Token addresses (SSV and USDC)
- Fee tier (3000 = 0.3%)
- Full‑range ticks for testing (`TICK_LOWER=-887220`, `TICK_UPPER=887220`)

**Run:**
```bash
source 0-setup-env.sh
```

## Step 1: Create Pool

**File:** `1-create-pool.sh`

Creates the Uniswap V3 pool if it doesn't exist.

**Commands:**
```bash
# Create the pool
cast send $FACTORY "createPool(address,address,uint24)" $TOKEN0 $TOKEN1 $FEE \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Fetch pool address
export POOL=$(cast call $FACTORY "getPool(address,address,uint24)(address)" $TOKEN0 $TOKEN1 $FEE --rpc-url $RPC_URL | tr -d '\r')
echo "POOL=$POOL"
```

**Expected Output:**
- Transaction hash
- Pool address

## Step 2: Initialize Price

**File:** `2-initialize-price.sh`

Initializes the pool with an initial price. Must be done once before adding liquidity.

**Initial Price Calculation:**
```python
import math
P = 1.0  # price = token1 per token0 (1 SSV = 1 USDC)
sqrtPriceX96 = int(math.sqrt(P) * (1<<96))
print(hex(sqrtPriceX96))
```

**Commands:**
```bash
# Compute sqrtPriceX96 (example for P=1.0)
export INIT_PRICE=$(python3 << 'PY'
import math
P = 1.0
sqrtPriceX96 = int(math.sqrt(P) * (1<<96))
print(hex(sqrtPriceX96))
PY
)

# Initialize pool
cast send $POOL "initialize(uint160)" $INIT_PRICE \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Verify initialization
cast call $POOL "slot0()(uint160,int24,uint16,uint16,uint16,uint8,bool)" --rpc-url $RPC_URL
```

**Note:** If the pool is already initialized, this step will revert. That's okay - skip to Step 3.

## (Removed) Inspect Pool Parameters

This step was removed because full‑range ticks are preset in `0-setup-env.sh`. If you need custom tick bounds, compute them manually or reintroduce an inspect step.

## Step 3: Approve Tokens

**File:** `3-approve-tokens.sh`

Approves the NonfungiblePositionManager to spend tokens for minting liquidity.

**Commands:**
```bash
# Set desired amounts (adjust based on token decimals)
export AMT0_DESIRED=100000000000000000000000     # 100000 SSV (18 decimals)
export AMT1_DESIRED=100000000000000000000000     # 100000 USDC (18 decimals)

# Approve TOKEN0
cast send $TOKEN0 "approve(address,uint256)" $NPM $AMT0_DESIRED \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Approve TOKEN1
cast send $TOKEN1 "approve(address,uint256)" $NPM $AMT1_DESIRED \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

**Token Decimals:**
- Both SSV and USDC have 18 decimals in this deployment
- Adjust amounts based on your token's decimal places

## Step 4: Mint Liquidity Position

**File:** `4-mint-liquidity.sh`

Mints a concentrated liquidity position (NFT).

**Commands:**
```bash
export ME=$(cast wallet address --private-key $PRIVATE_KEY)
export DEADLINE=$(($(date +%s)+3600))  # 1 hour from now

cast send $NPM \
"mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))" \
"($TOKEN0,$TOKEN1,$FEE,$TICK_LOWER,$TICK_UPPER,$AMT0_DESIRED,$AMT1_DESIRED,$AMT0_MIN,$AMT1_MIN,$ME,$DEADLINE)" \
--rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Check NFT balance
cast call $NPM "balanceOf(address)(uint256)" $ME --rpc-url $RPC_URL

# Check pool liquidity
cast call $POOL "liquidity()(uint128)" --rpc-url $RPC_URL
```

**After Success:**
- You'll receive an NFT representing your liquidity position
- Pool will have active liquidity in your tick range

## Step 5: Approve Router

**File:** `5-approve-router.sh`

**Required before Step 6!** Approves the SwapRouter02 to spend tokens for swapping.

**Commands:**
```bash
# Set swap parameters (if not already set)
export TOKEN_IN=$TOKEN0  # Token you want to swap (SSV)
export TOKEN_OUT=$TOKEN1  # Token you want to receive (USDC)
export AMOUNT_IN=1000000000000000   # Amount to swap (0.001 tokens)

# Approve router
cast send $TOKEN_IN "approve(address,uint256)" $ROUTER $AMOUNT_IN \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

**Note:** This step is **required** before executing the swap in Step 6.

## Step 6: Execute Swap

**File:** `6-execute-swap.sh`

Executes the actual swap.

**Commands:**
```bash
export ME=$(cast wallet address --private-key $PRIVATE_KEY)
export AMOUNT_OUT_MIN=0  # Set to 0 to skip slippage protection (or estimate manually)

# NOTE: SwapRouter02 exactInputSingle struct has NO deadline field
# Struct: (tokenIn, tokenOut, fee, recipient, amountIn, amountOutMinimum, sqrtPriceLimitX96)
cast send $ROUTER \
"exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))" \
"($TOKEN_IN,$TOKEN_OUT,$FEE,$ME,$AMOUNT_IN,$AMOUNT_OUT_MIN,$PRICE_LIMIT)" \
--rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

**After Success:**
- Check your token balances to confirm receipt
- Verify the swap happened in your liquidity range

## Troubleshooting

### Pool Already Initialized
If `initialize` reverts, the pool is already initialized. Skip Step 2.

### Invalid Tick Bounds
- Ensure `tickLower < tickUpper`
- Both must be multiples of `tickSpacing`
- With full‑range presets in `0-setup-env.sh`, you can skip any tick math entirely

### Insufficient Token Amounts
- Check you have enough tokens in your wallet
- Verify approvals were successful
- Ensure amounts match token decimals

### Swap Reverts
- Check token approvals (Step 5 - must be done before Step 6)
- Verify liquidity exists in your price range
- Set a reasonable `amountOutMinimum` (not 0 in production)
- **IMPORTANT**: SwapRouter02 `exactInputSingle` does NOT have a `deadline` parameter - don't include it in the struct!

### Token Decimals Mismatch
Both SSV and USDC have 18 decimals in this deployment. Adjust amounts if your tokens differ.

## Advanced: Custom Initial Price

To set a different initial price in Step 2, modify the Python calculation:

```python
P = 100.0  # 1 SSV = 100 USDC
sqrtPriceX96 = int(math.sqrt(P) * (1<<96))
print(hex(sqrtPriceX96))
```

## Advanced: Custom Tick Range

Instead of full‑range for testing, set specific bounds:

```bash
# Example: if current tick is ~0 and tick spacing is 60
export TICK_LOWER=-600   # Multiple of 60
export TICK_UPPER=600    # Multiple of 60
```

Ensure `tickLower < currentTick < tickUpper` for your position to earn fees.

