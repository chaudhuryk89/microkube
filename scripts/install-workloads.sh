#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CTX="${KIND_CLUSTER_NAME:-dev}"
kubectl config use-context "kind-${CTX}"

echo "=== Namespaces ==="
kubectl apply -f "${ROOT}/k8s/namespaces.yaml"

echo "=== Metrics server (KinD patch via kustomize) ==="
kubectl kustomize "${ROOT}/k8s/metrics-server" | kubectl apply -f -
kubectl rollout status deployment/metrics-server -n kube-system --timeout=120s

echo "=== Ingress NGINX (Kind provider manifest, pinned release) ==="
INGRESS_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/kind/deploy.yaml"
kubectl apply -f "${INGRESS_URL}"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "=== Demo app + HPA + Ingress ==="
kubectl apply -k "${ROOT}/k8s/sample-app"
kubectl rollout status deployment/demo-web -n demo --timeout=120s

echo "=== Load generators (CPU burn, CronJob spikes; memory job created on apply) ==="
kubectl apply -k "${ROOT}/k8s/load"

echo "=== Wait for metrics-server API ==="
for i in $(seq 1 30); do
  if kubectl top nodes >/dev/null 2>&1; then
    echo "metrics-server is answering."
    break
  fi
  echo "waiting for metrics-server ($i/30)..."
  sleep 4
done

kubectl top nodes || true
kubectl top pods -n demo || true
kubectl top pods -n loadtest || true

echo ""
echo "Optional: kubectl apply -f ${ROOT}/k8s/load/http-load-job.yaml"
echo "Ingress URL (localtest.me resolves to 127.0.0.1): http://demo.localtest.me:8080"
