Import-Module "$PSScriptRoot/../modules/New-GitTagObject.psm1" -Force

Describe "New-GitTagObject" {
  BeforeAll {
    $script:RepoName     = "my-repo"
    $script:OrgName      = "my-org"
    $script:TagName      = "v1.2.3"
    $script:TagMessage   = "Release v1.2.3"
    $script:TargetSha    = "abc123def456"
    $script:MockApiUrl   = "http://127.0.0.1:3000"
    $script:Headers      = @{ Authorization = "Bearer test-token"; "Accept" = "application/vnd.github+json" }
    $script:SampleTagSha = "tagsha123abc"
    $script:actor        = "unit-user"
  }
  
  BeforeEach {
    $env:GITHUB_OUTPUT = (New-TemporaryFile).FullName
    $env:MOCK_API = $script:MockApiUrl
    $env:GITHUB_ACTOR = $actor
  }
  
  AfterEach {
    if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
    Remove-Item Env:MOCK_API -ErrorAction SilentlyContinue
    Remove-Item Env:GITHUB_ACTOR -ErrorAction SilentlyContinue
  }

  Context "Success Cases" {
      It "unit: New-GitTagObject succeeds with HTTP 201" {
          Mock Invoke-WebRequest {
              [PSCustomObject]@{
                  StatusCode = 201
                  Content = '{"sha":"tagsha123abc","other":"data"}'
              }
          } -ModuleName New-GitTagObject
  
          $result = New-GitTagObject -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagMessage $TagMessage -TargetSha $TargetSha -GithubApiUrl $MockApiUrl -Headers $Headers
  
          $result.Result | Should -Be 'success'
          $result.TagObj.sha | Should -Be $SampleTagSha
      }

      It "unit: New-GitTagObject calls Invoke-WebRequest with correct parameters" {
        Mock Invoke-WebRequest {
            [PSCustomObject]@{ StatusCode = 201; Content = '{"sha":"foo"}' }
        } -ModuleName New-GitTagObject

        New-GitTagObject -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagMessage $TagMessage -TargetSha $TargetSha -GithubApiUrl $MockApiUrl -Headers $Headers

        Assert-MockCalled Invoke-WebRequest -ModuleName New-GitTagObject -Exactly 1 -ParameterFilter {
            $Uri -eq "$MockApiUrl/repos/$OrgName/$RepoName/git/tags" -and
            $Headers.Authorization -eq "Bearer test-token" -and
            $Method -eq "Post"
        }
    }      
  }

  Context "Failure Cases" {
      It "unit: New-GitTagObject failus with non-200 HTTP code" {
        Mock Invoke-WebRequest {
            [PSCustomObject]@{
                StatusCode = 400
                Content = '{"message":"Invalid input"}'
            }
        } -ModuleName New-GitTagObject

        $result = New-GitTagObject -RepoName $RepoName -OrgName $OrgName -TagName $TagName -TagMessage $TagMessage -TargetSha $TargetSha -GithubApiUrl $MockApiUrl -Headers $Headers

        $result.Result | Should -Be 'failure'
        $result.TagObj | Should -Be $null
        $result.ErrorMessage | Should -Match "Error: Failed to create tag object. Status: 400. Message: Invalid input"
    }
  }
}
