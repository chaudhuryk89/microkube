#!/usr/bin/env bash
set -euo pipefail
BIN="${HOME}/.local/bin"
mkdir -p "${BIN}"
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) K="amd64" ;;
  aarch64 | arm64) K="arm64" ;;
  *)
    echo "Unsupported machine: ${ARCH}" >&2
    exit 1
    ;;
esac
# Pinned stable release (avoid `latest` resolving to pre-releases).
KIND_VERSION="${KIND_VERSION:-v0.31.0}"
URL="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${K}"
echo "Downloading ${URL}"
curl -fsSL -o "${BIN}/kind" "${URL}"
chmod +x "${BIN}/kind"
if ! grep -qF '.local/bin' "${HOME}/.bashrc" 2>/dev/null; then
  echo 'export PATH="${HOME}/.local/bin:${PATH}"' >>"${HOME}/.bashrc"
  echo "Appended PATH to ~/.bashrc — run: source ~/.bashrc"
fi
export PATH="${HOME}/.local/bin:${PATH}"
echo "Installed:"
kind version
