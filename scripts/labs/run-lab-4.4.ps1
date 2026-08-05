param(
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

function Wait-PvcBound {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [int]$TimeoutSeconds = 120
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $phase = Invoke-KubectlOutputOrEmpty "get" "pvc" $Name "-n" $Namespace "-o" "jsonpath={.status.phase}"
    if ($phase -eq "Bound") {
      return
    }

    Write-Host "Waiting for PVC $Name to bind... phase=$phase"
    Start-Sleep -Seconds 2
  }

  Invoke-Kubectl "describe" "pvc" $Name "-n" $Namespace
  throw "PVC $Name did not become Bound within $TimeoutSeconds seconds."
}

Write-Host "Lab 4.4 - PersistentVolumeClaim dynamic provisioning and persistence"

Assert-DockerReady
Assert-KubernetesReady
Ensure-DockerImage -Image "busybox:1.36"

$Namespace = "storage-lab"
$PvcManifest = "k8s/labs/lab-4.4-pvc.yaml"
$WriterManifest = "k8s/labs/lab-4.4-pvc-writer-pod.yaml"
$ReaderManifest = "k8s/labs/lab-4.4-pvc-reader-pod.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 4.4"

Write-Host "Available StorageClasses:"
Invoke-Kubectl "get" "storageclass"

Invoke-Kubectl "apply" "-f" $PvcManifest

Write-Host "Creating writer Pod and writing LearnHub course progress into the PVC."
Write-Host "The default Docker Desktop StorageClass uses WaitForFirstConsumer, so the PVC binds after this Pod is scheduled."
Invoke-Kubectl "apply" "-f" $WriterManifest
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-pvc-writer" "-n" $Namespace "--timeout=120s"
Wait-PvcBound -Name "learnhub-course-cache" -Namespace $Namespace -TimeoutSeconds 120
Invoke-Kubectl "get" "pvc,pv" "-n" $Namespace
$writerData = Invoke-KubectlOutput "exec" "pod/learnhub-pvc-writer" "-n" $Namespace "-c" "writer" "--" "cat" "/data/courses/progress.txt"
$writerData | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $writerData -Expected "course_id=c-k8s-ckad" -Context "Lab 4.4 writer PVC data"

Write-Host "Deleting writer Pod while keeping the PVC."
Invoke-Kubectl "delete" "pod" "learnhub-pvc-writer" "-n" $Namespace "--wait=true"

Write-Host "Recreating a reader Pod with the same PVC and verifying persistence."
Invoke-Kubectl "apply" "-f" $ReaderManifest
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-pvc-reader" "-n" $Namespace "--timeout=120s"
$readerData = Invoke-KubectlOutput "exec" "pod/learnhub-pvc-reader" "-n" $Namespace "-c" "reader" "--" "cat" "/data/courses/progress.txt"
$readerData | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $readerData -Expected "course_id=c-k8s-ckad" -Context "Lab 4.4 reader PVC data"
Assert-OutputContains -Output $readerData -Expected "status=persisted" -Context "Lab 4.4 persistence check"

Invoke-Kubectl "get" "pod,pvc" "-n" $Namespace "-o" "wide"
