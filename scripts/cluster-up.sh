#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KIND_EXPERIMENTAL_PROVIDER=docker

kind create cluster --config "${ROOT}/kind/kind-config.yaml"
kubectl config use-context kind-dev
kubectl cluster-info
kubectl get nodes -o wide
