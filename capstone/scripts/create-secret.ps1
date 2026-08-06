param(
  [string]$Namespace = "learnhub-capstone-dev",
  [string]$Name = "learnhub-secret",
  [string]$PostgresDb = "learnhub",
  [string]$PostgresUser = "learnhub",
  [string]$PostgresPassword = "",
  [string]$JwtSecret = "",
  [string]$MinioRootUser = "learnhub",
  [string]$MinioRootPassword = "",
  [string]$SmtpUsername = "learnhub",
  [string]$SmtpPassword = ""
)

$ErrorActionPreference = "Stop"

function New-RandomSecret {
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $bytes = New-Object byte[] 24
  $rng.GetBytes($bytes)
  return [Convert]::ToBase64String($bytes)
}

function Get-ExistingSecretValue {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SecretName,

    [Parameter(Mandatory = $true)]
    [string]$Key
  )

  $encodedValue = & kubectl get secret $SecretName -n $Namespace --ignore-not-found -o "jsonpath={.data.$Key}" 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($encodedValue)) {
    return ""
  }

  return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encodedValue))
}

$namespaceYaml = & kubectl create namespace $Namespace --dry-run=client -o yaml
if ($LASTEXITCODE -ne 0) {
  throw "kubectl create namespace dry-run failed."
}

$namespaceYaml | & kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
  throw "kubectl apply namespace $Namespace failed."
}

if ([string]::IsNullOrWhiteSpace($JwtSecret)) {
  $JwtSecret = Get-ExistingSecretValue -SecretName $Name -Key "JWT_SECRET"
  if ([string]::IsNullOrWhiteSpace($JwtSecret)) {
    $JwtSecret = New-RandomSecret
  }
}
if ([string]::IsNullOrWhiteSpace($MinioRootPassword)) {
  $MinioRootPassword = Get-ExistingSecretValue -SecretName $Name -Key "MINIO_ROOT_PASSWORD"
  if ([string]::IsNullOrWhiteSpace($MinioRootPassword)) {
    $MinioRootPassword = New-RandomSecret
  }
}
if ([string]::IsNullOrWhiteSpace($SmtpPassword)) {
  $SmtpPassword = Get-ExistingSecretValue -SecretName $Name -Key "SMTP_PASSWORD"
  if ([string]::IsNullOrWhiteSpace($SmtpPassword)) {
    $SmtpPassword = New-RandomSecret
  }
}

$literalArgs = @(
  "--from-literal=JWT_SECRET=$JwtSecret",
  "--from-literal=MINIO_ROOT_USER=$MinioRootUser",
  "--from-literal=MINIO_ROOT_PASSWORD=$MinioRootPassword",
  "--from-literal=SMTP_USERNAME=$SmtpUsername",
  "--from-literal=SMTP_PASSWORD=$SmtpPassword"
)

$secretYaml = & kubectl create secret generic $Name -n $Namespace @literalArgs --dry-run=client -o yaml
if ($LASTEXITCODE -ne 0) {
  throw "kubectl create secret dry-run failed."
}

$secretYaml | & kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
  throw "kubectl apply secret failed."
}

$databaseServices = @(
  @{ Key = "user"; SecretName = "user-service-db" },
  @{ Key = "course"; SecretName = "course-service-db" },
  @{ Key = "enrollment"; SecretName = "enrollment-service-db" },
  @{ Key = "payment"; SecretName = "payment-service-db" },
  @{ Key = "notification"; SecretName = "notification-service-db" }
)

foreach ($databaseService in $databaseServices) {
  $databasePassword = $PostgresPassword
  if ([string]::IsNullOrWhiteSpace($databasePassword)) {
    $databasePassword = Get-ExistingSecretValue -SecretName $databaseService.SecretName -Key "POSTGRES_PASSWORD"
    if ([string]::IsNullOrWhiteSpace($databasePassword)) {
      $databasePassword = New-RandomSecret
    }
  }

  $databaseName = "${PostgresDb}_$($databaseService.Key)"
  $databaseUser = "${PostgresUser}_$($databaseService.Key)"
  $databaseArgs = @(
    "--from-literal=POSTGRES_DB=$databaseName",
    "--from-literal=POSTGRES_USER=$databaseUser",
    "--from-literal=POSTGRES_PASSWORD=$databasePassword"
  )

  $databaseSecretYaml = & kubectl create secret generic $databaseService.SecretName -n $Namespace @databaseArgs --dry-run=client -o yaml
  if ($LASTEXITCODE -ne 0) {
    throw "kubectl create secret dry-run failed for $($databaseService.SecretName)."
  }

  $databaseSecretYaml | & kubectl apply -f -
  if ($LASTEXITCODE -ne 0) {
    throw "kubectl apply secret failed for $($databaseService.SecretName)."
  }
}

Write-Host "Shared secret $Name and 5 service database secrets are present in namespace $Namespace. Values were not printed."
