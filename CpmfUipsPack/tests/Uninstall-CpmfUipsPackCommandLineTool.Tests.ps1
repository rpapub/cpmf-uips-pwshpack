#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../CpmfUipsPack.psd1') -Force
}

Describe 'Uninstall-CpmfUipsPackCommandLineTool' {

    BeforeEach {
        $script:tmpToolBase          = Join-Path ([System.IO.Path]::GetTempPath()) "CpmfUipsPackTest-$(New-Guid)"
        $script:cliVersionClassic    = '23.10.2.6'
        $script:cliVersionDotnetTool = '25.10.15'
        $script:savedDotnetRoot      = [Environment]::GetEnvironmentVariable('DOTNET_ROOT', 'User')
        $script:savedPath            = [Environment]::GetEnvironmentVariable('PATH', 'User')
    }

    AfterEach {
        Remove-Item $script:tmpToolBase -Recurse -Force -ErrorAction SilentlyContinue
        [Environment]::SetEnvironmentVariable('DOTNET_ROOT', $script:savedDotnetRoot, 'User')
        [Environment]::SetEnvironmentVariable('PATH', $script:savedPath, 'User')
    }

    It 'removes CliToolDir and DotnetDir when they exist' {
        InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase; cv = $script:cliVersionDotnetTool } {
            param($tb, $cv)
            $p = Get-CpmfUipsToolPaths -CliVersion $cv -ToolBase $tb
            $null = New-Item -ItemType Directory -Path $p.CliToolDir -Force
            $null = New-Item -ItemType Directory -Path $p.DotnetDir  -Force

            Uninstall-CpmfUipsPackCommandLineTool -CliVersion $cv -ToolBase $tb

            Test-Path $p.CliToolDir | Should -Be $false
            Test-Path $p.DotnetDir  | Should -Be $false
        }
    }

    It 'does not throw when directories are absent' {
        { Uninstall-CpmfUipsPackCommandLineTool -CliVersion $script:cliVersionDotnetTool -ToolBase $script:tmpToolBase } | Should -Not -Throw
    }

    Context 'DOTNET_ROOT handling' {
        It 'clears DOTNET_ROOT for classic path (23.x)' {
            [Environment]::SetEnvironmentVariable('DOTNET_ROOT', 'C:\some\path', 'User')
            Uninstall-CpmfUipsPackCommandLineTool -CliVersion $script:cliVersionClassic -ToolBase $script:tmpToolBase
            [Environment]::GetEnvironmentVariable('DOTNET_ROOT', 'User') | Should -BeNullOrEmpty
        }

        It 'does not clear DOTNET_ROOT for dotnet-tool path (25.10.x)' {
            [Environment]::SetEnvironmentVariable('DOTNET_ROOT', 'C:\some\path', 'User')
            Uninstall-CpmfUipsPackCommandLineTool -CliVersion $script:cliVersionDotnetTool -ToolBase $script:tmpToolBase
            [Environment]::GetEnvironmentVariable('DOTNET_ROOT', 'User') | Should -Be 'C:\some\path'
        }
    }

    It 'removes DotnetToken from user PATH' {
        InModuleScope CpmfUipsPack -Parameters @{ tb = $script:tmpToolBase; cv = $script:cliVersionDotnetTool } {
            param($tb, $cv)
            $p = Get-CpmfUipsToolPaths -CliVersion $cv -ToolBase $tb
            [Environment]::SetEnvironmentVariable('PATH', "$($p.DotnetToken);C:\foo", 'User')

            Uninstall-CpmfUipsPackCommandLineTool -CliVersion $cv -ToolBase $tb

            [Environment]::GetEnvironmentVariable('PATH', 'User') | Should -Not -BeLike "*$($p.DotnetToken)*"
        }
    }
}
