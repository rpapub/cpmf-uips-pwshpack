#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../CpmfUipsPack.psd1') -Force
}

Describe 'Invoke-NativeCommandCapture' {
    It 'captures stdout, stderr, and exit code from a native command' {
        InModuleScope CpmfUipsPack {
            $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsNativeTest-$(New-Guid)"
            $null = New-Item -ItemType Directory -Path $tmpRoot -Force
            try {
                $probe = Join-Path $tmpRoot 'probe.ps1'
                Set-Content -LiteralPath $probe @'
Write-Output "stdout-one"
Write-Error "stderr-one"
exit 7
'@

                $pwsh = (Get-Command pwsh).Source
                $capture = Invoke-NativeCommandCapture -FilePath $pwsh -ArgumentList @('-NoProfile', '-File', $probe)

                $capture.ExitCode | Should -Be 7
                $capture.StdOutLines | Should -Contain 'stdout-one'
                ($capture.StdErrLines -join "`n") | Should -Match 'stderr-one'
            }
            finally {
                Remove-Item $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'Invoke-PackAndStage' {

    BeforeEach {
        $script:tmpRoot     = Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsPackTest-$(New-Guid)"
        $script:tmpFeed     = Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsFeed-$(New-Guid)"
        $script:projectJson = Join-Path $script:tmpRoot 'project.json'
        $null = New-Item -ItemType Directory -Path $script:tmpRoot -Force
        Set-Content $script:projectJson '{"projectVersion": "1.0.0", "name": "TestProject"}'
    }

    AfterEach {
        Remove-Item $script:tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $script:tmpFeed -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Successful pack' {
        It 'bumps version, returns staged nupkg path, and uses the configured output root' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                $outputBase = Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsOutput-$(New-Guid)"
                $script:capturedOutputDir = $null
                Mock Invoke-UipcliPack {
                    param($UipcliExe, $PackArgs)
                    $outDir = $PackArgs[$PackArgs.IndexOf('-o') + 1]
                    $script:capturedOutputDir = $outDir
                    ($outDir.StartsWith($outputBase)) | Should -BeTrue
                    New-Item -ItemType File -Path (Join-Path $outDir 'TestProject.1.1.0.nupkg') -Force | Out-Null
                    return 0
                }

                $result = Invoke-PackAndStage -ProjectJson $pj -FeedPath $feed -OutputPath $outputBase -UipcliArgs @() -UipcliExe 'fake.exe'

                $result           | Should -BeLike '*.nupkg'
                Test-Path $result | Should -Be $true
                (Get-Content $pj -Raw) | Should -Match '"projectVersion":\s*"1\.1\.0"'
                $script:capturedOutputDir | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Pack failure and version rollback' {
        It 'restores projectVersion when uipcli exits non-zero' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Invoke-UipcliPack { return 1 }

                { Invoke-PackAndStage -ProjectJson $pj -FeedPath $feed -OutputPath (Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsOutput-$(New-Guid)") -UipcliArgs @() -UipcliExe 'fake.exe' } |
                    Should -Throw '*uipcli pack failed*'

                (Get-Content $pj -Raw) | Should -Match '"projectVersion":\s*"1\.0\.0"'
            }
        }
    }

    Context '-NoBump' {
        It 'does not change projectVersion' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Invoke-UipcliPack {
                    param($UipcliExe, $PackArgs)
                    $outDir = $PackArgs[$PackArgs.IndexOf('-o') + 1]
                    New-Item -ItemType File -Path (Join-Path $outDir 'TestProject.1.0.0.nupkg') -Force | Out-Null
                    return 0
                }

                Invoke-PackAndStage -ProjectJson $pj -FeedPath $feed -OutputPath (Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsOutput-$(New-Guid)") -UipcliArgs @() -NoBump -UipcliExe 'fake.exe' | Out-Null
                (Get-Content $pj -Raw) | Should -Match '"projectVersion":\s*"1\.0\.0"'
            }
        }
    }
}

Describe 'Invoke-CpmfUipsPack' {

    BeforeEach {
        $script:tmpRoot     = Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsPackTest-$(New-Guid)"
        $script:tmpFeed     = Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsFeed-$(New-Guid)"
        $script:projectJson = Join-Path $script:tmpRoot 'project.json'
        $null = New-Item -ItemType Directory -Path $script:tmpRoot -Force
        Set-Content $script:projectJson '{"projectVersion": "1.0.0", "name": "TestProject"}'
    }

    AfterEach {
        Remove-Item $script:tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $script:tmpFeed -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Orchestration' {
        It 'calls Install-CpmfUipsPackCommandLineTool unless -SkipInstall' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe'; DotnetDir = 'C:\fake' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                Mock Invoke-PackAndStage {
                    param($ProjectJson, $FeedPath, $UipcliArgs, $NoBump, $UipcliExe, $OutputPath)
                    'C:\Users\Public\UiPath.CLI.Windows\pack-output\fake.nupkg'
                }

                Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed
                Should -Invoke Install-CpmfUipsPackCommandLineTool -Times 1

                Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -SkipInstall
                Should -Invoke Install-CpmfUipsPackCommandLineTool -Times 1  # still only 1 total
            }
        }

        It 'returns the result from Invoke-PackAndStage' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe'; DotnetDir = 'C:\fake' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                Mock Invoke-PackAndStage {
                    param($ProjectJson, $FeedPath, $UipcliArgs, $NoBump, $UipcliExe, $OutputPath)
                    'C:\Users\Public\UiPath.CLI.Windows\pack-output\Test.1.1.0.nupkg'
                }

                $result = Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -SkipInstall
                $result | Should -Be 'C:\Users\Public\UiPath.CLI.Windows\pack-output\Test.1.1.0.nupkg'
            }
        }
    }

    Context '-Version' {
        It 'prints the module version and exits' {
            { Invoke-CpmfUipsPack -Version } | Should -Not -Throw
            (Invoke-CpmfUipsPack -Version) | Should -BeLike 'CpmfUipsPack *'
        }
    }

    Context '-UseWorktree' {
        It 'does not modify the original project.json' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe'; DotnetDir = 'C:\fake' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                Mock Get-GitWorktreePath { Join-Path ([System.IO.Path]::GetTempPath()) "wt-test-$(New-Guid)" }
                Mock Invoke-GitWorktree { param($RepoRoot, $WorktreePath, $ScriptBlock); & $ScriptBlock $WorktreePath }
                Mock Invoke-PackAndStage {
                    param($ProjectJson, $FeedPath, $UipcliArgs, $NoBump, $UipcliExe, $OutputPath)
                    'C:\Users\Public\UiPath.CLI.Windows\pack-output\fake.nupkg'
                }
                Mock -CommandName 'git' -MockWith { 'C:\repos\MyProject'; $global:LASTEXITCODE = 0 }

                $originalContent = Get-Content $pj -Raw
                Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -UseWorktree -SkipInstall | Out-Null
                Get-Content $pj -Raw | Should -Be $originalContent
            }
        }

        It 'always removes the worktree (success and failure)' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe'; DotnetDir = 'C:\fake' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                Mock Get-GitWorktreePath { Join-Path ([System.IO.Path]::GetTempPath()) "wt-test-$(New-Guid)" }
                $script:removed = $false
                Mock Invoke-GitWorktree {
                    param($RepoRoot, $WorktreePath, $ScriptBlock)
                    try { & $ScriptBlock $WorktreePath } finally { $script:removed = $true }
                }
                Mock Invoke-PackAndStage { }
                Mock -CommandName 'git' -MockWith { 'C:\repos\MyProject'; $global:LASTEXITCODE = 0 }

                Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -UseWorktree -SkipInstall | Out-Null
                $script:removed | Should -Be $true
            }
        }
    }

    Context 'Prerequisite check' {
        It 'throws when git is absent and -UseWorktree is requested' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Test-CpmfUipsPackPrerequisites { throw 'git executable not found on PATH.' }

                { Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -UseWorktree -SkipInstall } |
                    Should -Throw '*git executable not found*'
            }
        }
    }

    Context '-ConfigFile' {
        It 'applies FeedPath from config when not supplied explicitly' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                $cfgPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.psd1'
                Set-Content $cfgPath "@{ FeedPath = '$feed' }"

                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe'; DotnetDir = 'C:\fake' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                $script:capturedFeed = $null
                Mock Invoke-PackAndStage {
                    param($ProjectJson, $FeedPath, $UipcliArgs, $NoBump, $UipcliExe, $OutputPath)
                    $script:capturedFeed = $FeedPath
                    'C:\Users\Public\UiPath.CLI.Windows\pack-output\fake.nupkg'
                }

                Invoke-CpmfUipsPack -ProjectJson $pj -ConfigFile $cfgPath -SkipInstall | Out-Null
                $script:capturedFeed | Should -Be $feed

                Remove-Item $cfgPath -Force -ErrorAction SilentlyContinue
            }
        }

        It 'applies OutputPath from config when not supplied explicitly' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                $cfgPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.psd1'
                $outputBase = Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsOutput-$(New-Guid)"
                Set-Content $cfgPath "@{ OutputPath = '$outputBase' }"

                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe'; DotnetDir = 'C:\fake' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                $script:capturedOutputDir = $null
                Mock Invoke-PackAndStage {
                    param($ProjectJson, $FeedPath, $UipcliArgs, $NoBump, $UipcliExe, $TargetTag, $OutputPath)
                    $script:capturedOutputDir = $OutputPath
                    'C:\Users\Public\UiPath.CLI.Windows\pack-output\fake.nupkg'
                }

                Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -ConfigFile $cfgPath -SkipInstall | Out-Null
                $script:capturedOutputDir | Should -Be $outputBase

                Remove-Item $cfgPath -Force -ErrorAction SilentlyContinue
            }
        }

        It 'explicit parameter overrides config value' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                $cfgPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.psd1'
                Set-Content $cfgPath "@{ FeedPath = 'C:\Users\Public\UiPath.CLI.Windows\should-not-be-used' }"

                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe'; DotnetDir = 'C:\fake' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                $script:capturedFeed = $null
                Mock Invoke-PackAndStage {
                    param($ProjectJson, $FeedPath, $UipcliArgs, $NoBump, $UipcliExe, $OutputPath)
                    $script:capturedFeed = $FeedPath
                    'C:\Users\Public\UiPath.CLI.Windows\pack-output\fake.nupkg'
                }

                Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -ConfigFile $cfgPath -SkipInstall | Out-Null
                $script:capturedFeed | Should -Be $feed

                Remove-Item $cfgPath -Force -ErrorAction SilentlyContinue
            }
        }

        It 'throws when ConfigFile path does not exist' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                { Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -ConfigFile 'C:\no-such-file.psd1' -SkipInstall } |
                    Should -Throw '*not found*'
            }
        }
    }
}
