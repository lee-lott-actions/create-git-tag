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
		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
		return
	}

	Import-Module "$PSScriptRoot/Get-BranchHeadSha.psm1" -Force
	Import-Module "$PSScriptRoot/New-GitTagObject.psm1" -Force
	Import-Module "$PSScriptRoot/New-GitTagRef.psm1" -Force

	$githubApiUrl = $env:MOCK_API  
	if (-not $githubApiUrl) { $githubApiUrl = "https://api.github.com" }

	$headers = @{
		Authorization = "Bearer $Token"
		"Accept" = "application/vnd.github+json"
	}

	try {
		Write-Host "Creating Git Tag..."

		if (-not [string]::IsNullOrEmpty($CommitSha)) {
			$targetSha = $CommitSha
			Write-Host "Using provided CommitSha: $targetSha"
		} else {
			$targetSha = Get-BranchHeadSha -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -GithubApiUrl $githubApiUrl -Headers $headers
			if ([string]::IsNullOrEmpty($targetSha)) {
				Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
      			Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Failed to fetch branch info."
				return   
			}
		}

		$result = New-GitTagObject -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagMessage $TagMessage -TargetSha $targetSha -GithubApiUrl $githubApiUrl -Headers $headers 
		if ($result.Result -ne 'success') {
			Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
			Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$($result.ErrorMessage)"
			return
		}

		$tagObj = $result.TagObj 
		$refResult = New-GitTagRef -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagSha $tagObj.sha -GithubApiUrl $githubApiUrl -Headers $headers 
		if ($refResult.Result -ne 'success') {
			Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
			Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$($refResult.ErrorMessage)"
			return
		}

		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=success"  
		Write-Host "Successfully created tag $TagName on $OrgName/$RepoName ($BranchName)"
	} catch {
		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Create Git Tag threw an exception and failed."
		Write-Host "Failed to create Git tag: $($_.Exception.Message)"
	}
}