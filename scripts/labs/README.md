# LearnHub CKAD Lab Scripts

## Run from PowerShell

Windows already includes Windows PowerShell 5.1, which is enough to run these `.ps1` lab scripts.

Do not double-click a `.ps1` file from Explorer. Windows commonly opens it in Notepad to prevent accidental script execution.

Open PowerShell, then run from the project root:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
```

If script execution is blocked, allow it only for the current PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Run Lab 1.1:

```powershell
.\scripts\labs\run-lab-1.1.ps1
```

Or run it in one command from any PowerShell location:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\quang\Desktop\Work\CKAD\Online_Learning\scripts\labs\run-lab-1.1.ps1
```

Available scripts:

```powershell
.\scripts\labs\run-lab-1.1.ps1
.\scripts\labs\run-lab-1.2.ps1
.\scripts\labs\run-lab-1.3.ps1
.\scripts\labs\run-lab-1.4.ps1
.\scripts\labs\run-lab-2.1.ps1
.\scripts\labs\run-lab-2.2.ps1
.\scripts\labs\run-lab-2.3.ps1
.\scripts\labs\run-lab-2.4.ps1
.\scripts\labs\run-lab-3.1.ps1
.\scripts\labs\run-lab-3.2.ps1
.\scripts\labs\run-lab-3.3.ps1
.\scripts\labs\run-lab-3.4.ps1
.\scripts\labs\run-lab-4.1.ps1
.\scripts\labs\run-lab-4.2.ps1
.\scripts\labs\run-lab-4.3.ps1
.\scripts\labs\run-lab-4.4.ps1
.\scripts\labs\run-lab-5.1.ps1
.\scripts\labs\run-lab-5.2.ps1
.\scripts\labs\run-lab-5.3.ps1
.\scripts\labs\run-lab-5.4.ps1
.\scripts\labs\install-metrics-server-lab.ps1
.\scripts\labs\cleanup-lab-namespaces.ps1
```

## Full commands for each lab

Run these commands from the project root:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
```

These commands are the recommended repeat-run commands for this machine after the LearnHub images already exist locally. If this is the first run on a clean machine, remove `-SkipBuild` from the commands that include it so the script can build the required image first.

From Lab 2.1 to Lab 5.4, the lab scripts deploy and change main Kubernetes resources through YAML manifests, Kustomize, or Helm charts as much as possible. Temporary curl Pods are still used only for smoke tests and are removed automatically.

Install Metrics API for Lab 2.3 HPA and Lab 5.2 `kubectl top` on Docker Desktop:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1
```

This is lab-only setup. It patches Metrics Server with `--kubelet-insecure-tls` for Docker Desktop kubelet certificates. Remove it after lab if needed:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1 -Uninstall
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-1.1.ps1 -SkipBuild
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-1.2.ps1 -SkipBuild
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-1.3.ps1 -SkipBuild -SkipLearnHubDeploy
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-1.4.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120

powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.1.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.2.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.4.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120

powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-3.1.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-3.2.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-3.3.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-3.4.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120

powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-4.1.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-4.2.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-4.3.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-4.4.ps1 -NamespaceDeleteTimeoutSeconds 120

powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-5.1.ps1 -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-5.2.ps1 -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-5.3.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-5.4.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
```

run before lab 5.2
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1


If Lab 1.3 is run without running Lab 1.2 or `scripts/deploy.ps1` first, use this command instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-1.3.ps1 -SkipBuild
```

If Lab 4.3 must fail when the cluster does not enforce NetworkPolicy, use:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-4.3.ps1 -SkipBuild -RequireNetworkPolicyEnforcement -NamespaceDeleteTimeoutSeconds 120
```

If Lab 2.3 should create CPU load for HPA observation, use:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -CreateLoad -LoadClients 8 -BurnMilliseconds 750 -LoadDurationSeconds 180 -NamespaceDeleteTimeoutSeconds 120
```

If Lab 2.3 should fail when HPA does not scale under load, use:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -CreateLoad -RequireHpaScale -LoadClients 8 -BurnMilliseconds 750 -LoadDurationSeconds 180 -NamespaceDeleteTimeoutSeconds 120
```

To keep the Lab 2.3 load generator Pods running and delete them later:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -CreateLoad -KeepLoad -LoadDurationSeconds 0 -NamespaceDeleteTimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -DeleteLoad
```

If Helm is not in PATH and the local portable Helm exists, Lab 5.4 can also be run explicitly with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-5.4.ps1 -SkipBuild -HelmPath .\.tools\helm\windows-amd64\helm.exe -NamespaceDeleteTimeoutSeconds 120
```

Common options:

```powershell
-SkipBuild
-NamespaceDeleteTimeoutSeconds 120
```

For labs 1.2 and 1.3:

```powershell
-SkipLearnHubDeploy
```

Use `-SkipBuild` when the `learnhub/*` images already exist locally.
Use `-SkipLearnHubDeploy` when namespace `learnhub-lab` already has the Online Learning services running.
Use `-NamespaceDeleteTimeoutSeconds` for Lab 1.4, Lab 2.x, Lab 3.x, and Lab 4.x if Docker Desktop needs more time to delete an old lab namespace.
Use `-RequireNetworkPolicyEnforcement` with Lab 4.3 when the script must fail on clusters whose CNI does not enforce NetworkPolicy.
Use `-HelmPath` with Lab 5.4 when Helm is not in PATH.

Each lab script now checks Docker and Kubernetes before changing resources. When `-SkipBuild` is used, the script verifies the required local `learnhub/*` images are already present. Scripts that call APIs also run a smoke test against the Online Learning service response.

Example:

```powershell
.\scripts\labs\run-lab-1.1.ps1 -SkipBuild
.\scripts\labs\run-lab-1.4.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
.\scripts\labs\run-lab-2.1.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
.\scripts\labs\run-lab-3.1.ps1 -SkipBuild
.\scripts\labs\run-lab-3.4.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
.\scripts\labs\run-lab-4.1.ps1 -SkipBuild
.\scripts\labs\run-lab-4.3.ps1 -SkipBuild
.\scripts\labs\run-lab-5.3.ps1 -SkipBuild
.\scripts\labs\run-lab-5.4.ps1 -SkipBuild
```

Cleanup is handled at the start of each isolated lab script where the lab needs temporary resources. After finishing a lab, use the cleanup commands in `docs/lab-run-verify-cleanup.md`.

To remove all lab namespaces while keeping the shared LearnHub app namespace:

```powershell
.\scripts\labs\cleanup-lab-namespaces.ps1 -Wait -TimeoutSeconds 120
```

To remove the shared `learnhub-lab` namespace too:

```powershell
.\scripts\labs\cleanup-lab-namespaces.ps1 -IncludeLearnHub -Wait -TimeoutSeconds 120
```
