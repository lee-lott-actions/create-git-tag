Import-Module "$PSScriptRoot/../modules/New-GitTagRef.psm1" -Force

Describe "New-GitTagRef" {
	BeforeAll {
		$script:RepoName   = "my-repo"
		$script:OrgName    = "my-org"
		$script:TagName    = "v1.2.3"
		$script:TagSha     = "tagsha123"
		$script:MockApiUrl = "https://api.unit-test.com"
		$script:Headers    = @{ Authorization = "Bearer test-token"; "Accept" = "application/vnd.github+json" }
	}
	
	BeforeEach {
		$env:GITHUB_OUTPUT = (New-TemporaryFile).FullName
		$env:MOCK_API = $script:MockApiUrl
  	}

  	AfterEach {
		if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
		Remove-Item Env:MOCK_API -ErrorAction SilentlyContinue
  	}

	Context "Success Cases" {
		It "unit: New-GitTagRef succeeds with HTTP 201" {
			Mock Invoke-WebRequest {
				[PSCustomObject]@{
					StatusCode = 201
					Content = '{"ref":"refs/tags/v1.2.3","object":"tagobj456"}'
				}
			} -ModuleName New-GitTagRef
	
			$result = New-GitTagRef -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagSha $TagSha -GithubApiUrl $MockApiUrl -Headers $Headers
			$result.Result    | Should -Be 'success'
			$result.RefObject.ref | Should -Be "refs/tags/$TagName"
		}

		It "unit: New-GitTagRef calls Invoke-WebRequest with correct parameters" {
			Mock Invoke-WebRequest {
				[PSCustomObject]@{ StatusCode = 201; Content = '{}' }
			} -ModuleName New-GitTagRef
	
			New-GitTagRef -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagSha $TagSha -GithubApiUrl $MockApiUrl -Headers $Headers
	
			Assert-MockCalled Invoke-WebRequest -ModuleName New-GitTagRef -Exactly 1 -ParameterFilter {
				$Uri -eq "$MockApiUrl/repos/$OrgName/$RepoName/git/refs" -and
				$Headers.Authorization -eq "Bearer test-token" -and
				$Method -eq "Post"
			}
		}
	}

	Context "Failure Cases" {
		It "unit: New-GitTagRef fails with non-201 HTTP code" {
			Mock Invoke-WebRequest {
				[PSCustomObject]@{
					StatusCode = 400
					Content = '{"message":"Validation Failed"}'
				}
			} -ModuleName New-GitTagRef
	
			$result = New-GitTagRef -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagSha $TagSha -GithubApiUrl $MockApiUrl -Headers $Headers
			$result.Result       | Should -Be 'failure'
			$result.ErrorMessage | Should -Match "Error: Failed to create tag ref. Status: 400. Message: Validation Failed"
			$result.RefObject    | Should -Be $null
		}
	}
}
