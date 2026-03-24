function Uninstall-UipathcliTool {
<#
.SYNOPSIS
    Removes the uipathcli binary directory and cleans its PATH entry from the
    user environment registry.

.PARAMETER ToolBase
    Root directory used during installation. Defaults to %LOCALAPPDATA%\cpmf\tools.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ToolBase = (Join-Path $env:LOCALAPPDATA 'cpmf\tools')
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $p = Get-CpmfUipsToolPaths -ToolBase $ToolBase

    Write-Verbose "[Uninstall] Removing uipathcli ..."
    if (Test-Path $p.UipathcliDir) {
        if ($PSCmdlet.ShouldProcess($p.UipathcliDir, 'Remove uipathcli directory')) {
            Remove-Item $p.UipathcliDir -Recurse -Force
            Write-Verbose "[Uninstall] Removed $($p.UipathcliDir)"
        }
    } else {
        Write-Verbose "[Uninstall] $($p.UipathcliDir) not found — skipping"
    }

    $token = '%LOCALAPPDATA%\cpmf\tools\uipathcli'
    if ($PSCmdlet.ShouldProcess("PATH (User): $token", 'Remove entry')) {
        if (Remove-FromUserPath $token) {
            Write-Verbose "[Uninstall] Removed $token from user PATH"
        } else {
            Write-Verbose "[Uninstall] $token not found in user PATH — skipping"
        }
    }

    Write-Verbose "[Uninstall] Done"
}
