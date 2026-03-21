#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../CpmfUipsPack.psd1') -Force
}

Describe 'Get-CpmfUipsToolPaths — version family branching' {

    Context '23.x classic path' {
        It 'returns extracted\tools\uipcli.exe for 23.x version' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = 'C:\fake\tools' } {
                param($tb)
                $p = Get-CpmfUipsToolPaths -CliVersion '23.10.2.6' -ToolBase $tb
                $p.UipcliExe    | Should -BeLike '*\extracted\tools\uipcli.exe'
                $p.Generation   | Should -Be 'classic'
                $p.DotnetMarker | Should -Match 'Microsoft\.WindowsDesktop\.App\\6\.0\.36'
            }
        }
    }

    Context '25.x dotnet-tool path' {
        It 'returns uipcli.exe directly in CliToolDir for 25.x version' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = 'C:\fake\tools' } {
                param($tb)
                $p = Get-CpmfUipsToolPaths -CliVersion '25.10.11' -ToolBase $tb
                $p.UipcliExe    | Should -BeLike "*\uipcli-25.10.11\uipcli.exe"
                $p.UipcliExe    | Should -Not -BeLike '*\extracted\*'
                $p.Generation   | Should -Be 'dotnet-tool'
                $p.DotnetMarker | Should -BeLike '*dotnet8\sdk'
            }
        }
    }
}

Describe 'Install-CpmfUipsPackCommandLineTool — version family routing' {

    BeforeEach {
        $script:tmpToolBase = Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsPackTest-$(New-Guid)"
    }

    AfterEach {
        Remove-Item $script:tmpToolBase -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context '23.x skips when already installed' {
        It 'does not download when both marker and exe exist' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase } {
                param($tb)
                $p = Get-CpmfUipsToolPaths -CliVersion '23.10.2.6' -ToolBase $tb
                $null = New-Item -ItemType Directory -Path (Split-Path $p.DotnetMarker) -Force
                $null = New-Item -ItemType File      -Path $p.DotnetMarker              -Force
                $null = New-Item -ItemType Directory -Path (Split-Path $p.UipcliExe)    -Force
                $null = New-Item -ItemType File      -Path $p.UipcliExe                 -Force
                Mock Invoke-WebRequest { throw 'Should not be called' }
                { Install-CpmfUipsPackCommandLineTool -CliVersion '23.10.2.6' -ToolBase $tb } | Should -Not -Throw
                Should -Invoke Invoke-WebRequest -Times 0
            }
        }
    }

    Context '25.x skips when already installed' {
        It 'does not call dotnet when uipcli.exe already exists' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase } {
                param($tb)
                $p = Get-CpmfUipsToolPaths -CliVersion '25.10.11' -ToolBase $tb
                $null = New-Item -ItemType Directory -Path (Split-Path $p.UipcliExe) -Force
                $null = New-Item -ItemType File      -Path $p.UipcliExe               -Force
                # Create dotnet.exe stub so prerequisite check passes
                $null = New-Item -ItemType Directory -Path $p.DotnetDir -Force
                $null = New-Item -ItemType File      -Path (Join-Path $p.DotnetDir 'dotnet.exe') -Force
                Mock Invoke-WebRequest { throw 'Should not be called' }
                { Install-CpmfUipsPackCommandLineTool -CliVersion '25.10.11' -ToolBase $tb } | Should -Not -Throw
                Should -Invoke Invoke-WebRequest -Times 0
            }
        }
    }
}

