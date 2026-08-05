param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

Write-Host "Lab 3.2 - Security Context Lockdown using learnhub/course-service"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages -Services @("course-service")
} else {
  Assert-DockerImages -Images @("learnhub/course-service:0.1.0")
}

Ensure-DockerImage -Image "busybox:1.36"
Ensure-DockerImage -Image "curlimages/curl:8.10.1"

$Namespace = "security-lab"
$Manifest = "k8s/labs/lab-3.2-security-context-lockdown.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 3.2"

Invoke-Kubectl "apply" "-f" $Manifest
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-course-secure" "-n" $Namespace "--timeout=120s"

Invoke-Kubectl "get" "pod" "learnhub-course-secure" "-n" $Namespace "-o" "custom-columns=POD:.metadata.name,READY:.status.containerStatuses[*].ready,IMAGE:.spec.containers[*].image,STATUS:.status.phase"

$podRunAsNonRoot = Invoke-KubectlOutput "get" "pod" "learnhub-course-secure" "-n" $Namespace "-o" "jsonpath={.spec.securityContext.runAsNonRoot}"
$podRunAsUser = Invoke-KubectlOutput "get" "pod" "learnhub-course-secure" "-n" $Namespace "-o" "jsonpath={.spec.securityContext.runAsUser}"
$courseReadOnly = Invoke-KubectlOutput "get" "pod" "learnhub-course-secure" "-n" $Namespace "-o" "jsonpath={.spec.containers[0].securityContext.readOnlyRootFilesystem}"
$courseNoPrivilegeEscalation = Invoke-KubectlOutput "get" "pod" "learnhub-course-secure" "-n" $Namespace "-o" "jsonpath={.spec.containers[0].securityContext.allowPrivilegeEscalation}"
$courseCapabilityDrop = Invoke-KubectlOutput "get" "pod" "learnhub-course-secure" "-n" $Namespace "-o" "jsonpath={.spec.containers[0].securityContext.capabilities.drop[0]}"

Write-Host "SecurityContext:"
Write-Host "runAsNonRoot=$podRunAsNonRoot"
Write-Host "runAsUser=$podRunAsUser"
Write-Host "course.readOnlyRootFilesystem=$courseReadOnly"
Write-Host "course.allowPrivilegeEscalation=$courseNoPrivilegeEscalation"
Write-Host "course.capabilities.drop[0]=$courseCapabilityDrop"

Assert-OutputContains -Output $podRunAsNonRoot -Expected "true" -Context "Lab 3.2 pod runAsNonRoot"
Assert-OutputContains -Output $podRunAsUser -Expected "10001" -Context "Lab 3.2 pod runAsUser"
Assert-OutputContains -Output $courseReadOnly -Expected "true" -Context "Lab 3.2 readOnlyRootFilesystem"
Assert-OutputContains -Output $courseNoPrivilegeEscalation -Expected "false" -Context "Lab 3.2 allowPrivilegeEscalation"
Assert-OutputContains -Output $courseCapabilityDrop -Expected "ALL" -Context "Lab 3.2 capabilities drop"

Write-Host "Runtime checks from security-checker container:"
$uidOutput = Invoke-KubectlOutput "exec" "pod/learnhub-course-secure" "-n" $Namespace "-c" "security-checker" "--" "id" "-u"
Write-Host "uid=$uidOutput"
Assert-OutputContains -Output $uidOutput -Expected "10001" -Context "Lab 3.2 runtime uid"

$capOutput = Invoke-KubectlOutput "exec" "pod/learnhub-course-secure" "-n" $Namespace "-c" "security-checker" "--" "sh" "-c" "grep '^CapEff:' /proc/self/status"
$capOutput | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $capOutput -Expected "0000000000000000" -Context "Lab 3.2 effective capabilities"

$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $writeOutput = kubectl exec pod/learnhub-course-secure -n $Namespace -c security-checker -- sh -c "touch /tmp/blocked" 2>&1
  $writeExitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $oldErrorActionPreference
}
if ($writeExitCode -eq 0) {
  throw "Expected write to read-only root filesystem to fail, but it succeeded."
}
Write-Host "Write to read-only root filesystem failed as expected."
$writeOutput | ForEach-Object { Write-Host $_ }

Write-Host "Smoke test locked-down course-service:"
$response = Invoke-TemporaryCurlOutput -Name "security-client" -Namespace $Namespace -Url "http://learnhub-course-secure/healthz"
$response | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $response -Expected "course-service-secure" -Context "Lab 3.2 course-service health check"
