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
        $errorMsg = "Error: failed to create tag ref. Status: $($refResp.StatusCode). Message: $msg"
        Write-Host $errorMsg
        return @{
            Result = 'failure'
            ErrorMessage = $errorMsg
        }
    }

    Write-Host "Tag ref created: refs/tags/$TagName"
    return @{
        Result = 'success'
        RefObject = $refResp.Content | ConvertFrom-Json
    }
}
