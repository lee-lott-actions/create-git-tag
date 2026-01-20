function New-GitTagRef {
    param(
        [string]$RepoName,
        [string]$OrgName,
        [string]$TagName,
        [string]$TagSha,
        [string]$GithubApiUrl,
        [hashtable]$Headers
    )

    $refBody = @{
        ref = "refs/tags/$TagName"
        sha = $TagSha
    } | ConvertTo-Json

    $refUrl = "$GithubApiUrl/repos/$OrgName/$RepoName/git/refs"
    $refResp = Invoke-WebRequest -Uri $refUrl -Headers $Headers -Method Post -Body $refBody

    if ($refResp.StatusCode -ne 201) {
        $msg = ($refResp.Content | ConvertFrom-Json).message
        Write-Host "Failed to create tag ref. Status: $($refResp.StatusCode)"
        return @{
            Result = 'failure'
            ErrorMessage = "Failed to create ref: $msg"
        }
    }

    Write-Host "Tag ref created: refs/tags/$TagName"
    return @{
        Result = 'success'
        RefObject = $refResp.Content | ConvertFrom-Json
    }
}