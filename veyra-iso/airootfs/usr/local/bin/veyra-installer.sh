#!/usr/bin/env bash
set -euo pipefail

cd /usr/local/lib/veyra/veyra-installer
export PYTHONPATH="$PWD/src"
exec python3 -m veyra_installer.main