function New-GitTagObject {
    param(
        [string]$RepoName,
        [string]$OrgName,
        [string]$TagName,
        [string]$TagMessage,
        [string]$TargetSha,
        [string]$GithubApiUrl,
        [hashtable]$Headers
    )

    $tagBody = @{
        tag = $TagName
        message = $TagMessage
        object = $TargetSha
        type = "commit"
        tagger = @{
            name  = $env:GITHUB_ACTOR
            email = "$($env:GITHUB_ACTOR)@users.noreply.github.com"
            date  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
    } | ConvertTo-Json

    $tagUrl = "$GithubApiUrl/repos/$OrgName/$RepoName/git/tags"
    $tagResp = Invoke-WebRequest -Uri $tagUrl -Headers $Headers -Method Post -Body $tagBody

    if ($tagResp.StatusCode -ne 201) {
        $msg = ($tagResp.Content | ConvertFrom-Json).message
        $errorMsg = "Error: Failed to create tag object. Status: $($tagResp.StatusCode). Message: $msg" 
        Write-Host $errorMsg
        return @{
            Result = 'failure'
            ErrorMessage = $errorMsg
            TagObj = $null
        }
    }

    $tagObj = $tagResp.Content | ConvertFrom-Json
    Write-Host "Tag object created: $($tagObj.sha)"
    return @{
        Result = 'success'
        TagObj = $tagObj
    }
}
