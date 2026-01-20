Write-Host "Running all module tests..."

. "$PSScriptRoot/Get-BranchHeadSha.Tests.ps1"
. "$PSScriptRoot/New-GitTagObject.Tests.ps1"
. "$PSScriptRoot/New-GitTagRef.Tests.ps1"
. "$PSScriptRoot/Add-GitTag.Tests.ps1"

Write-Host "All tests completed."