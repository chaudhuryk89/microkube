# Stress test, 20% CPU target, and validating scaling in real time

## What we built

This lab runs a small **KinD** cluster with **metrics-server** (so Kubernetes can see CPU per pod), a **`demo-web`** app (nginx) in the **`demo`** namespace, and a **HorizontalPodAutoscaler (HPA)** on that Deployment. Separately, in **`loadtest`**, a **Job** drives HTTP traffic at **`demo-web`** so its pods do real work and their **CPU utilization** goes up.

The HPA is configured with **`averageUtilization: 20`** on CPU ([`k8s/sample-app/hpa.yaml`](../k8s/sample-app/hpa.yaml)). That means the controller tries to keep **average CPU use near 20% of each pod’s CPU request** (not 20% of the node). If measured utilization stays **above** that target, Kubernetes **adds replicas** (up to **8**); if it stays **below**, it **removes replicas** (down to **2**). A **20%** target is **lower** than a typical 50–70% default, so the autoscaler is **more eager** to scale out under the same load—useful for demos.

## How the HTTP stress test works

The manifest [`k8s/load/http-load-job.yaml`](../k8s/load/http-load-job.yaml) defines a **Batch Job** named **`http-load`**. A pod runs a **shell loop for about three minutes**: each iteration launches many **parallel `curl`** calls to `http://demo-web.demo.svc.cluster.local/` (in-cluster DNS to the **`demo-web`** Service). That simulates many clients hitting the app at once, raises **CPU** on **`demo-web`** pods, and gives the HPA a signal to **scale out**.

**Note:** Kubernetes Job names are unique. To run the stress again, delete the previous Job before re-applying (see [README § Re-simulate](../README.md#re-simulate-http-and-cpu-load)).

## How to validate cluster usage and horizontal scaling in real time

Prerequisites: context **`kind-dev`**, **metrics-server** running, **`demo-web`** and HPA applied.

1. **Start (or restart) the HTTP load**

   ```bash
   kubectl delete job http-load -n loadtest --ignore-not-found
   kubectl apply -f k8s/load/http-load-job.yaml
   ```

2. **Watch scaling (best single view)**  
   Updates every few seconds until you press Ctrl+C:

   ```bash
   kubectl get hpa -n demo -w
   ```

   Watch **REPLICAS** increase from **2** toward a higher value while load is on; after the Job finishes, replicas should **cool down** toward **2** again (subject to HPA stabilization delays).

3. **Confirm pod count**

   ```bash
   kubectl get pods -n demo -l app=demo-web -w
   ```

4. **See CPU usage (cluster “usage” for those pods)**

   ```bash
   kubectl top pods -n demo
   kubectl top nodes
   ```

5. **Optional: load generator visibility**

   ```bash
   kubectl get pods -n loadtest -l app=http-load
   kubectl logs -n loadtest job/http-load -f
   ```

6. **Optional GUI**  
   **Lens** or **Headlamp** against your kubeconfig: open the **`demo`** namespace, **HPA** / **Deployment** / **Pods**, and metrics views—same signals as above, updated live.

Together, **`kubectl get hpa -n demo -w`** plus **`kubectl get pods -n demo -l app=demo-web -w`** is the minimal **real-time** story for **horizontal scaling**; **`kubectl top`** ties it to **resource usage**.
