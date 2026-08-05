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

if ([string]::IsNullOrWhiteSpace($PostgresPassword)) {
  $PostgresPassword = New-RandomSecret
}
if ([string]::IsNullOrWhiteSpace($JwtSecret)) {
  $JwtSecret = New-RandomSecret
}
if ([string]::IsNullOrWhiteSpace($MinioRootPassword)) {
  $MinioRootPassword = New-RandomSecret
}
if ([string]::IsNullOrWhiteSpace($SmtpPassword)) {
  $SmtpPassword = New-RandomSecret
}

$namespaceYaml = & kubectl create namespace $Namespace --dry-run=client -o yaml
if ($LASTEXITCODE -ne 0) {
  throw "kubectl create namespace dry-run failed."
}

$namespaceYaml | & kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
  throw "kubectl apply namespace $Namespace failed."
}

$literalArgs = @(
  "--from-literal=POSTGRES_DB=$PostgresDb",
  "--from-literal=POSTGRES_USER=$PostgresUser",
  "--from-literal=POSTGRES_PASSWORD=$PostgresPassword",
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

Write-Host "Secret $Name is present in namespace $Namespace. Values were not printed."
