param(
  [string]$Namespace = "learnhub-capstone-dev",
  [string]$CurlImage = "curlimages/curl:8.10.1"
)

$ErrorActionPreference = "Stop"

$CapstoneRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-Path (Join-Path $CapstoneRoot "..")
. (Join-Path $ProjectRoot "scripts\common.ps1")
$SmokePodName = "capstone-smoke-client"

function Start-SmokeClient {
  Invoke-Kubectl "delete" "pod" $SmokePodName "-n" $Namespace "--ignore-not-found" "--wait=true"
  Invoke-Kubectl "run" $SmokePodName `
    "--restart=Never" `
    "--image=$CurlImage" `
    "-n" $Namespace `
    "--labels=app.kubernetes.io/part-of=learnhub,app.kubernetes.io/component=smoke-test" `
    "--command" `
    "--" "sleep" "1800"
  Invoke-Kubectl "wait" "--for=condition=Ready" "pod/$SmokePodName" "-n" $Namespace "--timeout=90s"
}

function Remove-SmokeClient {
  Invoke-Kubectl "delete" "pod" $SmokePodName "-n" $Namespace "--ignore-not-found" "--wait=true"
}

function Invoke-CapstoneCurl {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Url,

    [string[]]$CurlArgs = @()
  )

  Write-Host "==> $Name"
  $kubectlArgs = @(
    "exec", $SmokePodName,
    "-n", $Namespace,
    "--", "curl", "--fail", "--silent", "--show-error", "--connect-timeout", "5", "--max-time", "20"
  ) + $CurlArgs + @($Url)
  $output = Invoke-KubectlOutput @kubectlArgs
  $output | ForEach-Object { Write-Host $_ }
}

$deployments = @(
  "user-postgresql",
  "course-postgresql",
  "enrollment-postgresql",
  "payment-postgresql",
  "notification-postgresql",
  "redis",
  "nats",
  "minio",
  "web-ui",
  "user-service",
  "course-service-blue",
  "course-service-green",
  "enrollment-service",
  "payment-service",
  "notification-service"
)

foreach ($deployment in $deployments) {
  Invoke-Kubectl "rollout" "status" "deployment/$deployment" "-n" $Namespace "--timeout=180s"
}

$migrationJobs = @(
  "user-db-migrate-v001",
  "course-db-migrate-v001",
  "enrollment-db-migrate-v001",
  "payment-db-migrate-v001",
  "notification-db-migrate-v001",
  "user-db-migrate-v002",
  "course-db-migrate-v002",
  "enrollment-db-migrate-v002",
  "payment-db-migrate-v002",
  "notification-db-migrate-v002",
  "course-db-migrate-v003",
  "enrollment-db-migrate-v003",
  "payment-db-migrate-v003"
)

foreach ($job in $migrationJobs) {
  Invoke-Kubectl "wait" "--for=condition=complete" "job/$job" "-n" $Namespace "--timeout=180s"
}

Invoke-Kubectl "wait" "--for=condition=complete" "job/learnhub-database-secret-check" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "wait" "--for=condition=complete" "job/learnhub-pvc-writer" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "wait" "--for=condition=complete" "job/learnhub-pvc-reader-v2" "-n" $Namespace "--timeout=120s"

Start-SmokeClient
try {
  Invoke-CapstoneCurl -Name "users" -Url "http://user-service/api/users"
  Invoke-CapstoneCurl -Name "web-ui" -Url "http://web-ui/"
  Invoke-CapstoneCurl -Name "courses" -Url "http://course-service/api/courses"
  Invoke-CapstoneCurl -Name "progress" -Url "http://enrollment-service/api/progress/u-1001/c-k8s-ckad"
  Invoke-CapstoneCurl -Name "payment" -Url "http://payment-service/api/payments/p-1001"
  Invoke-CapstoneCurl -Name "notification" -Url "http://notification-service/api/notifications"
  Invoke-CapstoneCurl -Name "metrics" -Url "http://user-service/metrics"
  Invoke-CapstoneCurl -Name "jetstream" -Url "http://nats:8222/jsz?streams=true"
  Invoke-CapstoneCurl -Name "minio-upload" -Url "http://course-service/api/courses/c-k8s-ckad/lessons/l-01/content" -CurlArgs @("-X", "PUT", "-H", "Content-Type: text/plain", "--data-binary", "LearnHub MinIO content proof")
  Invoke-CapstoneCurl -Name "minio-read" -Url "http://course-service/api/courses/c-k8s-ckad/lessons/l-01/content"
  Invoke-CapstoneCurl -Name "cache-prime" -Url "http://enrollment-service/api/progress/u-1001/c-k8s-ckad" -CurlArgs @("-D", "-")
  Invoke-CapstoneCurl -Name "cache-hit" -Url "http://enrollment-service/api/progress/u-1001/c-k8s-ckad" -CurlArgs @("-D", "-")
  Invoke-CapstoneCurl -Name "confirm-payment" -Url "http://payment-service/api/payments/p-1001/confirm" -CurlArgs @("-X", "POST")
  Start-Sleep -Seconds 3
  Invoke-CapstoneCurl -Name "event-enrollment" -Url "http://enrollment-service/api/users/u-1001/courses"
  Invoke-CapstoneCurl -Name "event-notification" -Url "http://notification-service/api/notifications"
} finally {
  Remove-SmokeClient
}

Invoke-Kubectl "get" "deploy,pod,svc,endpoints,ingress,hpa,pvc" "-n" $Namespace
Invoke-Kubectl "logs" "job/learnhub-database-secret-check" "-n" $Namespace
Invoke-Kubectl "logs" "job/learnhub-pvc-writer" "-n" $Namespace
Invoke-Kubectl "logs" "job/learnhub-pvc-reader-v2" "-n" $Namespace

foreach ($job in $migrationJobs) {
  Invoke-Kubectl "logs" "job/$job" "-n" $Namespace
}

& kubectl top pod -n $Namespace
if ($LASTEXITCODE -ne 0) {
  Write-Warning "kubectl top failed. Check metrics-server before the HPA demo."
}

Write-Host "Capstone smoke test finished."
