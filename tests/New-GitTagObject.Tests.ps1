Import-Module "$PSScriptRoot/../modules/New-GitTagObject.psm1" -Force

Describe "New-GitTagObject" {
  BeforeEach {
    $RepoName   = "my-repo"
    $OrgName    = "my-org"
    $TagName    = "v1.2.3"
    $TagMessage = "Release v1.2.3"
    $TargetSha  = "abc123def456"
    $GithubApiUrl = "https://api.unit-test.com"
    $Headers = @{ Authorization = "Bearer test-token"; "Accept" = "application/vnd.github+json" }
    $SampleTagSha = "tagsha123abc"
    $actor = "unit-user"
  }
  
    BeforeAll {
        $env:GITHUB_ACTOR = $actor
    }

    AfterAll {
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
    }
    
    It "returns success and tag object on 201 status" {
        Mock Invoke-WebRequest {
            [PSCustomObject]@{
                StatusCode = 201
                Content = '{"sha":"tagsha123abc","other":"data"}'
            }
        } -ModuleName New-GitTagObject

        $result = New-GitTagObject -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagMessage $TagMessage -TargetSha $TargetSha -GithubApiUrl $GithubApiUrl -Headers $Headers

        $result.Result | Should -Be 'success'
        $result.TagObj.sha | Should -Be $SampleTagSha
    }

    It "returns failure and message on non-201 status" {
        Mock Invoke-WebRequest {
            [PSCustomObject]@{
                StatusCode = 400
                Content = '{"message":"Invalid input"}'
            }
        } -ModuleName New-GitTagObject

        $result = New-GitTagObject -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagMessage $TagMessage -TargetSha $TargetSha -GithubApiUrl $GithubApiUrl -Headers $Headers

        $result.Result | Should -Be 'failure'
        $result.TagObj | Should -Be $null
        $result.ErrorMessage | Should -Match "Failed to create tag object: Invalid input"
    }

    It "calls Invoke-WebRequest with correct parameters" {
        Mock Invoke-WebRequest {
            [PSCustomObject]@{ StatusCode = 201; Content = '{"sha":"foo"}' }
        } -ModuleName New-GitTagObject

        New-GitTagObject -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagMessage $TagMessage -TargetSha $TargetSha -GithubApiUrl $GithubApiUrl -Headers $Headers

        Assert-MockCalled Invoke-WebRequest -ModuleName New-GitTagObject -Exactly 1 -ParameterFilter {
            $Uri -eq "$GithubApiUrl/repos/$OrgName/$RepoName/git/tags" -and
            $Headers.Authorization -eq "Bearer test-token" -and
            $Method -eq "Post"
        }
    }
}