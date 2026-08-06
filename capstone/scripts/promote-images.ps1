param(
  [string]$Namespace = "learnhub-capstone-dev",
  [string]$Registry = "ghcr.io/dieppq",
  [Parameter(Mandatory = $true)][string]$UserServiceDigest,
  [Parameter(Mandatory = $true)][string]$CourseServiceDigest,
  [Parameter(Mandatory = $true)][string]$EnrollmentServiceDigest,
  [Parameter(Mandatory = $true)][string]$PaymentServiceDigest,
  [Parameter(Mandatory = $true)][string]$NotificationServiceDigest
)

$ErrorActionPreference = "Stop"
$images = @{
  "user-service" = "$Registry/learnhub-user-service@$UserServiceDigest"
  "course-service-blue" = "$Registry/learnhub-course-service@$CourseServiceDigest"
  "course-service-green" = "$Registry/learnhub-course-service@$CourseServiceDigest"
  "enrollment-service" = "$Registry/learnhub-enrollment-service@$EnrollmentServiceDigest"
  "payment-service" = "$Registry/learnhub-payment-service@$PaymentServiceDigest"
  "notification-service" = "$Registry/learnhub-notification-service@$NotificationServiceDigest"
}

foreach ($item in $images.GetEnumerator()) {
  if ($item.Value -notmatch "@sha256:[a-f0-9]{64}$") {
    throw "Invalid immutable digest for $($item.Key): $($item.Value)"
  }
  kubectl set image "deployment/$($item.Key)" "main=$($item.Value)" -n $Namespace
  if ($LASTEXITCODE -ne 0) { throw "kubectl set image failed for $($item.Key)" }
}

foreach ($deployment in $images.Keys) {
  kubectl rollout status "deployment/$deployment" -n $Namespace --timeout=180s
  if ($LASTEXITCODE -ne 0) { throw "rollout failed for $deployment" }
}
