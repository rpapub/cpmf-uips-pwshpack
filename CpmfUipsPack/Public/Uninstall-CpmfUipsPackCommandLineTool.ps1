function Uninstall-CpmfUipsPackCommandLineTool {
<#
.SYNOPSIS
    Removes the uipcli and .NET runtime tool directories and cleans DOTNET_ROOT
    and the associated PATH entry from the user environment registry.

.PARAMETER CliVersion
    UiPath CLI version to remove. Defaults to 23.10.2.6.

.PARAMETER ToolBase
    Root directory used during installation. Defaults to %LOCALAPPDATA%\cpmf\tools.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$CliVersion = '23.10.2.6',
        [string]$ToolBase   = (Join-Path $env:LOCALAPPDATA 'cpmf\tools')
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $p = Get-CpmfUipsToolPaths -CliVersion $CliVersion -ToolBase $ToolBase

    Write-Verbose "[Uninstall] Removing uipcli $CliVersion ..."
    if (Test-Path $p.CliToolDir) {
        if ($PSCmdlet.ShouldProcess($p.CliToolDir, 'Remove uipcli tool directory')) {
            Remove-Item $p.CliToolDir -Recurse -Force
            Write-Verbose "[Uninstall] Removed $($p.CliToolDir)"
        }
    } else {
        Write-Verbose "[Uninstall] $($p.CliToolDir) not found — skipping"
    }

    Write-Verbose "[Uninstall] Removing .NET runtime ..."
    if (Test-Path $p.DotnetDir) {
        if ($PSCmdlet.ShouldProcess($p.DotnetDir, 'Remove .NET runtime directory')) {
            Remove-Item $p.DotnetDir -Recurse -Force
            Write-Verbose "[Uninstall] Removed $($p.DotnetDir)"
        }
    } else {
        Write-Verbose "[Uninstall] $($p.DotnetDir) not found — skipping"
    }

    Write-Verbose "[Uninstall] Cleaning user environment variables ..."

    # DOTNET_ROOT is only set by the classic (23.x/.NET 6) install path
    if ($p.Generation -eq 'classic') {
        if ($PSCmdlet.ShouldProcess('DOTNET_ROOT (User)', 'Clear environment variable')) {
            [Environment]::SetEnvironmentVariable('DOTNET_ROOT', $null, 'User')
            Write-Verbose "[Uninstall] Cleared DOTNET_ROOT"
        }
    }

    if ($PSCmdlet.ShouldProcess("PATH (User): $($p.DotnetToken)", 'Remove entry')) {
        if (Remove-FromUserPath $p.DotnetToken) {
            Write-Verbose "[Uninstall] Removed $($p.DotnetToken) from user PATH"
        } else {
            Write-Verbose "[Uninstall] $($p.DotnetToken) not found in user PATH — skipping"
        }
    }

    Write-Verbose "[Uninstall] Done"
}
