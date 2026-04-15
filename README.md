# microkube — KinD on WSL2 (demo workloads + monitoring)

This repo implements a **Kubernetes in Docker (KinD)** lab on **Windows + WSL2**: multi-node cluster, **ingress-nginx**, **metrics-server** (KinD-compatible), a **demo** web app with **HPA**, and **loadtest** workloads for CPU spikes and HTTP bursts.

## Deploying from the Cursor terminal (Windows + WSL2)

These steps assume the project lives at `e:\cursor_projects\microkube` on Windows.

### 1. Use a WSL shell in Cursor

- Open the terminal panel (**Ctrl+`**).
- Click the **+** dropdown next to the terminal tab and choose your **WSL** profile (for example **Ubuntu**),  
  **or** in Command Palette run **Terminal: Select Default Profile** and set **Ubuntu (WSL)** so new terminals open in WSL.

Do **not** run `bash scripts/*.sh` from plain PowerShell unless you wrap them with `wsl` (see step 6).

### 2. Go to the project directory inside WSL

Drive `E:` is usually mounted as `/mnt/e`:

```bash
cd /mnt/e/cursor_projects/microkube
```

If your repo path differs, `cd` to the folder that contains `scripts/` and `kind/`.

### 3. Install tools inside WSL (one-time)

You need **Docker** (via Docker Desktop WSL integration or Docker Engine in WSL), plus **kubectl** and **kind** in **this** WSL distro. Example on Ubuntu:

Install **kubectl** and **kind** inside WSL using the official guides:  
[Install kubectl on Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) and [KinD installation](https://kind.sigs.k8s.io/docs/user/quick-start/#installation).

Confirm:

```bash
bash scripts/verify-prereqs.sh
```

Fix anything reported as `MISSING` before continuing.

### 4. Create the cluster and install workloads

```bash
bash scripts/bootstrap.sh
```

First run can take several minutes (images pulls, ingress ready, metrics-server).

### 5. Confirm the simulation is running

```bash
kubectl config use-context kind-dev
kubectl get nodes
kubectl get pods -A
kubectl top pods -A
```

Open in a browser: **http://demo.localtest.me:8080** or **http://127.0.0.1:8080**  
You should see the **microkube demo-web** heading (not the stock nginx welcome page). The Ingress uses a **hostless** rule so `Host: …:8080` still routes to this app.

### 6. Optional: run from PowerShell without switching profile

```powershell
wsl -e bash -lc "cd /mnt/e/cursor_projects/microkube && bash scripts/verify-prereqs.sh"
wsl -e bash -lc "cd /mnt/e/cursor_projects/microkube && bash scripts/bootstrap.sh"
```

### 7. Run load simulations (same WSL terminal, repo as cwd)

```bash
cd /mnt/e/cursor_projects/microkube
kubectl config use-context kind-dev
```

First-time HTTP burst and optional memory job:

```bash
kubectl apply -f k8s/load/http-load-job.yaml
kubectl get hpa -n demo -w
kubectl apply -f k8s/load/memory-spike-job.yaml
kubectl get pods -n loadtest
kubectl top pods -n loadtest
```

To **run HTTP or CPU load again** (delete old Jobs, scale `cpu-burn`, manual spike), use **[Re-simulate HTTP and CPU load](#re-simulate-http-and-cpu-load)** below.

### 8. Tear down

```bash
cd /mnt/e/cursor_projects/microkube
bash scripts/cluster-down.sh
```

---

## Prerequisites (WSL2)

Run everything from **WSL** (Ubuntu recommended) with **Docker** available in that same shell:

- **Path A**: Docker Desktop on Windows → enable **WSL integration** for your distro.
- **Path B**: Docker Engine installed inside WSL.

Install **kubectl**, **KinD**, and ensure WSL has enough RAM/CPU (see `.wslconfig` on Windows if the cluster is slow or OOMs).

Verify:

```bash
bash scripts/verify-prereqs.sh
```

## One-shot bootstrap

Creates cluster `dev` (context `kind-dev`), installs metrics-server, ingress, demo app, HPA, and baseline load generators:

```bash
bash scripts/bootstrap.sh
```

Tear down:

```bash
bash scripts/cluster-down.sh
```

## Manual steps (same as scripts)

```bash
bash scripts/cluster-up.sh
bash scripts/install-workloads.sh
```

## Try the demo app

- **Ingress**: [http://demo.localtest.me:8080](http://demo.localtest.me:8080) or `http://127.0.0.1:8080` (same rule; **microkube demo-web** title in the page).  
  Port **8080** is mapped in [kind/kind-config.yaml](kind/kind-config.yaml) so privileged ports 80/443 are not required on Windows.

Optional HTTP load (drives **HPA** + CPU in Lens / `kubectl top`):

```bash
kubectl apply -f k8s/load/http-load-job.yaml
kubectl logs -n loadtest job/http-load -f
kubectl get hpa -n demo -w
```

Optional memory pressure job (may hit **OOMKilled** depending on limits — use a throwaway namespace):

```bash
kubectl apply -f k8s/load/memory-spike-job.yaml
kubectl logs -n loadtest job/memory-spike -f
```

CPU spike **CronJob** runs every **5** minutes ([k8s/load/cpu-spike-cronjob.yaml](k8s/load/cpu-spike-cronjob.yaml)). CPU burn runs continuously ([k8s/load/cpu-burn.yaml](k8s/load/cpu-burn.yaml)).

### If `cpu-spike` / `memory-spike` show `StartError`

Older manifests used **`polinux/stress`**, which often fails container creation on current KinD/containerd (you still see **`StartError`** in `kubectl get pods`). The repo now uses **`busybox`** (CPU spike) and **`python:3.12-alpine`** (memory spike). Re-apply and remove stuck jobs/pods:

```bash
kubectl apply -f k8s/load/cpu-spike-cronjob.yaml
kubectl delete jobs -n loadtest -l app=cpu-spike --ignore-not-found
kubectl delete pods -n loadtest -l app=cpu-spike --field-selector=status.phase!=Running --ignore-not-found

kubectl delete job memory-spike -n loadtest --ignore-not-found
kubectl apply -f k8s/load/memory-spike-job.yaml
```

## Re-simulate HTTP and CPU load

Use a **WSL** shell, cluster context **`kind-dev`**, and repo root (for example `cd /mnt/e/cursor_projects/microkube`).

### HTTP load (hits `demo-web`, good for HPA / scaling)

A **Job** named `http-load` can only exist once. To run another burst:

1. **Use the right cluster**

   ```bash
   kubectl config use-context kind-dev
   ```

2. **Remove the previous run** (safe if nothing exists)

   ```bash
   kubectl delete job http-load -n loadtest --ignore-not-found
   ```

3. **Start a new HTTP load Job**

   ```bash
   kubectl apply -f k8s/load/http-load-job.yaml
   ```

4. **Watch horizontal scaling** (HPA on `demo-web` in namespace `demo`)

   ```bash
   kubectl get hpa -n demo -w
   ```

   Press **Ctrl+C** when you are done. In another terminal you can run:

   ```bash
   kubectl get pods -n demo -l app=demo-web
   kubectl top pods -n demo
   ```

5. **Optional: follow the load pod logs**

   ```bash
   kubectl logs -n loadtest job/http-load -f
   ```

The Job runs about **three minutes** of parallel `curl` traffic to `demo-web` inside the cluster.

### CPU load (namespace `loadtest`, for `kubectl top` / dashboards)

This does **not** scale **`demo-web`**; it only adds **CPU usage on `loadtest` pods** (and nodes), useful for monitoring demos.

**Steady CPU (`cpu-burn` Deployment)** — already running after bootstrap.

- **See it**

  ```bash
  kubectl get pods -n loadtest -l app=cpu-burn
  kubectl top pods -n loadtest -l app=cpu-burn
  ```

- **Turn the “volume” up or down** (more replicas = more busy-loops)

  ```bash
  kubectl scale deployment cpu-burn -n loadtest --replicas=3
  kubectl top pods -n loadtest
  kubectl scale deployment cpu-burn -n loadtest --replicas=1
  ```

**Short CPU spikes (`cpu-spike` CronJob)** — runs on a **5-minute** schedule by default.

- **Wait for the next tick**, or **start one spike immediately** (one-off Job from the CronJob):

  ```bash
  kubectl create job -n loadtest --from=cronjob/cpu-spike cpu-spike-manual-$(date +%s)
  kubectl get pods -n loadtest -l app=cpu-spike -w
  ```

- **Re-apply the CronJob** after editing the manifest (optional)

  ```bash
  kubectl apply -f k8s/load/cpu-spike-cronjob.yaml
  ```

### Quick reference (copy-paste)

```bash
kubectl config use-context kind-dev
cd /mnt/e/cursor_projects/microkube

# HTTP again
kubectl delete job http-load -n loadtest --ignore-not-found
kubectl apply -f k8s/load/http-load-job.yaml
kubectl get hpa -n demo -w

# CPU: stronger steady burn
kubectl scale deployment cpu-burn -n loadtest --replicas=3
kubectl top pods -n loadtest

# CPU: one immediate spike
kubectl create job -n loadtest --from=cronjob/cpu-spike cpu-spike-manual-$(date +%s)
```

## Monitoring and visualization

| Tool | Role |
|------|------|
| **[Lens](https://k8slens.dev/)** | Recommended desktop UI: workloads, events, logs, metrics when metrics-server is installed. |
| **[Headlamp](https://headlamp.dev/)** | Open-source web UI; point it at your kubeconfig. |
| **k9s** | Terminal UI for fast live navigation. |

**Kubeconfig path (WSL → Lens on Windows)**  
Merge or reference the file WSL uses, for example:

`\\wsl$\Ubuntu\home\<you>\.kube\config`

In Lens: **Add cluster** from kubeconfig. Use context **kind-dev**.

**Optional production-style metrics**  
For dashboards and retention, add **Prometheus + Grafana** (for example the **kube-prometheus-stack** Helm chart). That stack is heavier than metrics-server alone; give WSL extra memory before installing.

## Layout

| Path | Purpose |
|------|---------|
| [kind/kind-config.yaml](kind/kind-config.yaml) | Multi-node KinD + ingress port mappings |
| [k8s/metrics-server/](k8s/metrics-server/) | Kustomize overlay: upstream + `--kubelet-insecure-tls` |
| [k8s/sample-app/](k8s/sample-app/) | `demo` namespace: nginx, Service, Ingress, HPA |
| [k8s/load/](k8s/load/) | `loadtest` namespace: CPU burn, CronJob spikes; optional Jobs |
| [scripts/](scripts/) | verify, cluster up/down, install |
| [docs/stress-test-and-horizontal-scaling.md](docs/stress-test-and-horizontal-scaling.md) | Short write-up: HTTP stress, **20%** HPA CPU target, real-time validation |
| [docs/PLAN.md](docs/PLAN.md) | Project plan: goals, architecture, how each part is achieved, verification |

## Sanity checklist

- `kind get clusters` lists **dev**
- `kubectl get pods -A` shows **ingress-nginx**, **metrics-server**, **demo**, **loadtest** healthy
- `kubectl top pods -A` works after ~1–2 minutes
- Browser or `curl` hits **demo.localtest.me:8080** (or **127.0.0.1:8080**) and shows **microkube demo-web**
