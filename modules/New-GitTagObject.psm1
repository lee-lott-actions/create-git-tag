function Add-GitTag {
	param(
		[string]$RepoName,
		[string]$OrgName,
		[string]$BranchName,
		[string]$TagName,
		[string]$TagMessage,
		[string]$CommitSha,
		[string]$Token 
	)

	# Validate required inputs
	if ([string]::IsNullOrEmpty($RepoName) -or 
		[string]::IsNullOrEmpty($OrgName) -or 
		[string]::IsNullOrEmpty($BranchName) -or 
		[string]::IsNullOrEmpty($TagName) -or
		[string]::IsNullOrEmpty($Token)) 
	{
		Write-Output "Error: Missing required parameters"  
		Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Missing required parameters: RepoName, OrgName, BranchName, TagName, and Token must be provided."
		Add-Content -Path $env:GITHUB_OUTPUT -Value "resfunction New-GitTagObject {
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
        Write-Host "Failed to create tag object. Status: $($tagResp.StatusCode)"
        return @{
            Result = 'failure'
            ErrorMessage = "Failed to create tag object: $msg"
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