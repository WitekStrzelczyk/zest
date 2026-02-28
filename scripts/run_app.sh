#!/usr/bin/env bash
# Backward-compatible launcher. Preferred entrypoint: ./scripts/run

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/run" "$@"
