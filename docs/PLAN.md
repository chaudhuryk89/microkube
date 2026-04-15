# Project plan: microkube — KinD on WSL2, load simulation, and scaling

This file mirrors the living implementation plan. **Operator steps** and **troubleshooting** are in [README.md](../README.md); **HPA / HTTP stress** narrative is in [stress-test-and-horizontal-scaling.md](stress-test-and-horizontal-scaling.md).

## 1. Goal

A **disposable Kubernetes lab** on **Windows + WSL2** using **KinD**, with metrics (`kubectl top`), a **browser-visible** demo app, **HPA** driven by **HTTP load**, **loadtest** CPU/memory helpers, and **scripts + docs**.

## 2. Architecture

```mermaid
flowchart LR
  Win[Windows_host]
  WSL[WSL2_distro]
  Docker[Docker_daemon]
  KinD[KinD_cluster_dev]
  Win --> WSL
  WSL --> Docker
  Docker --> KinD
```

## 3. Repository map

| Area | Path | Role |
|------|------|------|
| Cluster | [kind/kind-config.yaml](../kind/kind-config.yaml) | Cluster **dev**, 1 control-plane + 2 workers, ingress-ready, **8080/8443** host maps. |
| Scripts | [scripts/](../scripts/) | `verify-prereqs`, `cluster-up`, `install-workloads`, `bootstrap`, `cluster-down`, `install-kind-wsl`. |
| Metrics | [k8s/metrics-server/](../k8s/metrics-server/) | Kustomize + **`--kubelet-insecure-tls`**. |
| Demo | [k8s/sample-app/](../k8s/sample-app/) | **demo**: nginx, Service, **hostless** Ingress, ConfigMap page, **HPA CPU 20%**. |
| Load | [k8s/load/](../k8s/load/) | **loadtest**: cpu-burn, cpu-spike CronJob, optional http-load / memory-spike Jobs. |

## 4. How capabilities are achieved

| Capability | Mechanism |
|------------|-----------|
| Multi-node KinD | [kind/kind-config.yaml](../kind/kind-config.yaml) + [cluster-up.sh](../scripts/cluster-up.sh) |
| `kubectl top` | [k8s/metrics-server](../k8s/metrics-server) patched for KinD kubelet TLS |
| Ingress from host | ingress-nginx Kind manifest + **extraPortMappings** 8080/8443 |
| Distinct demo page | ConfigMap `index.html` mounted in [deployment](../k8s/sample-app/deployment.yaml) |
| Correct routing on :8080 | Ingress **without** `host:` so `Host: …:8080` matches |
| HPA scales eagerly | [hpa.yaml](../k8s/sample-app/hpa.yaml): **`averageUtilization: 20`** |
| HTTP stress → demo | [http-load-job.yaml](../k8s/load/http-load-job.yaml): parallel **curl** ~3 min to **demo-web** Service |
| Steady / burst CPU in loadtest | [cpu-burn](../k8s/load/cpu-burn.yaml), [cpu-spike CronJob](../k8s/load/cpu-spike-cronjob.yaml) (busybox) |
| Memory demo | [memory-spike-job.yaml](../k8s/load/memory-spike-job.yaml) (python bytearray) |
| WSL bash safety | [.gitattributes](../.gitattributes): `*.sh` **LF** |

## 5. End-to-end flow

1. WSL + Docker + kubectl + kind → `bash scripts/verify-prereqs.sh`
2. `bash scripts/bootstrap.sh`
3. Browser → `http://demo.localtest.me:8080` or `http://127.0.0.1:8080`
4. Optional: `kubectl apply -f k8s/load/http-load-job.yaml` → `kubectl get hpa -n demo -w`
5. Re-simulate / CPU steps → [README § Re-simulate](../README.md#re-simulate-http-and-cpu-load)
6. `bash scripts/cluster-down.sh`

## 6. Verification checklist

- Context **kind-dev**; nodes Ready; **metrics-server** and **ingress-nginx** running
- **microkube demo-web** in browser (not wrong default backend)
- **`kubectl top pods`** works
- Under **http-load**, **HPA** replicas increase then settle after Job completes
- **loadtest**: **cpu-spike** completes (no **StartError** from removed stress images)
