function Get-BranchHeadSha {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$RepoName,
        [string]$OrgName,
        [string]$BranchName,
        [string]$GithubApiUrl,
        [hashtable]$Headers
    )

    $EncodedBranchName = [uri]::EscapeDataString($BranchName)
    $branchUrl = "$GithubApiUrl/repos/$OrgName/$RepoName/branches/$EncodedBranchName"
    $branchResp = Invoke-WebRequest -Uri $branchUrl -Headers $Headers -Method Get
    
    if ($branchResp.StatusCode -ne 200) {
        Write-Host "Failed to fetch branch info. Status: $($branchResp.StatusCode)"
        return ''
    }
    
    $branchInfo = $branchResp.Content | ConvertFrom-Json
    $targetSha = $branchInfo.commit.sha
    Write-Host "Using branch head SHA: $targetSha"
    return $targetSha
}