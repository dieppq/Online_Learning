param(
  [string]$Namespace = "learnhub-capstone-dev",
  [string]$CurlImage = "curlimages/curl:8.10.1"
)

$ErrorActionPreference = "Stop"

$CapstoneRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-Path (Join-Path $CapstoneRoot "..")
. (Join-Path $ProjectRoot "scripts\common.ps1")

function Invoke-CapstoneCurl {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Url
  )

  Invoke-Kubectl "delete" "pod" $Name "-n" $Namespace "--ignore-not-found" "--wait=true"

  Invoke-Kubectl "run" $Name `
    "--restart=Never" `
    "--image=$CurlImage" `
    "-n" $Namespace `
    "--labels=app.kubernetes.io/part-of=learnhub,app.kubernetes.io/component=smoke-test" `
    "--command" `
    "--" "curl" "--fail" "--silent" "--show-error" $Url

  $deadline = (Get-Date).AddSeconds(90)
  $phase = ""

  while ((Get-Date) -lt $deadline) {
    $phase = Invoke-KubectlOutputOrEmpty "get" "pod" $Name "-n" $Namespace "-o" "jsonpath={.status.phase}"
    if ($phase -eq "Succeeded" -or $phase -eq "Failed") {
      break
    }

    Start-Sleep -Seconds 2
  }

  $output = Invoke-KubectlOutputOrEmpty "logs" $Name "-n" $Namespace
  $output | ForEach-Object { Write-Host $_ }

  if ($phase -ne "Succeeded") {
    Invoke-Kubectl "describe" "pod" $Name "-n" $Namespace
    Invoke-Kubectl "delete" "pod" $Name "-n" $Namespace "--ignore-not-found" "--wait=true"
    throw "Smoke test Pod $Name failed with phase '$phase'."
  }

  Invoke-Kubectl "delete" "pod" $Name "-n" $Namespace "--ignore-not-found" "--wait=true"
}

$deployments = @(
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

Invoke-Kubectl "wait" "--for=condition=complete" "job/learnhub-secret-check" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "wait" "--for=condition=complete" "job/learnhub-pvc-writer" "-n" $Namespace "--timeout=120s"

Invoke-CapstoneCurl -Name "capstone-curl-users" -Url "http://user-service/api/users"
Invoke-CapstoneCurl -Name "capstone-curl-web-ui" -Url "http://web-ui/"
Invoke-CapstoneCurl -Name "capstone-curl-courses" -Url "http://course-service/api/courses"
Invoke-CapstoneCurl -Name "capstone-curl-progress" -Url "http://enrollment-service/api/progress/u-1001/c-k8s-ckad"
Invoke-CapstoneCurl -Name "capstone-curl-payment" -Url "http://payment-service/api/payments/p-1001"
Invoke-CapstoneCurl -Name "capstone-curl-notify" -Url "http://notification-service/api/notifications"

Invoke-Kubectl "get" "deploy,pod,svc,endpoints,ingress,hpa,pvc" "-n" $Namespace
Invoke-Kubectl "logs" "job/learnhub-secret-check" "-n" $Namespace
Invoke-Kubectl "logs" "job/learnhub-pvc-writer" "-n" $Namespace

& kubectl top pod -n $Namespace
if ($LASTEXITCODE -ne 0) {
  Write-Warning "kubectl top failed. Check metrics-server before the HPA demo."
}

Write-Host "Capstone smoke test finished."
