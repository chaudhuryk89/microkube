#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "${ROOT}/scripts/verify-prereqs.sh"
bash "${ROOT}/scripts/cluster-up.sh"
bash "${ROOT}/scripts/install-workloads.sh"
