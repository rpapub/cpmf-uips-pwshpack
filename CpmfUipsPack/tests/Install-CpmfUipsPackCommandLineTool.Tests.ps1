#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../CpmfUipsPack.psd1') -Force
}

Describe 'Install-CpmfUipsPackCommandLineTool' {

    BeforeEach {
        $script:tmpToolBase = Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsPackTest-$(New-Guid)"
        $script:cliVersion  = '23.10.2.6'
    }

    AfterEach {
        Remove-Item $script:tmpToolBase -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Skips when already installed' {
        It 'does not call Invoke-WebRequest when DotnetMarker and UipcliExe both exist' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase; cv = $script:cliVersion } {
                param($tb, $cv)
                $p = Get-CpmfUipsToolPaths -CliVersion $cv -ToolBase $tb
                $null = New-Item -ItemType Directory -Path (Split-Path $p.DotnetMarker) -Force
                $null = New-Item -ItemType File      -Path $p.DotnetMarker              -Force
                $null = New-Item -ItemType Directory -Path (Split-Path $p.UipcliExe)    -Force
                $null = New-Item -ItemType File      -Path $p.UipcliExe                 -Force

                Mock Invoke-WebRequest { throw 'Should not be called' }

                { Install-CpmfUipsPackCommandLineTool -CliVersion $cv -ToolBase $tb } | Should -Not -Throw
                Should -Invoke Invoke-WebRequest -Times 0
            }
        }
    }

    Context 'Cleans up on failed extraction' {
        It 'removes CliToolDir when ZipFile extraction fails' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase; cv = $script:cliVersion } {
                param($tb, $cv)
                $p = Get-CpmfUipsToolPaths -CliVersion $cv -ToolBase $tb

                # Stub .NET as already installed
                $null = New-Item -ItemType Directory -Path (Split-Path $p.DotnetMarker) -Force
                $null = New-Item -ItemType File      -Path $p.DotnetMarker              -Force
                $null = New-Item -ItemType File      -Path (Join-Path $p.DotnetDir 'dotnet.exe') -Force

                # Invoke-WebRequest no-ops but leaves no file, so ZipFile::ExtractToDirectory throws
                Mock Invoke-WebRequest { }

                # Any exception during extraction should clean up CliToolDir
                { Install-CpmfUipsPackCommandLineTool -CliVersion $cv -ToolBase $tb } | Should -Throw
                Test-Path $p.CliToolDir | Should -Be $false
            }
        }
    }

    Context 'Throws on non-zero dotnet-install exit code' {
        It 'throws when base runtime installer exits non-zero' {
            InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase; cv = $script:cliVersion } {
                param($tb, $cv)

                Mock Invoke-WebRequest { }
                # Simulate installer creating no files and setting bad exit code
                Mock -CommandName 'Start-Process' { }
                # Intercept the dotnet-install script call by making dotnet.exe absent
                # The LASTEXITCODE guard fires before the file check so force it via a wrapper
                Mock -CommandName 'Invoke-WebRequest' -MockWith {
                    # Create the install script as a stub that exits 1
                    param($Uri, $OutFile)
                    Set-Content $OutFile 'exit 1'
                }

                { Install-CpmfUipsPackCommandLineTool -CliVersion $cv -ToolBase $tb } | Should -Throw
            }
        }
    }
}
