Import-Module "$PSScriptRoot/../modules/Get-BranchHeadSha.psm1" -Force

Describe "Get-BranchHeadSha" {
	BeforeEach {
		$RepoName   = "my-repo"
		$OrgName    = "my-org"
		$BranchName = "main"
		$GithubApiUrl = "https://api.unit-test.com"
		$Headers = @{ Authorization = "Bearer test-token"; "Accept" = "application/vnd.github+json" }
		$SampleSha = "abc123def456"
	}

	AfterAll {
		if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
	}

	It "returns branch head sha on status 200" {
		Mock Invoke-WebRequest {
			[PSCustomObject]@{ 
				StatusCode = 200
				Content = '{"commit":{"sha":"abc123def456"}}'
			}
		} -ModuleName Get-BranchHeadSha

		$result = Get-BranchHeadSha -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -GithubApiUrl $GithubApiUrl -Headers $Headers
		$result | Should -Be $SampleSha
	}

	It "returns empty string for non-200 status code" {
		Mock Invoke-WebRequest {
			[PSCustomObject]@{ 
				StatusCode = 404
				Content = '{"message": "Not Found"}'
			}
		} -ModuleName Get-BranchHeadSha

		$result = Get-BranchHeadSha -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -GithubApiUrl $GithubApiUrl -Headers $Headers
		$result | Should -Be ""
	}

	It "calls Invoke-WebRequest with correct parameters" {
		Mock Invoke-WebRequest {
			[PSCustomObject]@{ StatusCode = 200; Content = '{"commit":{"sha":"abc123def456"}}' }
		} -ModuleName Get-BranchHeadSha

		Get-BranchHeadSha -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -GithubApiUrl $GithubApiUrl -Headers $Headers

		Assert-MockCalled Invoke-WebRequest -ModuleName Get-BranchHeadSha -Exactly 1 -ParameterFilter {
			$Uri -eq "$GithubApiUrl/repos/$OrgName/$RepoName/branches/$BranchName" -and
			$Headers.Authorization -eq "Bearer test-token" -and
			$Method -eq "Get"
		}
	}

	It "returns empty string if commit sha missing from content" {
		Mock Invoke-WebRequest {
			[PSCustomObject]@{ 
				StatusCode = 200
				Content = '{"commit":{}}'
			}
		} -ModuleName Get-BranchHeadSha

		$result = Get-BranchHeadSha -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -GithubApiUrl $GithubApiUrl -Headers $Headers
		$result | Should -Be $null # will be null, not empty string, if no property
	}

	It "encodes branch name with forward slashes" {
		Mock Invoke-WebRequest {
			[PSCustomObject]@{ StatusCode = 200; Content = '{"commit":{"sha":"abc123def456"}}' }
		} -ModuleName Get-BranchHeadSha

		$result = Get-BranchHeadSha -RepoName $RepoName -OrgName $OrgName -BranchName "feature/my-branch" -GithubApiUrl $GithubApiUrl -Headers $Headers

		$result | Should -Be $SampleSha
		Assert-MockCalled Invoke-WebRequest -ModuleName Get-BranchHeadSha -Exactly 1 -ParameterFilter {
			$Uri -eq "$GithubApiUrl/repos/$OrgName/$RepoName/branches/feature%2Fmy-branch"
		}
	}
}