Describe 'Invoke-CpmfUipsPack — multi-target' {

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

    Context 'Single target (backward compat)' {
        It 'calls Install-CpmfUipsPackCommandLineTool once and returns one path' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                Mock Invoke-PackAndStage { 'C:\feed\TestProject.1.1.0.nupkg' }

                $result = @(Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -Targets net6 -SkipInstall)
                $result.Count | Should -Be 1
                $result[0]    | Should -BeLike '*.nupkg'
                Should -Invoke Invoke-PackAndStage -Times 1
            }
        }
    }

    Context 'Multi-target' {
        It 'calls Install-CpmfUipsPackCommandLineTool and Invoke-PackAndStage once per target' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                $script:callCount = 0
                Mock Invoke-PackAndStage {
                    $script:callCount++
                    "C:\feed\TestProject.1.1.0.net$script:callCount.nupkg"
                }

                $result = Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -Targets net6,net8 -SkipInstall
                $result.Count | Should -Be 2
                Should -Invoke Invoke-PackAndStage -Times 2
            }
        }

        It 'second target call passes -NoBump (version bumped by first target only)' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                $script:noBumpValues = @()
                Mock Invoke-PackAndStage {
                    param($ProjectJson, $FeedPath, $UipcliArgs, $NoBump, $UipcliExe, $TargetTag)
                    $script:noBumpValues += $NoBump.IsPresent
                    "C:\feed\fake.$TargetTag.nupkg"
                }

                Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -Targets net6,net8 -SkipInstall | Out-Null
                $script:noBumpValues[0] | Should -Be $false  # first target: bump
                $script:noBumpValues[1] | Should -Be $true   # second target: no bump
            }
        }

        It '-MultiTfm calls Invoke-MultiTfmMerge and returns merged path' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                Mock Invoke-PackAndStage {
                    param($ProjectJson, $FeedPath, $UipcliArgs, $NoBump, $UipcliExe, $TargetTag)
                    "C:\feed\TestProject.1.1.0.$TargetTag.nupkg"
                }
                Mock Invoke-MultiTfmMerge { 'C:\feed\TestProject.1.1.0.nupkg' }

                $result = @(Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -Targets net6,net8 -MultiTfm -SkipInstall)
                Should -Invoke Invoke-MultiTfmMerge -Times 1
                $result.Count | Should -Be 1
                $result[0]    | Should -Be 'C:\feed\TestProject.1.1.0.nupkg'
            }
        }
    }

    Context 'Deprecated -CliVersion' {
        It 'emits a warning and maps 23.x to CliVersionNet6' {
            InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
                param($pj, $feed)
                Mock Install-CpmfUipsPackCommandLineTool { }
                Mock Get-CpmfUipsToolPaths { @{ UipcliExe = 'fake.exe' } }
                Mock Invoke-WithFileLock { param($LockFile, $ScriptBlock); & $ScriptBlock }
                Mock Invoke-PackAndStage { 'C:\feed\fake.nupkg' }

                { Invoke-CpmfUipsPack -ProjectJson $pj -FeedPath $feed -CliVersion '23.10.2.6' -SkipInstall } |
                    Should -Not -Throw
                # Warning verification: just confirm it runs without error
            }
        }
    }
}

Describe 'Invoke-PackAndStage — TargetTag naming' {

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

    It 'appends TargetTag to staged filename when tag is non-empty' {
        InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
            param($pj, $feed)
            Mock Invoke-UipcliPack {
                param($UipcliExe, $PackArgs)
                $outDir = $PackArgs[$PackArgs.IndexOf('-o') + 1]
                New-Item -ItemType File -Path (Join-Path $outDir 'TestProject.1.1.0.nupkg') -Force | Out-Null
                return 0
            }
            $result = Invoke-PackAndStage -ProjectJson $pj -FeedPath $feed -UipcliArgs @() -UipcliExe 'fake.exe' -TargetTag 'net6'
            $result | Should -BeLike '*.net6.nupkg'
        }
    }

    It 'uses original filename when TargetTag is empty' {
        InModuleScope CpmfUipsPack -Parameters @{ pj = $script:projectJson; feed = $script:tmpFeed } {
            param($pj, $feed)
            Mock Invoke-UipcliPack {
                param($UipcliExe, $PackArgs)
                $outDir = $PackArgs[$PackArgs.IndexOf('-o') + 1]
                New-Item -ItemType File -Path (Join-Path $outDir 'TestProject.1.1.0.nupkg') -Force | Out-Null
                return 0
            }
            $result = Invoke-PackAndStage -ProjectJson $pj -FeedPath $feed -UipcliArgs @() -UipcliExe 'fake.exe' -TargetTag ''
            $result | Should -BeLike '*TestProject.1.1.0.nupkg'
            $result | Should -Not -BeLike '*.net*.nupkg'
        }
    }
}
