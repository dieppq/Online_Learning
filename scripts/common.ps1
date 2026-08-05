$ErrorActionPreference = "Stop"
$LearnHubScriptsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Assert-CommandAvailable {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found in PATH."
  }
}

function Invoke-External {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgumentList
  )

  & $FilePath @ArgumentList
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw "$FilePath failed with exit code $exitCode. Args: $($ArgumentList -join ' ')"
  }
}

function Invoke-ExternalOutput {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgumentList
  )

  $output = & $FilePath @ArgumentList
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw "$FilePath failed with exit code $exitCode. Args: $($ArgumentList -join ' ')"
  }

  return $output
}

function Invoke-Kubectl {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgumentList
  )

  Invoke-External "kubectl" @ArgumentList
}

function Invoke-KubectlOutput {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgumentList
  )

  Invoke-ExternalOutput "kubectl" @ArgumentList
}

function Invoke-KubectlOutputOrEmpty {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgumentList
  )

  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"

  try {
    $output = & kubectl @ArgumentList 2>$null
    if ($LASTEXITCODE -ne 0) {
      return ""
    }

    return $output
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
  }
}

function Invoke-Docker {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgumentList
  )

  Invoke-External "docker" @ArgumentList
}

function Assert-DockerReady {
  Assert-CommandAvailable "docker"
  Invoke-Docker "version" "--format" "Docker client {{.Client.Version}}, server {{.Server.Version}}"
}

function Assert-KubernetesReady {
  Assert-CommandAvailable "kubectl"
  Invoke-Kubectl "version" "--client=true" "--output=yaml"

  $context = Invoke-KubectlOutput "config" "current-context"
  Write-Host "kubectl context: $context"

  Invoke-Kubectl "get" "nodes" "--request-timeout=10s"
}

function Test-DockerImage {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )

  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"

  try {
    & docker image inspect $Image *> $null
    return ($LASTEXITCODE -eq 0)
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
  }
}

function Ensure-DockerImage {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )

  if (Test-DockerImage -Image $Image) {
    Write-Host "Image already present: $Image"
    return
  }

  Invoke-Docker "pull" $Image
}

function Assert-DockerImages {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Images,

    [string]$Hint = "Run the lab script without -SkipBuild."
  )

  foreach ($image in $Images) {
    if (-not (Test-DockerImage -Image $image)) {
      throw "Required local image is missing: $image. $Hint"
    }
  }
}

function Build-LearnHubImages {
  param(
    [string[]]$Tags = @("0.1.0"),
    [string[]]$Services = @()
  )

  $buildScript = Join-Path $LearnHubScriptsRoot "build-images.ps1"

  foreach ($tag in $Tags) {
    if ($Services.Count -gt 0) {
      & $buildScript -Tag $tag -Services $Services
    } else {
      & $buildScript -Tag $tag
    }

    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
      throw "$buildScript failed with exit code $exitCode for tag $tag."
    }
  }
}

function Wait-NamespaceDeleted {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [Parameter(Mandatory = $true)]
    [int]$TimeoutSeconds
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

  while ((Get-Date) -lt $deadline) {
    $namespaceName = Invoke-KubectlOutput "get" "namespace" $Namespace "-o" "name" "--ignore-not-found"

    if ([string]::IsNullOrWhiteSpace($namespaceName)) {
      Write-Host "Namespace $Namespace is deleted."
      return
    }

    $phase = Invoke-KubectlOutputOrEmpty "get" "namespace" $Namespace "-o" "jsonpath={.status.phase}"
    if ([string]::IsNullOrWhiteSpace($phase)) {
      Write-Host "Namespace $Namespace is deleted."
      return
    }

    Write-Host "Waiting for namespace $Namespace to be deleted... phase=$phase"
    Start-Sleep -Seconds 2
  }

  Write-Warning "Namespace $Namespace was not deleted within $TimeoutSeconds seconds."
  Write-Host ""
  Write-Host "Debug commands:"
  Write-Host "kubectl get namespace $Namespace -o yaml"
  Write-Host "kubectl get all -n $Namespace"
  Write-Host "kubectl describe namespace $Namespace"
  Write-Host ""

  Invoke-Kubectl "get" "namespace" $Namespace "-o" "yaml"
  Invoke-Kubectl "get" "all" "-n" $Namespace

  throw "Namespace $Namespace is still terminating. Check finalizers/events or restart Docker Desktop Kubernetes, then rerun this script."
}

