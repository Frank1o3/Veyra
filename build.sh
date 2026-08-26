#!/usr/bin/env bash

# Exit immediately if a command fails
set -e

# Core paths
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAPPER_DIR="${REPO_DIR}/bootstrapper"
ISO_PROFILE_DIR="${REPO_DIR}/veyra-iso"
STAGING_DIR="/tmp/veyra-build"
OUT_DIR="${REPO_DIR}/out"

echo "=== [1/4] Building Rust Bootstrapper ==="
cd "${BOOTSTRAPPER_DIR}"
# Build as a fully optimized, statically linked release binary
cargo build --release

echo "=== [2/4] Setting Up Build Staging Workspace ==="
# Clear old configurations safely
sudo rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}" "${OUT_DIR}"

# Copy the fresh profile structure to the clean throwaway workspace
cp -r "${ISO_PROFILE_DIR}/." "${STAGING_DIR}/"

echo "=== [3/4] Injecting Compiled Bootstrapper Binary ==="
# Move compiled binary directly into your staged system paths
cp "${BOOTSTRAPPER_DIR}/target/release/bootstrapper" "${STAGING_DIR}/airootfs/usr/local/bin/veyra-installer"

echo "=== [4/4] Generating Distribution Installation ISO ==="
cd "${STAGING_DIR}"
# mkarchiso must run as root to construct correct loopback overlay permissions
sudo mkarchiso -v -w "${STAGING_DIR}/work" -o "${OUT_DIR}" "${STAGING_DIR}"

echo "=== Success! ISO built inside ${OUT_DIR} ==="
