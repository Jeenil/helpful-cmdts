# kubectl Commands

> **Docs:** [kubectl reference](https://kubernetes.io/docs/reference/kubectl/)
> **Cheatsheet:** [kubectl quick reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/)

These examples use the `pwsh-cron-jobs` deployment in AKS dev as the real reference point.
Swap in any namespace/name for other workloads.

---

## Context & Cluster

```bash
# See which cluster you're connected to
kubectl config current-context

# List all configured clusters
kubectl config get-contexts

# Switch to a different cluster
kubectl config use-context <context-name>
```

---

## Namespaces

```bash
# List all namespaces
kubectl get namespaces

# Shorthand
kubectl get ns
```

Current deployment spans two namespaces:

- `flux-system` where the HelmRelease lives (Flux manages it)
- `pwsh-cron-jobs` where the actual CronJob, Jobs, and Pods run

---

## Flux / HelmRelease

> **Docs:** [HelmRelease](https://fluxcd.io/flux/components/helm/helmreleases/)

```bash
# Check if Flux has picked up and applied your HelmRelease
kubectl get helmrelease pwsh-cron-jobs -n flux-system

# Force Flux to re-sync immediately (don't wait for the 1h interval)
flux reconcile helmrelease pwsh-cron-jobs -n flux-system

# See full status, conditions, and any errors
kubectl describe helmrelease pwsh-cron-jobs -n flux-system
```

---

## CronJobs

> **Docs:** [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)

```bash
# List all CronJobs in the namespace
kubectl get cronjob -n pwsh-cron-jobs

# See schedule, last run time, and next scheduled run
kubectl describe cronjob pwsh-cron-jobs-pwsh-cron-jobs -n pwsh-cron-jobs

# Manually trigger a one-off run right now (great for testing without waiting for the schedule)
kubectl create job --from=cronjob/pwsh-cron-jobs-pwsh-cron-jobs manual-test-1 -n pwsh-cron-jobs

# Delete a manually triggered job when you're done
kubectl delete job manual-test-1 -n pwsh-cron-jobs
```

> The schedule in your HelmRelease is `0 */2 * * *` runs every 2 hours.
> Use the manual trigger above whenever you don't want to wait.

---

## Jobs

> **Docs:** [Job](https://kubernetes.io/docs/concepts/workloads/controllers/job/)

```bash
# List all jobs (each CronJob run creates one Job)
kubectl get jobs -n pwsh-cron-jobs

# Watch jobs update in real time
kubectl get jobs -n pwsh-cron-jobs -w

# See why a job failed, retry count, duration
kubectl describe job <job-name> -n pwsh-cron-jobs
```

---

## Pods

> **Docs:** [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)

```bash
# List pods each job run = one pod
kubectl get pods -n pwsh-cron-jobs

# Watch pods start and change state in real time
kubectl get pods -n pwsh-cron-jobs -w

# Show wide output (includes node it ran on and IP)
kubectl get pods -n pwsh-cron-jobs -o wide

# Full pod details: image used, events, exit codes
kubectl describe pod <pod-name> -n pwsh-cron-jobs
```

### Pod statuses you'll see

| Status             | Meaning                                                         |
| ------------------ | --------------------------------------------------------------- |
| `Pending`          | Scheduled but not started yet (pulling image, waiting for node) |
| `Running`          | Container is active                                             |
| `Completed`        | Finished successfully                                           |
| `OOMKilled`        | Ran out of memory check logs                                  |
| `CrashLoopBackOff` | Keeps failing and restarting                                     |

---

## Logs

```bash
# Print logs from a pod
kubectl logs <pod-name> -n pwsh-cron-jobs

# Follow logs live while the pod is running
kubectl logs -f <pod-name> -n pwsh-cron-jobs

# Get logs from a pod that already finished or crashed
kubectl logs <pod-name> -n pwsh-cron-jobs --previous

# Last 50 lines only
kubectl logs <pod-name> -n pwsh-cron-jobs --tail=50
```

---

## Exec Into a Container

> **Docs:** [Get a shell to a running container](https://kubernetes.io/docs/tasks/debug/debug-application/get-shell-running-container/)

The pod must be in `Running` state. Use the manual job trigger above, then exec in while it's running.

```bash
# Open an interactive PowerShell session inside the container
kubectl exec -it <pod-name> -n pwsh-cron-jobs -- pwsh

# Open a bash shell instead
kubectl exec -it <pod-name> -n pwsh-cron-jobs -- /bin/bash

# Run a single command without going interactive
kubectl exec <pod-name> -n pwsh-cron-jobs -- pwsh -c "Get-ChildItem /scripts"

# Check what env vars the workload identity injected
kubectl exec <pod-name> -n pwsh-cron-jobs -- env | grep AZURE
```

---

## Testing the Entitlement Management Drift Script

The script at `/scripts/entitlement-management-drift/entitlement-management-drift.ps1`
runs `Get-EntraVacAccessPackageDrift` against the configured access packages and logs
results via `Send-Log` (JSON to stdout, App Insights if key is available).

```bash
# 1. Force Flux to deploy the latest image first
flux reconcile helmrelease pwsh-cron-jobs -n flux-system

# 2. Trigger a manual run
kubectl create job --from=cronjob/pwsh-cron-jobs-pwsh-cron-jobs drift-test-1 -n pwsh-cron-jobs

# 3. Watch the pod come up
kubectl get pods -n pwsh-cron-jobs -w

# 4. Stream the script output (JSON log lines from Send-Log)
kubectl logs -f <pod-name> -n pwsh-cron-jobs

# 5. If something looks wrong, exec in and run the script manually
kubectl exec -it <pod-name> -n pwsh-cron-jobs -- pwsh
# Then inside the pod:
# & /scripts/run-script.ps1 -ScriptName entitlement-management-drift

# 6. Clean up
kubectl delete job drift-test-1 -n pwsh-cron-jobs
```

### What to look for in the logs

Each `Send-Log` call outputs a compressed JSON line. A clean run looks like:

```json
{"TimeGenerated":"...","Level":"INFO","Message":"Access package drift check complete","AccessPackageName":"Logix-Reporting","ShouldAdd":0,"ShouldRemove":0,"ShouldReprocess":0,...}
{"TimeGenerated":"...","Level":"INFO","Message":"All access packages are in sync",...}
```

A drift detected run will show `"Level":"WARNING"` with individual user entries.

---

## Typical Debug Workflow

```bash
# 1. Confirm the CronJob exists and see its name
kubectl get cronjob -n pwsh-cron-jobs

# 2. Trigger it manually so you don't wait 2 hours
kubectl create job --from=cronjob/pwsh-cron-jobs-pwsh-cron-jobs test-run-1 -n pwsh-cron-jobs

# 3. Watch the pod appear and track its state
kubectl get pods -n pwsh-cron-jobs -w

# 4. Read the output (PowerShell script logs)
kubectl logs <pod-name> -n pwsh-cron-jobs

# 5. If you need to poke around inside
kubectl exec -it <pod-name> -n pwsh-cron-jobs -- pwsh

# 6. Clean up your test job
kubectl delete job test-run-1 -n pwsh-cron-jobs
```

---

## Useful Flags

| Flag                      | What it does                         |
| ------------------------- | ------------------------------------ |
| `-n <namespace>`          | Target a specific namespace          |
| `-A` / `--all-namespaces` | Run command across all namespaces    |
| `-w`                      | Watch for live updates               |
| `-o wide`                 | Extra columns (node, IP)             |
| `-o yaml`                 | Full resource definition as YAML     |
| `--previous`              | Logs from the last crashed container |
| `-f`                      | Follow/stream logs                   |
