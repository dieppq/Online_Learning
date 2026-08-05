param(
  [string]$ManifestUrl = "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml",
  [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"

$CapstoneRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-Path (Join-Path $CapstoneRoot "..")
. (Join-Path $ProjectRoot "scripts\common.ps1")

Assert-KubernetesReady

Invoke-Kubectl "apply" "-f" $ManifestUrl
Invoke-Kubectl "wait" "--namespace" "ingress-nginx" "--for=condition=Ready" "pod" "--selector=app.kubernetes.io/component=controller" "--timeout=${TimeoutSeconds}s"
Invoke-Kubectl "get" "ingressclass"
Invoke-Kubectl "get" "pod,svc" "-n" "ingress-nginx"

Write-Host "ingress-nginx is ready."

