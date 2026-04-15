#!/usr/bin/env bash
set -euo pipefail

fail=0

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "MISSING: $1" >&2
    fail=1
  else
    echo "OK: $1 ($($1 --version 2>/dev/null | head -n1 || true))"
  fi
}

echo "=== WSL / environment ==="
if grep -qi microsoft /proc/version 2>/dev/null; then
  echo "OK: appears to be WSL ($(uname -r))"
else
  echo "NOTE: /proc/version does not look like WSL (still checking tools)"
fi

echo "=== Required commands ==="
need_cmd docker
need_cmd kubectl
need_cmd kind

echo "=== Docker daemon ==="
if docker info >/dev/null 2>&1; then
  echo "OK: docker info"
else
  echo "MISSING: Docker is not reachable from this shell (start Docker Desktop / dockerd)" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "" >&2
  echo "Fix the items above, then re-run: bash scripts/verify-prereqs.sh" >&2
  exit 1
fi

echo ""
echo "All prerequisite checks passed."
