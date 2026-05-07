Import-Module "$PSScriptRoot/../modules/Add-GitTag.psm1" -Force

Describe "Add-GitTag" {
    BeforeEach {
        $env:GITHUB_OUTPUT = "$PSScriptRoot/github_output.temp"
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
        $RepoName   = "my-repo"
        $OrgName    = "my-org"
        $BranchName = "main"
        $TagName    = "v1.2.3"
        $TagMessage = "Release v1.2.3"
        $CommitSha  = "abc123def456"
        $Token      = "test-token"
        $GithubApiUrl = "https://api.unit-test.com"
        $Headers = @{ Authorization = "Bearer $Token"; Accept = "application/vnd.github+json" }
        $SampleSha = "abc123def456"
        $SampleTag = @{ sha = "tagsha123" }
    }

    AfterAll {
      if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
    }

    It "returns failure for empty RepoName" {
        Add-GitTag -RepoName "" -OrgName "org" -BranchName "branch" -TagName "tag" -TagMessage "msg" -Token "tok"
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "error-message=Missing required parameters" } | Should -Not -BeNullOrEmpty
    }
    
    It "returns failure for empty OrgName" {
        Add-GitTag -RepoName "repo" -OrgName "" -BranchName "branch" -TagName "tag" -TagMessage "msg" -Token "tok"
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "error-message=Missing required parameters" } | Should -Not -BeNullOrEmpty
    }
    
    It "returns failure for empty BranchName" {
        Add-GitTag -RepoName "repo" -OrgName "org" -BranchName "" -TagName "tag" -TagMessage "msg" -Token "tok"
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "error-message=Missing required parameters" } | Should -Not -BeNullOrEmpty
    }
    
    It "returns failure for empty TagName" {
        Add-GitTag -RepoName "repo" -OrgName "org" -BranchName "branch" -TagName "" -TagMessage "msg" -Token "tok"
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "error-message=Missing required parameters" } | Should -Not -BeNullOrEmpty
    }
    
    It "returns failure for empty Token" {
        Add-GitTag -RepoName "repo" -OrgName "org" -BranchName "branch" -TagName "tag" -TagMessage "msg" -Token ""
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "error-message=Missing required parameters" } | Should -Not -BeNullOrEmpty
    }

    It "uses provided CommitSha and does not call Get-BranchHeadSha" {
        $script:calledGetBranchHeadSha = $false
        $script:calledNewTagObj = $false
        $script:calledNewRef = $false

        Mock Get-BranchHeadSha { $script:calledGetBranchHeadSha = $true } -ModuleName Add-GitTag
        Mock New-GitTagObject { $script:calledNewTagObj = $true; @{ Result = 'success'; TagObj = @{ sha = "sha123" } } } -ModuleName Add-GitTag
        Mock New-GitTagRef { $script:calledNewRef = $true; @{ Result = 'success'; RefObject = @{ ref = "refs/tags/$TagName" } } } -ModuleName Add-GitTag

        Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -CommitSha $CommitSha -Token $Token

        $script:calledGetBranchHeadSha | Should -Be $false
        $script:calledNewTagObj | Should -Be $true
        $script:calledNewRef | Should -Be $true
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=success"
    }

    It "calls Get-BranchHeadSha when CommitSha is not supplied" {
        $calledGetBranchHeadSha = $false
        Mock Get-BranchHeadSha { $script:calledGetBranchHeadSha = $true; "sha-from-branch" } -ModuleName Add-GitTag
        Mock New-GitTagObject { @{ Result = 'success'; TagObj = @{ sha = "sha-from-branch" } } } -ModuleName Add-GitTag
        Mock New-GitTagRef { @{ Result = 'success'; RefObject = @{ ref = "refs/tags/$TagName" } } } -ModuleName Add-GitTag

        Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -Token $Token

        $script:calledGetBranchHeadSha | Should -Be $true
        (Get-Content $env:GITHUB_OUTPUT) | Should -Contain "result=success"
    }

    It "handles Get-BranchHeadSha returning empty string" {
        Mock Get-BranchHeadSha { "" } -ModuleName Add-GitTag
        Mock New-GitTagObject {} -ModuleName Add-GitTag
        Mock New-GitTagRef {} -ModuleName Add-GitTag

        Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -Token $Token

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "error-message=Failed to fetch branch info" } | Should -Not -BeNullOrEmpty
    }

    It "handles tag object creation failure" {
        Mock Get-BranchHeadSha { "sha123" } -ModuleName Add-GitTag
        Mock New-GitTagObject { @{ Result = 'failure'; ErrorMessage = "Some tagobj error" } } -ModuleName Add-GitTag
        Mock New-GitTagRef {} -ModuleName Add-GitTag

        Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -Token $Token

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Some tagobj error"
    }

    It "handles tag ref creation failure" {
        Mock Get-BranchHeadSha { "sha123" } -ModuleName Add-GitTag
        Mock New-GitTagObject { @{ Result = 'success'; TagObj = @{ sha = "sha123" } } } -ModuleName Add-GitTag
        Mock New-GitTagRef { @{ Result = 'failure'; ErrorMessage = "Ref create failed" } } -ModuleName Add-GitTag

        Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -Token $Token

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Ref create failed"
    }

    It "writes error-message and failure on exception" {
        Mock Get-BranchHeadSha { throw "Boom!" } -ModuleName Add-GitTag
        Mock New-GitTagObject {} -ModuleName Add-GitTag
        Mock New-GitTagRef {} -ModuleName Add-GitTag

        Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -Token $Token

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "error-message=Create Git Tag threw an exception" } | Should -Not -BeNullOrEmpty
    }

    It "calls sub-functions with correct parameters" {
        $script:gitShaResult = "testsha321"
        $script:tagObjResult = @{ sha = "tagsha456" }
        $script:calledParams = @{}

        Mock Get-BranchHeadSha {
            param($RepoName1, $OrgName1, $BranchName1, $ApiUrl1, $Headers1)
            $script:calledParams.branch = @{
                RepoName = $RepoName1
                OrgName  = $OrgName1
                BranchName = $BranchName1
                GithubApiUrl = $ApiUrl1
                Headers = $Headers1
            }
            $script:gitShaResult
        } -ModuleName Add-GitTag
        
        Mock New-GitTagObject {
            param($RepoName1, $OrgName1, $TagName1, $TagMessage1, $TargetSha1, $ApiUrl1, $Headers1)
            $script:calledParams.tag = @{
                RepoName = $RepoName1
                OrgName  = $OrgName1
                TagName  = $TagName1
                TagMessage = $TagMessage1
                TargetSha = $TargetSha1
                GithubApiUrl = $ApiUrl1
                Headers = $Headers1
            }
            @{ Result = 'success'; TagObj = $script:tagObjResult }
        } -ModuleName Add-GitTag
        
        Mock New-GitTagRef {
            param($RepoName1, $OrgName1, $TagName1, $TagSha1, $ApiUrl1, $Headers1)
            $script:calledParams.ref = @{
                RepoName = $RepoName1
                OrgName  = $OrgName1
                TagName  = $TagName1
                TagSha   = $TagSha1
                GithubApiUrl = $ApiUrl1
                Headers = $Headers1
            }
            @{ Result = 'success'; RefObject = @{ ref = "refs/tags/$TagName" } }
        } -ModuleName Add-GitTag

        Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -Token $Token

        $script:calledParams.branch.RepoName  | Should -Be $RepoName
        $script:calledParams.branch.OrgName   | Should -Be $OrgName
        $script:calledParams.branch.BranchName| Should -Be $BranchName
        $script:calledParams.tag.TagName      | Should -Be $TagName
        $script:calledParams.tag.TargetSha    | Should -Be $script:gitShaResult
        $script:calledParams.ref.TagSha       | Should -Be $script:tagObjResult.sha
    }
}