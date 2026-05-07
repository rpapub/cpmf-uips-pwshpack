#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../CpmfUipsPack.psd1') -Force
}

Describe 'Install-CpmfUipsPackCommandLineTool' {

    BeforeEach {
        $script:tmpToolBase          = Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsPackTest-$(New-Guid)"
        $script:cliVersionClassic    = '23.10.2.6'
        $script:cliVersionDotnetTool = '25.10.15'
    }

    AfterEach {
        Remove-Item $script:tmpToolBase -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'classic path (< 25.10.2)' {
        It 'does not call Invoke-WebRequest when DotnetMarker and UipcliExe both exist' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase; cv = $script:cliVersionClassic } {
                param($tb, $cv)
                $p = Get-CpmfUipsToolPaths -CliVersion $cv -ToolBase $tb
                $null = New-Item -ItemType Directory -Path (Split-Path $p.DotnetMarker) -Force
                $null = New-Item -ItemType File      -Path $p.DotnetMarker              -Force
                $null = New-Item -ItemType Directory -Path (Split-Path $p.UipcliExe)    -Force
                $null = New-Item -ItemType File      -Path $p.UipcliExe                 -Force

                Mock Invoke-NativeCommandCapture {
                    [pscustomobject]@{
                        ExitCode    = 0
                        StdOutLines = @('UiPath CLI')
                        StdErrLines = @()
                    }
                }
                Mock Invoke-WebRequest { throw 'Should not be called' }

                { Install-CpmfUipsPackCommandLineTool -CliVersion $cv -ToolBase $tb } | Should -Not -Throw
                Should -Invoke Invoke-WebRequest -Times 0
            }
        }

        It 'removes CliToolDir when ZipFile extraction fails' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase; cv = $script:cliVersionClassic } {
                param($tb, $cv)
                $p = Get-CpmfUipsToolPaths -CliVersion $cv -ToolBase $tb

                # Stub .NET as already installed
                $null = New-Item -ItemType Directory -Path (Split-Path $p.DotnetMarker) -Force
                $null = New-Item -ItemType File      -Path $p.DotnetMarker              -Force
                $null = New-Item -ItemType File      -Path (Join-Path $p.DotnetDir 'dotnet.exe') -Force

                # Invoke-WebRequest no-ops but leaves no file, so ZipFile::ExtractToDirectory throws
                Mock Invoke-WebRequest { }

                { Install-CpmfUipsPackCommandLineTool -CliVersion $cv -ToolBase $tb } | Should -Throw
                Test-Path $p.CliToolDir | Should -Be $false
            }
        }

        It 'throws when base runtime installer exits non-zero' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase; cv = $script:cliVersionClassic } {
                param($tb, $cv)

                Mock -CommandName 'Invoke-WebRequest' -MockWith {
                    param($Uri, $OutFile)
                    Set-Content $OutFile 'exit 1'
                }

                { Install-CpmfUipsPackCommandLineTool -CliVersion $cv -ToolBase $tb } | Should -Throw
            }
        }
    }

    Context 'dotnet-tool path (>= 25.10.2, default 25.10.15)' {
        It 'does not call Invoke-WebRequest when dotnet.exe and UipcliExe both exist' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase; cv = $script:cliVersionDotnetTool } {
                param($tb, $cv)
                $p = Get-CpmfUipsToolPaths -CliVersion $cv -ToolBase $tb
                $null = New-Item -ItemType Directory -Path $p.DotnetDir                 -Force
                $null = New-Item -ItemType File      -Path (Join-Path $p.DotnetDir 'dotnet.exe') -Force
                $null = New-Item -ItemType Directory -Path (Split-Path $p.UipcliExe)    -Force
                $null = New-Item -ItemType File      -Path $p.UipcliExe                 -Force

                Mock Invoke-NativeCommandCapture {
                    [pscustomobject]@{
                        ExitCode    = 0
                        StdOutLines = @('UiPath CLI')
                        StdErrLines = @()
                    }
                }
                Mock Invoke-WebRequest { throw 'Should not be called' }

                { Install-CpmfUipsPackCommandLineTool -CliVersion $cv -ToolBase $tb } | Should -Not -Throw
                Should -Invoke Invoke-WebRequest -Times 0
            }
        }

        It 'routes 25.10.2-20251124-7 (first dotnet-tool prerelease) to the dotnet-tool path' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase } {
                param($tb)
                $p = Get-CpmfUipsToolPaths -CliVersion '25.10.2-20251124-7' -ToolBase $tb
                $p.IsDotnetTool | Should -Be $true
                $p.Generation   | Should -Be 'dotnet-tool'
            }
        }

        It 'routes 25.10.1-20251105-9 (last classic prerelease) to the classic path' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase } {
                param($tb)
                $p = Get-CpmfUipsToolPaths -CliVersion '25.10.1-20251105-9' -ToolBase $tb
                $p.IsDotnetTool | Should -Be $false
                $p.Generation   | Should -Be 'classic'
            }
        }
    }

    Context 'version dispatch' {
        It 'routes 23.10.2.6 to classic' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase } {
                param($tb)
                $p = Get-CpmfUipsToolPaths -CliVersion '23.10.2.6' -ToolBase $tb
                $p.IsDotnetTool | Should -Be $false
                $p.Generation   | Should -Be 'classic'
            }
        }

        It 'routes 24.10.5.3 to classic' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase } {
                param($tb)
                $p = Get-CpmfUipsToolPaths -CliVersion '24.10.5.3' -ToolBase $tb
                $p.IsDotnetTool | Should -Be $false
                $p.Generation   | Should -Be 'classic'
            }
        }

        It 'routes 25.4.9414.17608 to classic' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase } {
                param($tb)
                $p = Get-CpmfUipsToolPaths -CliVersion '25.4.9414.17608' -ToolBase $tb
                $p.IsDotnetTool | Should -Be $false
                $p.Generation   | Should -Be 'classic'
            }
        }

        It 'routes 25.10.15 to dotnet-tool' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase } {
                param($tb)
                $p = Get-CpmfUipsToolPaths -CliVersion '25.10.15' -ToolBase $tb
                $p.IsDotnetTool | Should -Be $true
                $p.Generation   | Should -Be 'dotnet-tool'
            }
        }
    }
}
