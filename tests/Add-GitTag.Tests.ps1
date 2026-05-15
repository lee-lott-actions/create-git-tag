Import-Module "$PSScriptRoot/../modules/Add-GitTag.psm1" -Force

Describe "Add-GitTag" {
    BeforeAll {
        $script:RepoName   = "my-repo"
        $script:OrgName    = "my-org"
        $script:BranchName = "main"
        $script:TagName    = "v1.2.3"
        $script:TagMessage = "Release v1.2.3"
        $script:CommitSha  = "abc123def456"
        $script:Token      = "test-token"
        $script:MockApiUrl = "http://127.0.0.1:3000"
        $script:Headers = @{ Authorization = "Bearer $Token"; Accept = "application/vnd.github+json" }
    }
    
    BeforeEach {
        $env:GITHUB_OUTPUT = New-TemporaryFile
        $env:MOCK_API = $script:MockApiUrl       
    }

    AfterEach {
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
        Remove-Item Env:MOCK_API -ErrorAction SilentlyContinue
    }

     Context "Success Cases" {
        It "unit: Add-GitTag succeeds successfully" {
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

    Context "Get-BranchSha Test Cases" {
        It "unit: Add-GitTag uses provided CommitSha and does not call Get-BranchHeadSha" {
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
    
        It "unit: Add-GitTag calls Get-BranchHeadSha when CommitSha is not supplied" {
            $script:calledGetBranchHeadSha = $false
            Mock Get-BranchHeadSha { $script:calledGetBranchHeadSha = $true; "sha-from-branch" } -ModuleName Add-GitTag
            Mock New-GitTagObject { @{ Result = 'success'; TagObj = @{ sha = "sha-from-branch" } } } -ModuleName Add-GitTag
            Mock New-GitTagRef { @{ Result = 'success'; RefObject = @{ ref = "refs/tags/$TagName" } } } -ModuleName Add-GitTag
    
            Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -Token $Token
    
            $script:calledGetBranchHeadSha | Should -Be $true
            (Get-Content $env:GITHUB_OUTPUT) | Should -Contain "result=success"
        }
    
        It "unit: Add-GitTag handles Get-BranchHeadSha returning empty string" {
            Mock Get-BranchHeadSha { "" } -ModuleName Add-GitTag
            Mock New-GitTagObject {} -ModuleName Add-GitTag
            Mock New-GitTagRef {} -ModuleName Add-GitTag
    
            Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -Token $Token
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Where-Object { $_ -match "error-message=Error: Failed to fetch branch info." } | Should -Not -BeNullOrEmpty
        }    
    }

    Context "New-GitTagObject Failure Cases" {
        It "unit: Add-GitTag fails creating new Git Tag Object" {
            Mock Get-BranchHeadSha { "sha123" } -ModuleName Add-GitTag
            Mock New-GitTagObject { @{ Result = 'failure'; ErrorMessage = "Some tagobj error" } } -ModuleName Add-GitTag
            Mock New-GitTagRef {} -ModuleName Add-GitTag
    
            Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -Token $Token
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Should -Contain "error-message=Some tagobj error"
        }
    }

    Context "New-GitTagRef Failure Cases" {
        It "unit: Add-GitTag fails creating new Git Tag Ref" {
            Mock Get-BranchHeadSha { "sha123" } -ModuleName Add-GitTag
            Mock New-GitTagObject { @{ Result = 'success'; TagObj = @{ sha = "sha123" } } } -ModuleName Add-GitTag
            Mock New-GitTagRef { @{ Result = 'failure'; ErrorMessage = "Ref create failed" } } -ModuleName Add-GitTag
    
            Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -Token $Token
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Should -Contain "error-message=Ref create failed"
        }
    }

    Context "Parameter Validation Failure Cases" {
        It "unit: Add-GitTag fails with empty RepoName" {
            Add-GitTag -RepoName "" -OrgName "org" -BranchName "branch" -TagName "tag" -TagMessage "msg" -Token "tok"
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Where-Object { $_ -match "error-message=Missing required parameters" } | Should -Not -BeNullOrEmpty
        }
        
        It "unit: Add-GitTag fails with empty OrgName" {
            Add-GitTag -RepoName "repo" -OrgName "" -BranchName "branch" -TagName "tag" -TagMessage "msg" -Token "tok"
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Where-Object { $_ -match "error-message=Missing required parameters" } | Should -Not -BeNullOrEmpty
        }
        
        It "unit: Add-GitTag fails with empty BranchName" {
            Add-GitTag -RepoName "repo" -OrgName "org" -BranchName "" -TagName "tag" -TagMessage "msg" -Token "tok"
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Where-Object { $_ -match "error-message=Missing required parameters" } | Should -Not -BeNullOrEmpty
        }
        
        It "unit: Add-GitTag fails with empty TagName" {
            Add-GitTag -RepoName "repo" -OrgName "org" -BranchName "branch" -TagName "" -TagMessage "msg" -Token "tok"
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Where-Object { $_ -match "error-message=Missing required parameters" } | Should -Not -BeNullOrEmpty
        }
        
        It "unit: Add-GitTag fails with empty Token" {
            Add-GitTag -RepoName "repo" -OrgName "org" -BranchName "branch" -TagName "tag" -TagMessage "msg" -Token ""
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Where-Object { $_ -match "error-message=Missing required parameters" } | Should -Not -BeNullOrEmpty
        }
    }

    Context "Exception Failure Cases" {
        It "unit: Add-GitTag fails with exception" {
            Mock Get-BranchHeadSha { throw "Boom!" } -ModuleName Add-GitTag
            Mock New-GitTagObject {} -ModuleName Add-GitTag
            Mock New-GitTagRef {} -ModuleName Add-GitTag
    
            Add-GitTag -RepoName $RepoName -OrgName $OrgName -BranchName $BranchName -TagName $TagName -TagMessage $TagMessage -Token $Token
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Where-Object { $_ -match "error-message=Error: Failed to create tag.  Exception:" } | Should -Not -BeNullOrEmpty
        }    
    }
}
