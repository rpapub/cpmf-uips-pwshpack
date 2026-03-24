function Install-UipathcliTool {
<#
.SYNOPSIS
    Downloads and installs the uipathcli Go binary into the user profile
    (%LOCALAPPDATA%\cpmf\tools\uipathcli). No admin rights required. Idempotent.

.PARAMETER ToolBase
    Root directory for all installed tools. Defaults to %LOCALAPPDATA%\cpmf\tools.

.LINK
    https://github.com/UiPath/uipathcli
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ToolBase = (Join-Path $env:LOCALAPPDATA 'cpmf\tools')
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $p = Get-CpmfUipsToolPaths -ToolBase $ToolBase

    if (Test-Path $p.UipathcliExe) {
        Write-Verbose "[Install] uipathcli already installed — skipping"
        return
    }

    if (-not $PSCmdlet.ShouldProcess($p.UipathcliDir, 'Download uipathcli binary')) { return }

    Write-Progress -Activity 'CpmfUipsPack: install' -Status 'Downloading uipathcli …'
    Write-Verbose "[Install] Installing uipathcli into $($p.UipathcliDir) ..."

    $null = New-Item -ItemType Directory -Path $p.UipathcliDir -Force

    # Asset name pattern from https://github.com/UiPath/uipathcli/releases
    # Windows amd64 zip containing uipath.exe
    $downloadUrl = 'https://github.com/UiPath/uipathcli/releases/latest/download/uipathcli-windows-amd64.zip'
    $zipPath     = Join-Path $p.UipathcliDir 'uipathcli-windows-amd64.zip'

    try {
        Invoke-WebRequest `
            -Uri        $downloadUrl `
            -OutFile    $zipPath `
            -UseBasicParsing `
            -TimeoutSec 120

        Expand-Archive -Path $zipPath -DestinationPath $p.UipathcliDir -Force
        Remove-Item $zipPath -Force

        if (-not (Test-Path $p.UipathcliExe)) {
            throw "uipathcli download failed — binary not found at $($p.UipathcliExe)"
        }
    } catch {
        Remove-Item $p.UipathcliDir -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }

    $token = '%LOCALAPPDATA%\cpmf\tools\uipathcli'
    if (Add-ToUserPath $token) {
        Write-Verbose "[Install] Added $token to user PATH"
    }

    Write-Progress -Activity 'CpmfUipsPack: install' -Completed
    Write-Verbose "[Install] uipathcli installed at $($p.UipathcliExe)"
}
