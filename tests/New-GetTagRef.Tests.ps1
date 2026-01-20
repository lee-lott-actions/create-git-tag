Import-Module "$PSScriptRoot/../modules/New-GitTagRef.psm1" -Force

Describe "New-GitTagRef" {
	BeforeEach {
		$RepoName = "my-repo"
		$OrgName = "my-org"
		$TagName = "v1.2.3"
		$TagSha  = "tagsha123"
		$GithubApiUrl = "https://api.unit-test.com"
		$Headers = @{ Authorization = "Bearer test-token"; "Accept" = "application/vnd.github+json" }
	}

  AfterAll {
    if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
  }

	It "returns success and reference object on 201 status" {
		Mock Invoke-WebRequest {
			[PSCustomObject]@{
				StatusCode = 201
				Content = '{"ref":"refs/tags/v1.2.3","object":"tagobj456"}'
			}
		} -ModuleName New-GitTagRef

		$result = New-GitTagRef -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagSha $TagSha -GithubApiUrl $GithubApiUrl -Headers $Headers
		$result.Result    | Should -Be 'success'
		$result.RefObject.ref | Should -Be "refs/tags/$TagName"
	}

	It "returns failure and message on non-201 status" {
		Mock Invoke-WebRequest {
			[PSCustomObject]@{
				StatusCode = 400
				Content = '{"message":"Validation Failed"}'
			}
		} -ModuleName New-GitTagRef

		$result = New-GitTagRef -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagSha $TagSha -GithubApiUrl $GithubApiUrl -Headers $Headers
		$result.Result       | Should -Be 'failure'
		$result.ErrorMessage | Should -Match "Failed to create ref: Validation Failed"
		$result.RefObject    | Should -Be $null
	}

	It "calls Invoke-WebRequest with correct parameters" {
		Mock Invoke-WebRequest {
			[PSCustomObject]@{ StatusCode = 201; Content = '{}' }
		} -ModuleName New-GitTagRef

		New-GitTagRef -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagSha $TagSha -GithubApiUrl $GithubApiUrl -Headers $Headers

		Assert-MockCalled Invoke-WebRequest -ModuleName New-GitTagRef -Exactly 1 -ParameterFilter {
			$Uri -eq "$GithubApiUrl/repos/$OrgName/$RepoName/git/refs" -and
			$Headers.Authorization -eq "Bearer test-token" -and
			$Method -eq "Post"
		}
	}
}