function Test-NamespaceExists {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Namespace
  )

  $existingNamespace = Invoke-KubectlOutput "get" "namespace" $Namespace "-o" "name" "--ignore-not-found"
  return (-not [string]::IsNullOrWhiteSpace($existingNamespace))
}

function Reset-LabNamespace {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [Parameter(Mandatory = $true)]
    [int]$TimeoutSeconds,

    [Parameter(Mandatory = $true)]
    [string]$LabName
  )

  if (-not (Test-NamespaceExists -Namespace $Namespace)) {
    return
  }

  Write-Host "Cleaning previous $LabName namespace: $Namespace"
  Invoke-Kubectl "delete" "namespace" $Namespace "--ignore-not-found" "--wait=false"
  Wait-NamespaceDeleted -Namespace $Namespace -TimeoutSeconds $TimeoutSeconds
}

function Remove-PodIfExists {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Namespace
  )

  Invoke-Kubectl "delete" "pod" $Name "-n" $Namespace "--ignore-not-found" "--wait=true"
}

function Invoke-TemporaryCurl {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [Parameter(Mandatory = $true)]
    [string]$Url
  )

  $output = Invoke-TemporaryCurlOutput -Name $Name -Namespace $Namespace -Url $Url
  $output | ForEach-Object { Write-Host $_ }
}

function Invoke-TemporaryCurlOutput {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [Parameter(Mandatory = $true)]
    [string]$Url,

    [string[]]$Headers = @(),

    [string[]]$ExtraCurlArgs = @(),

    [int]$TimeoutSeconds = 90
  )

  Remove-PodIfExists -Name $Name -Namespace $Namespace

  $curlArgs = @("curl", "--fail", "--silent", "--show-error")
  foreach ($header in $Headers) {
    $curlArgs += @("-H", $header)
  }
  $curlArgs += $ExtraCurlArgs
  $curlArgs += $Url

  Invoke-Kubectl "run" $Name `
    "--restart=Never" `
    "--image=curlimages/curl:8.10.1" `
    "-n" $Namespace `
    "--command" `
    "--" @curlArgs

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $phase = ""

  while ((Get-Date) -lt $deadline) {
    $phase = Invoke-KubectlOutputOrEmpty "get" "pod" $Name "-n" $Namespace "-o" "jsonpath={.status.phase}"
    if ($phase -eq "Succeeded" -or $phase -eq "Failed") {
      break
    }

    Start-Sleep -Seconds 2
  }

  $output = Invoke-KubectlOutputOrEmpty "logs" $Name "-n" $Namespace

  if ($phase -ne "Succeeded") {
    Write-Host "Temporary curl Pod phase: $phase"
    Invoke-Kubectl "describe" "pod" $Name "-n" $Namespace
    $output | ForEach-Object { Write-Host $_ }
    Remove-PodIfExists -Name $Name -Namespace $Namespace
    throw "Temporary curl Pod $Name did not succeed within $TimeoutSeconds seconds."
  }

  Remove-PodIfExists -Name $Name -Namespace $Namespace
  return $output
}

function Assert-OutputContains {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Output,

    [Parameter(Mandatory = $true)]
    [string]$Expected,

    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  $text = ($Output | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "$Context did not contain expected text '$Expected'."
  }
}

function Assert-LearnHubServicesReady {
  param(
    [int]$TimeoutSeconds = 120
  )

  $deployments = @(
    "user-service",
    "course-service",
    "enrollment-service",
    "payment-service",
    "notification-service"
  )

  foreach ($deployment in $deployments) {
    Invoke-Kubectl "rollout" "status" "deployment/$deployment" "-n" "learnhub-lab" "--timeout=${TimeoutSeconds}s"
  }

  Invoke-Kubectl "get" "deploy,svc,pod" "-n" "learnhub-lab"
  Invoke-Kubectl "get" "endpoints" "-n" "learnhub-lab" "user-service" "course-service" "enrollment-service" "payment-service" "notification-service"
}
