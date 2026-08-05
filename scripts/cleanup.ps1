$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"

Assert-KubernetesReady
Invoke-Kubectl "delete" "namespace" "learnhub-lab" "--ignore-not-found"
