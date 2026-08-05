$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"

Assert-KubernetesReady

Invoke-Kubectl "get" "deploy,rs,pod,svc" "-n" "learnhub-lab"
Invoke-Kubectl "get" "configmap,secret" "-n" "learnhub-lab"
Invoke-Kubectl "get" "pvc" "-n" "learnhub-lab"
Invoke-Kubectl "get" "ingress" "-n" "learnhub-lab"

Write-Host ""
Write-Host "Recent user-service main logs"
Invoke-Kubectl "logs" "deploy/user-service" "-n" "learnhub-lab" "-c" "main" "--tail=20"

Write-Host ""
Write-Host "Recent user-service ambassador logs from log-sidecar"
Invoke-Kubectl "logs" "deploy/user-service" "-n" "learnhub-lab" "-c" "log-sidecar" "--tail=20"

Write-Host ""
Write-Host "Describe one user-service Pod"
$pod = Invoke-KubectlOutput "get" "pod" "-n" "learnhub-lab" "-l" "app.kubernetes.io/name=user-service" "-o" "jsonpath={.items[0].metadata.name}"
Invoke-Kubectl "describe" "pod" $pod "-n" "learnhub-lab"
