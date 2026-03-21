function Install-CpmfUipsPackConfig {
<#
.SYNOPSIS
    Scaffolds the user-level CpmfUipsPack config file at the XDG-inspired location:
        %LOCALAPPDATA%\cpmf\CpmfUipsPack\config.psd1

.DESCRIPTION
    Copies the bundled examples\uipath-pack.psd1 to the user config directory.
    All keys in the file are commented examples — edit the file to activate them.

    The user config is the lowest-priority config source. It is overridden by:
        env vars (UIPS_*)  >  -ConfigFile  >  explicit parameters

.PARAMETER Force
    Overwrite an existing config file. Without -Force, the command does nothing
    if the target file already exists.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $destPath = Join-Path $env:LOCALAPPDATA 'cpmf\CpmfUipsPack\config.psd1'
    $destDir  = Split-Path $destPath -Parent

    if ((Test-Path $destPath) -and -not $Force) {
        Write-Verbose "[Config] User config already exists at $destPath"
        Write-Verbose "[Config] Use -Force to overwrite."
        return
    }

    $examplePath = Join-Path $PSScriptRoot '..\examples\uipath-pack.psd1'
    $examplePath = (Resolve-Path $examplePath).Path

    if ($PSCmdlet.ShouldProcess($destPath, 'Create user config')) {
        $null = New-Item -ItemType Directory -Path $destDir -Force
        Copy-Item -LiteralPath $examplePath -Destination $destPath -Force
        Write-Verbose "[Config] User config created at $destPath"
        Write-Verbose "[Config] Edit the file to activate any settings."
    }
}
