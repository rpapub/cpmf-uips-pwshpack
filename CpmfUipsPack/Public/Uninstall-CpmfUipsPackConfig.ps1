function Uninstall-CpmfUipsPackConfig {
<#
.SYNOPSIS
    Removes the user-level CpmfUipsPack config file at the XDG-inspired location:
        %LOCALAPPDATA%\cpmf\CpmfUipsPack\config.psd1

.DESCRIPTION
    Complements Install-CpmfUipsPackConfig. Removes the config file and, if the
    parent directory is empty afterwards, removes the directory too.

.PARAMETER Force
    Suppress the confirmation prompt. Without -Force, ShouldProcess governs
    whether the deletion proceeds (respects -WhatIf and -Confirm).
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $configPath = Join-Path $env:LOCALAPPDATA 'cpmf\CpmfUipsPack\config.psd1'
    $configDir  = Split-Path $configPath -Parent

    if (-not (Test-Path $configPath)) {
        Write-Verbose "[Config] User config not found at $configPath — nothing to remove."
        return
    }

    if ($PSCmdlet.ShouldProcess($configPath, 'Remove user config file')) {
        Remove-Item -LiteralPath $configPath -Force
        Write-Verbose "[Config] Removed $configPath"

        # Remove the parent directory if it is now empty
        if ((Test-Path $configDir) -and @(Get-ChildItem $configDir).Count -eq 0) {
            Remove-Item -LiteralPath $configDir -Force
            Write-Verbose "[Config] Removed empty directory $configDir"
        }
    }
}
