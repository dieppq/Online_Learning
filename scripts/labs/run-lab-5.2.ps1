param(
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

function Wait-CrashyPreviousLogs {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [int]$TimeoutSeconds = 90
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $restartCountText = Invoke-KubectlOutputOrEmpty "get" "pod" "learnhub-observe-pod" "-n" $Namespace "-o" "jsonpath={.status.containerStatuses[?(@.name=='crashy')].restartCount}"
    if (-not [string]::IsNullOrWhiteSpace($restartCountText) -and [int]$restartCountText -gt 0) {
      $previous = Invoke-KubectlOutputOrEmpty "logs" "learnhub-observe-pod" "-n" $Namespace "-c" "crashy" "--previous"
      if (($previous | Out-String).Contains("crashy container attempt")) {
        return $previous
      }
    }

    Start-Sleep -Seconds 2
  }

  Invoke-Kubectl "describe" "pod" "learnhub-observe-pod" "-n" $Namespace
  throw "Previous logs for crashy container were not available within $TimeoutSeconds seconds."
}

Write-Host "Lab 5.2 - CLI Observability with logs, previous logs, events, and kubectl top"

Assert-DockerReady
Assert-KubernetesReady
Ensure-DockerImage -Image "busybox:1.36"

$Namespace = "observability-lab"
$Manifest = "k8s/labs/lab-5.2-cli-observability.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 5.2"

Invoke-Kubectl "apply" "-f" $Manifest
$previousLogs = Wait-CrashyPreviousLogs -Namespace $Namespace -TimeoutSeconds 90

Invoke-Kubectl "get" "pod" "learnhub-observe-pod" "-n" $Namespace "-o" "custom-columns=POD:.metadata.name,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,STATUS:.status.phase"

Write-Host "kubectl logs -c main:"
$mainLogs = Invoke-KubectlOutput "logs" "learnhub-observe-pod" "-n" $Namespace "-c" "main" "--tail=5"
$mainLogs | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $mainLogs -Expected "main container heartbeat" -Context "Lab 5.2 main container logs"

Write-Host "kubectl logs -c crashy --previous:"
$previousLogs | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $previousLogs -Expected "simulated bug" -Context "Lab 5.2 previous logs"

Write-Host "Events from kubectl describe:"
$describeOutput = Invoke-KubectlOutput "describe" "pod" "learnhub-observe-pod" "-n" $Namespace
$describeOutput | Select-String "Events:|BackOff|Killing|Started|crashy" | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $describeOutput -Expected "crashy" -Context "Lab 5.2 describe pod"

Write-Host "Events from kubectl get events:"
$eventsOutput = Invoke-KubectlOutput "get" "events" "-n" $Namespace "--sort-by=.lastTimestamp"
$eventsOutput | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $eventsOutput -Expected "learnhub-observe-pod" -Context "Lab 5.2 get events"

Write-Host "kubectl top pod:"
$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $topOutput = kubectl top pod -n $Namespace 2>&1
  $topExitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $oldErrorActionPreference
}

if ($topExitCode -eq 0) {
  $topOutput | ForEach-Object { Write-Host $_ }
  Assert-OutputContains -Output $topOutput -Expected "learnhub-observe-pod" -Context "Lab 5.2 kubectl top pod"
} else {
  Write-Warning "Metrics API is not ready. kubectl top was executed, but Docker Desktop currently reports metrics as unavailable."
  $topOutput | ForEach-Object { Write-Host $_ }
}
