# Webapp uniswap v3 integration Commands

All commands with `deadline` parameter must use a future timestamp. Generate it with: `$(($(date +%s)+1200))` (current time + 20 minutes)

Contract addresses (update for your network):
- QUOTER: 0x018FC7828A094375ae6C46B2E66d6bEEB9d2D7B5
- NPM: 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09
- ROUTER: 0x301906A8A6F393870390B50A0E2A8891B026e6Fc
- TOKEN0: 0x619b5EAD9A00795E1AB8Ef41E7f1B81c850Ab0C6 (SSV, 18 decimals)
- TOKEN1: 0xFf32778D4d3d6E1Ac9A859eBACB360F5118F837C (USDC, 18 decimals)
- FEE: 500 (0.05% fee tier)

## 1. Get Price Quote

**Quote exact input (get output for given input):**
```bash
cast call 0x018FC7828A094375ae6C46B2E66d6bEEB9d2D7B5 \
"quoteExactInputSingle((address,address,uint256,uint24,uint160))" \
"(0x619b5EAD9A00795E1AB8Ef41E7f1B81c850Ab0C6,0xFf32778D4d3d6E1Ac9A859eBACB360F5118F837C,10000000000000000000,500,0)" \
--rpc-url https://rpc.hoodi.ethpandaops.io
```

**Decode amountOut (first 64 hex chars after 0x):**
```bash
cast call 0x018FC7828A094375ae6C46B2E66d6bEEB9d2D7B5 \
"quoteExactInputSingle((address,address,uint256,uint24,uint160))" \
"(0x619b5EAD9A00795E1AB8Ef41E7f1B81c850Ab0C6,0xFf32778D4d3d6E1Ac9A859eBACB360F5118F837C,10000000000000000000,500,0)" \
--rpc-url https://rpc.hoodi.ethpandaops.io | cut -c3-66 | xargs cast --to-dec
```

Returns: `(amountOut, sqrtPriceX96After, initializedTicksCrossed, gasEstimate)`

## 2. Add Liquidity

**Approve tokens:**
```bash
cast send 0x619b5EAD9A00795E1AB8Ef41E7f1B81c850Ab0C6 \
"approve(address,uint256)" 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09 100000000000000000000000 \
--rpc-url https://rpc.hoodi.ethpandaops.io --private-key YOUR_PRIVATE_KEY

cast send 0xFf32778D4d3d6E1Ac9A859eBACB360F5118F837C \
"approve(address,uint256)" 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09 100000000000000000000000 \
--rpc-url https://rpc.hoodi.ethpandaops.io --private-key YOUR_PRIVATE_KEY
```

**Mint new position:**
```bash
cast send 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09 \
"mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))" \
"(0x619b5EAD9A00795E1AB8Ef41E7f1B81c850Ab0C6,0xFf32778D4d3d6E1Ac9A859eBACB360F5118F837C,500,-887270,887270,100000000000000000000000,100000000000000000000000,0,0,0x4da9f34f83d608cAB03868662e93c96Bc9793495,$(($(date +%s)+1200)))" \
--rpc-url https://rpc.hoodi.ethpandaops.io --private-key YOUR_PRIVATE_KEY
```

**Increase liquidity (add to existing position):**

**Note:** You can only add/remove liquidity from positions you own (or positions you've been approved to operate on via `setApprovalForAll`). Each position is an NFT - only the owner can modify it.

Find your position tokenId:
```bash
# Get number of positions owned
cast call 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09 \
"balanceOf(address)(uint256)" 0x4da9f34f83d608cAB03868662e93c96Bc9793495 \
--rpc-url https://rpc.hoodi.ethpandaops.io

# Get tokenId at index 0 (replace 0 with your index)
cast call 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09 \
"tokenOfOwnerByIndex(address,uint256)(uint256)" 0x4da9f34f83d608cAB03868662e93c96Bc9793495 0 \
--rpc-url https://rpc.hoodi.ethpandaops.io
```

Query position details (to see current liquidity):
```bash
# Returns: (nonce, operator, token0, token1, fee, tickLower, tickUpper, liquidity, feeGrowthInside0LastX128, feeGrowthInside1LastX128, tokensOwed0, tokensOwed1)
cast call 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09 \
"positions(uint256)(uint96,address,address,address,uint24,int24,int24,uint128,uint256,uint256,uint128,uint128)" \
1 --rpc-url https://rpc.hoodi.ethpandaops.io
```

Add liquidity to existing position:
```bash
cast send 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09 \
"increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))" \
"(1,50000000000000000000000,50000000000000000000000,0,0,$(($(date +%s)+1200)))" \
--rpc-url https://rpc.hoodi.ethpandaops.io --private-key YOUR_PRIVATE_KEY
```

**Use case:** Adding liquidity to an existing pool increases depth and can help stabilize price. Adding more TOKEN0 relative to TOKEN1 will push price down (more supply of TOKEN0).

## 3. Remove Liquidity

**Note:** You can only remove liquidity from positions you own. If you need to manipulate a pool's price but don't own a position, you must first mint a new position.

**Query position to get liquidity amount:**
```bash
# Get position details - 8th value (index 7) is liquidity
cast call 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09 \
"positions(uint256)(uint96,address,address,address,uint24,int24,int24,uint128,uint256,uint256,uint128,uint128)" \
1 --rpc-url https://rpc.hoodi.ethpandaops.io
```

**Decrease liquidity (remove partial or full amount):**
```bash
# Remove liquidity - use liquidity value from position query above
cast send 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09 \
"decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))" \
"(1,100000000000000000000,0,0,$(($(date +%s)+1200)))" \
--rpc-url https://rpc.hoodi.ethpandaops.io --private-key YOUR_PRIVATE_KEY
```

**Collect tokens (must call after decreaseLiquidity):**
```bash
cast send 0xEd6844FAEd8a049Cbd90A7513D0100C03e51EC09 \
"collect((uint256,address,uint128,uint128))" \
"(1,0x4da9f34f83d608cAB03868662e93c96Bc9793495,340282366920938463463374607431768211455,340282366920938463463374607431768211455)" \
--rpc-url https://rpc.hoodi.ethpandaops.io --private-key YOUR_PRIVATE_KEY
```

**Use case:** Removing liquidity from a pool reduces depth and can move price. Removing TOKEN0 (relative to TOKEN1) will push price up (less supply of TOKEN0). Use this to manipulate pool price to a desired level.

## 4. Perform Swap

**Approve router:**
```bash
cast send 0x619b5EAD9A00795E1AB8Ef41E7f1B81c850Ab0C6 \
"approve(address,uint256)" 0x301906A8A6F393870390B50A0E2A8891B026e6Fc 10000000000000000000 \
--rpc-url https://rpc.hoodi.ethpandaops.io --private-key YOUR_PRIVATE_KEY
```

**Swap:**
```bash
cast send 0x301906A8A6F393870390B50A0E2A8891B026e6Fc \
"exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))" \
"(0x619b5EAD9A00795E1AB8Ef41E7f1B81c850Ab0C6,0xFf32778D4d3d6E1Ac9A859eBACB360F5118F837C,500,0x4da9f34f83d608cAB03868662e93c96Bc9793495,10000000000000000000,0,0)" \
--rpc-url https://rpc.hoodi.ethpandaops.io --private-key YOUR_PRIVATE_KEY
```

**Note:** For TOKEN1->TOKEN0 swaps, use `sqrtPriceLimitX96` = `0xffffffffffffffffffffffffffffffffffffffff` instead of `0`.
