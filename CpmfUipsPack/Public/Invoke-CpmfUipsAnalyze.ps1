function Invoke-CpmfUipsAnalyze {
<#
.SYNOPSIS
    Runs the UiPath workflow analyzer on a project using either uipcli or uipathcli.

.DESCRIPTION
    Invokes the workflow analyzer for one or more CLI targets and returns the
    analyzer output as [string[]]. No version bump or feed staging is performed.

.PARAMETER ProjectJson
    Path to the UiPath project.json.

.PARAMETER Backend
    CLI backend to use. 'uipcli' (default) or 'uipathcli'.

.PARAMETER Targets
    Which CLI versions to analyze with. Valid values: 'net6', 'net8'.
    Defaults to @('net6'). Only relevant when -Backend is 'uipcli'.

.PARAMETER CliVersionNet6
    uipcli version for the net6 target. Default: 23.10.2.6.

.PARAMETER CliVersionNet8
    uipcli version for the net8 target. Default: 25.10.11.

.PARAMETER SkipInstall
    Skip tool auto-install. Use when tools are already in place.

.PARAMETER ToolBase
    Tool root directory. Defaults to %LOCALAPPDATA%\cpmf\tools.

.PARAMETER ConfigFile
    Path to a .psd1 config file for default values. Explicit parameters always win.

.PARAMETER UipcliArgs
    Additional arguments passed verbatim to the CLI backend.

.OUTPUTS
    [string[]] Analyzer output lines.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string[]])]
    param(
        [string]  $ProjectJson    = (Join-Path $PSScriptRoot '..\project.json'),
        [ValidateSet('uipcli', 'uipathcli')]
        [string]  $Backend        = 'uipcli',
        [string[]]$Targets        = @('net6'),
        [string]  $CliVersionNet6 = '23.10.2.6',
        [string]  $CliVersionNet8 = '25.10.11',
        [switch]  $SkipInstall,
        [string]  $ToolBase       = (Join-Path $env:LOCALAPPDATA 'cpmf\tools'),
        [string]  $ConfigFile     = '',
        [string[]]$UipcliArgs     = @()
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Apply layered config defaults
    $cfg = Get-CpmfUipsPackEffectiveConfig -ConfigFile $ConfigFile

    foreach ($key in @('CliVersionNet6', 'CliVersionNet8', 'ToolBase')) {
        if (-not $PSBoundParameters.ContainsKey($key) -and $cfg.ContainsKey($key)) {
            Set-Variable -Name $key -Value $cfg[$key]
        }
    }
    foreach ($key in @('UipcliArgs', 'Targets')) {
        if (-not $PSBoundParameters.ContainsKey($key) -and $cfg.ContainsKey($key)) {
            Set-Variable -Name $key -Value ([string[]]$cfg[$key])
        }
    }
    foreach ($key in @('SkipInstall')) {
        if (-not $PSBoundParameters.ContainsKey($key) -and $cfg.ContainsKey($key) -and $cfg[$key]) {
            Set-Variable -Name $key -Value ([switch]$true)
        }
    }

    $validTargets = @('net6', 'net8')
    foreach ($t in $Targets) {
        if ($t -notin $validTargets) { throw "-Targets contains invalid value '$t'. Valid values: net6, net8" }
    }

    $ProjectJson = (Resolve-Path $ProjectJson).Path

    if (-not $SkipInstall) {
        if ($Backend -eq 'uipathcli') {
            Install-UipathcliTool -ToolBase $ToolBase
        } else {
            foreach ($target in $Targets) {
                $cliVer = if ($target -eq 'net6') { $CliVersionNet6 } else { $CliVersionNet8 }
                Install-CpmfUipsPackCommandLineTool -CliVersion $cliVer -ToolBase $ToolBase
            }
        }
    }

    $results = [System.Collections.Generic.List[string]]::new()

    $analyzeTargets = if ($Backend -eq 'uipathcli') { @('uipathcli') } else { $Targets }

    foreach ($target in $analyzeTargets) {
        if ($Backend -eq 'uipcli') {
            $cliVer = if ($target -eq 'net6') { $CliVersionNet6 } else { $CliVersionNet8 }
        } else {
            $cliVer = $CliVersionNet6  # placeholder; uipathcli exe path is backend-independent
        }
        $p = Get-CpmfUipsToolPaths -CliVersion $cliVer -ToolBase $ToolBase

        if (-not $PSCmdlet.ShouldProcess($ProjectJson, "Analyze with $Backend")) { continue }

        $label = if ($analyzeTargets.Count -gt 1) { " [$target]" } else { '' }
        Write-Progress -Activity "CpmfUipsAnalyze$label" -Status 'Analyzing …' -PercentComplete 10

        $exitCode = Invoke-CliBackend `
            -Op             analyze `
            -Backend        $Backend `
            -UipcliExe      $p.UipcliExe `
            -UipathcliExe   $p.UipathcliExe `
            -ProjectJson    $ProjectJson `
            -ExtraArgs      $UipcliArgs

        Write-Progress -Activity "CpmfUipsAnalyze$label" -Completed

        if ($exitCode -ne 0) { throw "analyze failed (exit $exitCode)" }
    }

    Write-Output ($results.ToArray())
}
