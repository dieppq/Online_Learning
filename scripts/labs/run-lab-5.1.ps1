param(
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

function Get-ProbePodName {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Namespace
  )

  Invoke-KubectlOutput "get" "pod" "-n" $Namespace "-l" "app=learnhub-self-healing" "-o" "jsonpath={.items[0].metadata.name}"
}

function Wait-ContainerRestart {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Pod,

    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [Parameter(Mandatory = $true)]
    [int]$InitialRestartCount,

    [int]$TimeoutSeconds = 90
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $restartCountText = Invoke-KubectlOutputOrEmpty "get" "pod" $Pod "-n" $Namespace "-o" "jsonpath={.status.containerStatuses[0].restartCount}"
    if (-not [string]::IsNullOrWhiteSpace($restartCountText)) {
      $restartCount = [int]$restartCountText
      if ($restartCount -gt $InitialRestartCount) {
        Write-Host "Container restarted: initial=$InitialRestartCount current=$restartCount"
        return
      }
    }

    Start-Sleep -Seconds 2
  }

  Invoke-Kubectl "describe" "pod" $Pod "-n" $Namespace
  throw "Container did not restart within $TimeoutSeconds seconds."
}

Write-Host "Lab 5.1 - Self-Healing App with liveness, readiness, and startup probes"

Assert-DockerReady
Assert-KubernetesReady
Ensure-DockerImage -Image "busybox:1.36"
Ensure-DockerImage -Image "curlimages/curl:8.10.1"

$Namespace = "probe-lab"
$Manifest = "k8s/labs/lab-5.1-self-healing-app.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 5.1"

Invoke-Kubectl "apply" "-f" $Manifest
Invoke-Kubectl "rollout" "status" "deployment/learnhub-self-healing" "-n" $Namespace "--timeout=120s"

$pod = Get-ProbePodName -Namespace $Namespace
Invoke-Kubectl "get" "pod" $pod "-n" $Namespace "-o" "custom-columns=POD:.metadata.name,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,STATUS:.status.phase"

$probeConfig = Invoke-KubectlOutput "get" "deployment" "learnhub-self-healing" "-n" $Namespace "-o" "jsonpath={.spec.template.spec.containers[0].startupProbe.httpGet.path}{' '}{.spec.template.spec.containers[0].livenessProbe.httpGet.path}{' '}{.spec.template.spec.containers[0].readinessProbe.exec.command}"
$probeConfig | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $probeConfig -Expected "/healthz" -Context "Lab 5.1 HTTP startup/liveness probe"
Assert-OutputContains -Output $probeConfig -Expected "test -f /tmp/ready" -Context "Lab 5.1 file-based readiness probe"

Write-Host "Calling app through Service before inducing liveness failure:"
$beforeResponse = Invoke-TemporaryCurlOutput -Name "probe-client-before" -Namespace $Namespace -Url "http://learnhub-self-healing/"
$beforeResponse | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $beforeResponse -Expected "course_id=c-k8s-ckad" -Context "Lab 5.1 initial service response"

$initialRestartCount = [int](Invoke-KubectlOutput "get" "pod" $pod "-n" $Namespace "-o" "jsonpath={.status.containerStatuses[0].restartCount}")
Write-Host "Removing /www/healthz so HTTP liveness probe fails and kubelet restarts the container."
Invoke-Kubectl "exec" "pod/$pod" "-n" $Namespace "-c" "probe-app" "--" "rm" "/www/healthz"

Wait-ContainerRestart -Pod $pod -Namespace $Namespace -InitialRestartCount $initialRestartCount -TimeoutSeconds 90
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/$pod" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "get" "pod" $pod "-n" $Namespace "-o" "custom-columns=POD:.metadata.name,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,STATUS:.status.phase"

Write-Host "Calling app after self-healing restart:"
$afterResponse = Invoke-TemporaryCurlOutput -Name "probe-client-after" -Namespace $Namespace -Url "http://learnhub-self-healing/"
$afterResponse | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $afterResponse -Expected "course_id=c-k8s-ckad" -Context "Lab 5.1 service response after restart"
