# kubectl Commands

> **Docs:** [kubectl reference](https://kubernetes.io/docs/reference/kubectl/)
> **Cheatsheet:** [kubectl quick reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/)

These examples use the `pwsh-cronjobs` deployment in AKS dev as the real reference point.
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

Current Deployment in two namespaces:

- `flux-system` — where the HelmRelease lives (Flux manages it)
- `pwsh-cronjobs` — where the actual CronJob, Jobs, and Pods run

## Flux / HelmRelease

> **Docs:** [HelmRelease](https://fluxcd.io/flux/components/helm/helmreleases/)

```bash
# Check if Flux has picked up and applied your HelmRelease
kubectl get helmrelease pwsh-cronjobs -n flux-system

# Force Flux to re-sync immediately (don't wait for the 1h interval)
flux reconcile helmrelease pwsh-cronjobs -n flux-system

# See full status, conditions, and any errors
kubectl describe helmrelease pwsh-cronjobs -n flux-system
```

---

## CronJobs

> **Docs:** [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)

```bash
# List all CronJobs in the namespace
kubectl get cronjob -n pwsh-cronjobs

# See schedule, last run time, and next scheduled run
kubectl describe cronjob pwsh-cronjobs-pwsh-cronjobs -n pwsh-cronjobs

# Manually trigger a one-off run right now (great for testing without waiting for the schedule)
kubectl create job --from=cronjob/pwsh-cronjobs-pwsh-cronjobs manual-test-1 -n pwsh-cronjobs

# Delete a manually triggered job when you're done
kubectl delete job manual-test-1 -n pwsh-cronjobs
```

> The schedule in your HelmRelease is `0 */2 * * *` — runs every 2 hours.
> Use the manual trigger above whenever you don't want to wait.

---

## Jobs

> **Docs:** [Job](https://kubernetes.io/docs/concepts/workloads/controllers/job/)

```bash
# List all jobs (each CronJob run creates one Job)
kubectl get jobs -n pwsh-cronjobs

# Watch jobs update in real time
kubectl get jobs -n pwsh-cronjobs -w

# See why a job failed, retry count, duration
kubectl describe job <job-name> -n pwsh-cronjobs
```

---

## Pods

> **Docs:** [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)

```bash
# List pods — each job run = one pod
kubectl get pods -n pwsh-cronjobs

# Watch pods start and change state in real time
kubectl get pods -n pwsh-cronjobs -w

# Show wide output (includes node it ran on and IP)
kubectl get pods -n pwsh-cronjobs -o wide

# Full pod details: image used, events, exit codes
kubectl describe pod <pod-name> -n pwsh-cronjobs
```

### Pod statuses you'll see

| Status            | Meaning                                                        |
| ----------------  | -------------------------------------------------------------- |
| `Pending`         | Scheduled but not started yet (pulling image, waiting for node)|
| `Running`         | Container is active                                            |
| `Completed`       | Finished successfully                                          |
| `Error OOMKilled` | Crashed check logs                                             |
| `CrashLoopBackOff`| Keeps failing and restarting                                   |

## Logs

```bash
# Print logs from a pod
kubectl logs <pod-name> -n pwsh-cronjobs

# Follow logs live while the pod is running
kubectl logs -f <pod-name> -n pwsh-cronjobs

# Get logs from a pod that already finished or crashed
kubectl logs <pod-name> -n pwsh-cronjobs --previous

# Last 50 lines only
kubectl logs <pod-name> -n pwsh-cronjobs --tail=50
```

---

## Exec Into a Container

> **Docs:** [Get a shell to a running container](https://kubernetes.io/docs/tasks/debug/debug-application/get-shell-running-container/)

The pod must be in `Running` state. Use the manual job trigger above, then exec in while it's running.

```bash
# Open an interactive PowerShell session inside the container
kubectl exec -it <pod-name> -n pwsh-cronjobs -- pwsh

# Open a bash shell instead
kubectl exec -it <pod-name> -n pwsh-cronjobs -- /bin/bash

# Run a single command without going interactive
kubectl exec <pod-name> -n pwsh-cronjobs -- pwsh -c "Get-ChildItem /app"
kubectl exec <pod-name> -n pwsh-cronjobs -- env   # see environment variables
```

---

## Typical Debug Workflow

```bash
# 1. Confirm the CronJob exists and see its name
kubectl get cronjob -n pwsh-cronjobs

# 2. Trigger it manually so you don't wait 2 hours
kubectl create job --from=cronjob/pwsh-cronjobs-pwsh-cronjobs test-run-1 -n pwsh-cronjobs

# 3. Watch the pod appear and track its state
kubectl get pods -n pwsh-cronjobs -w

# 4. Read the output (PowerShell script logs)
kubectl logs <pod-name> -n pwsh-cronjobs

# 5. If you need to poke around inside
kubectl exec -it <pod-name> -n pwsh-cronjobs -- pwsh

# 6. Clean up your test job
kubectl delete job test-run-1 -n pwsh-cronjobs
```

---

## Useful Flags

| Flag                      | What it does                          |
| -----------------------   | ------------------------------------- |
| `-n <namespace>`          | Target a specific namespace           |
| `-A` / `--all-namespaces` | Run command across all namespaces     |
| `-w`                      | Watch for live updates                |
| `-o wide`                 | Extra columns (node, IP)              |
| `-o yaml`                 | Full resource definition as YAML      |
| `--previous`              | Logs from the last crashed container  |
| `-f`                      | Follow/stream logs                    |
