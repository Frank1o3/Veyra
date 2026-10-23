#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${REPO_DIR}/veyra-iso"
OUT_DIR="${REPO_DIR}/out"

command -v mkarchiso >/dev/null || {
    echo "mkarchiso is missing. Install the archiso package first." >&2
    exit 1
}

mkdir -p "$OUT_DIR"
cd "$REPO_DIR"
mkarchiso -r -v -o "$OUT_DIR" "$PROFILE_DIR"
echo "ISO build complete: ${OUT_DIR}"
