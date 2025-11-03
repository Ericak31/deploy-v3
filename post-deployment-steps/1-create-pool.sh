#!/bin/bash
# Step 1: Create the pool (if it doesn't already exist)

set -e

# Source environment if not already done
[ -z "$FACTORY" ] && source "$(dirname "$0")/0-setup-env.sh"

echo "=== Step 1: Create Pool ==="
echo "Creating pool for TOKEN0=$TOKEN0 and TOKEN1=$TOKEN1 with fee=$FEE"

# Check if pool already exists
echo "Checking if pool already exists..."
export POOL=$(cast call $FACTORY "getPool(address,address,uint24)(address)" $TOKEN0 $TOKEN1 $FEE --rpc-url $RPC_URL | tr -d '\r')

if [ "$POOL" != "0x0000000000000000000000000000000000000000" ]; then
  echo "✅ Pool already exists at: $POOL"
  # Save for later steps
  echo "export POOL=$POOL" >> .env.local
  echo "✅ Step 1 complete! (Pool already exists)"
else
  # 1a) Create the pool
  echo "Pool doesn't exist. Creating pool..."
  echo "Executing: cast send \$FACTORY \"createPool(address,address,uint24)\" \$TOKEN0 \$TOKEN1 \$FEE"
  cast send $FACTORY "createPool(address,address,uint24)" $TOKEN0 $TOKEN1 $FEE \
    --rpc-url $RPC_URL --private-key $PRIVATE_KEY || {
    echo "❌ Pool creation failed!"
    exit 1
  }

  # 1b) Fetch pool address
  echo ""
  echo "Fetching pool address..."
  export POOL=$(cast call $FACTORY "getPool(address,address,uint24)(address)" $TOKEN0 $TOKEN1 $FEE --rpc-url $RPC_URL | tr -d '\r')
  echo "POOL=$POOL"

  # Save for later steps
  echo "export POOL=$POOL" >> .env.local

  echo "Pool created at: $POOL"
  echo "✅ Step 1 complete!"
fi

