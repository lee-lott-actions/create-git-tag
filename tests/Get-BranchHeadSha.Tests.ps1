Import-Module "$PSScriptRoot/../modules/Get-BranchHeadSha.psm1" -Force

Describe "Get-BranchHeadSha" {
	BeforeAll {
		$script:RepoName   = "my-repo"
		$script:OrgName    = "my-org"
		$script:BranchName = "main"
		$script:MockApiUrl = "http://127.0.0.1:3000"
		$script:Headers    = @{ Authorization = "Bearer test-token"; "Accept" = "application/vnd.github+json" }
		$script:SampleSha  = "abc123def456"
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
		It "unit: Get-BranchHeadSha succeeds with HTTP 200" {
			Mock Invoke-WebRequest {
				[PSCustomObject]@{ 
					StatusCode = 200
					Content = '{"commit":{"sha":"abc123def456"}}'
				}
			} -ModuleName Get-BranchHeadSha
	
			$result = Get-BranchHeadSha -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -GithubApiUrl $MockApiUrl -Headers $Headers
			$result | Should -Be $SampleSha
		}

		It "unit: Get-BranchHeadSha calls Invoke-WebRequest with correct parameters" {
			Mock Invoke-WebRequest {
				[PSCustomObject]@{ StatusCode = 200; Content = '{"commit":{"sha":"abc123def456"}}' }
			} -ModuleName Get-BranchHeadSha
	
			Get-BranchHeadSha -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -GithubApiUrl $MockApiUrl -Headers $Headers
	
			Assert-MockCalled Invoke-WebRequest -ModuleName Get-BranchHeadSha -Exactly 1 -ParameterFilter {
				$Uri -eq "$MockApiUrl/repos/$OrgName/$RepoName/branches/$BranchName" -and
				$Headers.Authorization -eq "Bearer test-token" -and
				$Method -eq "Get"
			}
		}

		It "unit: Get-BranchHeadSha returns empty string if commit sha missing from content" {
			Mock Invoke-WebRequest {
				[PSCustomObject]@{ 
					StatusCode = 200
					Content = '{"commit":{}}'
				}
			} -ModuleName Get-BranchHeadSha
	
			$result = Get-BranchHeadSha -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -GithubApiUrl $MockApiUrl -Headers $Headers
			$result | Should -Be $null # will be null, not empty string, if no property
		}
	
		It "unit: Get-BranchHeadSha encodes branch name correctly when branch name contains forward slashes" {
			Mock Invoke-WebRequest {
				[PSCustomObject]@{ StatusCode = 200; Content = '{"commit":{"sha":"abc123def456"}}' }
			} -ModuleName Get-BranchHeadSha
	
			$result = Get-BranchHeadSha -RepoName $RepoName -OrgName $OrgName -BranchName "feature/my-branch" -GithubApiUrl $MockApiUrl -Headers $Headers
	
			$result | Should -Be $SampleSha
			Assert-MockCalled Invoke-WebRequest -ModuleName Get-BranchHeadSha -Exactly 1 -ParameterFilter {
				$Uri -eq "$MockApiUrl/repos/$OrgName/$RepoName/branches/feature%2Fmy-branch"
			}
		}
	}

	Context "Failure Cases" {
		It "unit: Get-BranchHeadSha fails with non-200 HTTP code" {
			Mock Invoke-WebRequest {
				[PSCustomObject]@{ 
					StatusCode = 404
					Content = '{"message": "Not Found"}'
				}
			} -ModuleName Get-BranchHeadSha
	
			$result = Get-BranchHeadSha -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -GithubApiUrl $MockApiUrl -Headers $Headers
			$result | Should -Be ""
		}
	}
}
