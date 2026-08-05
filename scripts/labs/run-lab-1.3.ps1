param(
  [switch]$SkipBuild,
  [switch]$SkipLearnHubDeploy
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

Write-Host "Lab 1.3 - Jobs & CronJobs using real LearnHub APIs"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages
} else {
  Assert-DockerImages -Images @(
    "learnhub/user-service:0.1.0",
    "learnhub/course-service:0.1.0",
    "learnhub/enrollment-service:0.1.0",
    "learnhub/payment-service:0.1.0",
    "learnhub/notification-service:0.1.0"
  )
}

if (-not $SkipLearnHubDeploy) {
  & "$ProjectRoot\scripts\deploy.ps1"
}

Assert-LearnHubServicesReady
Ensure-DockerImage -Image "curlimages/curl:8.10.1"

if (Test-NamespaceExists -Namespace "ckad-lab") {
  Invoke-Kubectl "delete" "cronjob" "learnhub-reminder-cronjob" "-n" "ckad-lab" "--ignore-not-found"
  Invoke-Kubectl "delete" "job" "-n" "ckad-lab" "-l" "lab=1.3" "--ignore-not-found"
  Invoke-Kubectl "delete" "job" "learnhub-reminder-manual" "-n" "ckad-lab" "--ignore-not-found"
}

Invoke-Kubectl "apply" "-f" "k8s/labs/lab-1.3-jobs-cronjobs.yaml"
Invoke-Kubectl "wait" "--for=condition=complete" "job/learnhub-daily-report" "-n" "ckad-lab" "--timeout=120s"

Write-Host "One-off Job logs:"
$dailyReportLogs = Invoke-KubectlOutput "logs" "job/learnhub-daily-report" "-n" "ckad-lab"
$dailyReportLogs | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $dailyReportLogs -Expected "LearnHub one-off report finished" -Context "Lab 1.3 one-off Job"

Write-Host "Waiting for one scheduled CronJob child Job..."
$deadline = (Get-Date).AddSeconds(90)
$childJob = ""
while ((Get-Date) -lt $deadline -and [string]::IsNullOrWhiteSpace($childJob)) {
  Start-Sleep -Seconds 5
  $childJob = Invoke-KubectlOutputOrEmpty "get" "jobs" "-n" "ckad-lab" "-l" "workload=cronjob-child" "-o" "jsonpath={.items[0].metadata.name}"
}

if ([string]::IsNullOrWhiteSpace($childJob)) {
  Write-Host "No scheduled child Job appeared within 90s. Creating one manually from the CronJob template."
  Invoke-Kubectl "create" "job" "learnhub-reminder-manual" "--from=cronjob/learnhub-reminder-cronjob" "-n" "ckad-lab"
  $childJob = "learnhub-reminder-manual"
}

Invoke-Kubectl "wait" "--for=condition=complete" "job/$childJob" "-n" "ckad-lab" "--timeout=120s"

Write-Host "CronJob child logs:"
$cronJobLogs = Invoke-KubectlOutput "logs" "job/$childJob" "-n" "ckad-lab"
$cronJobLogs | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $cronJobLogs -Expected "LearnHub scheduled reminder finished" -Context "Lab 1.3 CronJob child Job"

Write-Host "Suspending CronJob to avoid creating Jobs every minute."
Invoke-Kubectl "patch" "cronjob" "learnhub-reminder-cronjob" "-n" "ckad-lab" "--type" "merge" "--patch-file" "k8s/labs/lab-1.3-suspend-cronjob-patch.json"

Invoke-Kubectl "get" "job,cronjob,pod" "-n" "ckad-lab" "-l" "lab=1.3"
