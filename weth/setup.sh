#!/usr/bin/env bash
set -euo pipefail

# Install Foundry if not already installed
if ! command -v forge >/dev/null 2>&1; then
  echo "Installing Foundry..."
  curl -L https://foundry.paradigm.xyz | bash
  export PATH="$HOME/.foundry/bin:$PATH"
  foundryup
fi

# Ensure we are in the weth directory
cd "$(dirname "$0")"

# Initialize lib and add forge-std (kept local under ./lib)
mkdir -p lib
if [ ! -d lib/forge-std ]; then
  echo "Installing forge-std into ./lib..."
  git clone --depth 1 https://github.com/foundry-rs/forge-std.git lib/forge-std
fi

echo "Setup complete. You can now run ./deploy.sh"
