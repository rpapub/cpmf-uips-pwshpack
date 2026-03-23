<#
.SYNOPSIS
    Runs PSScriptAnalyzer and Pester before a git push. Called by .git/hooks/pre-push.

.DESCRIPTION
    Exits with code 1 (blocking the push) if any PSScriptAnalyzer findings or
    Pester test failures are found. Pass -Verbose to see individual Pester test output.

.EXAMPLE
    # Run manually from repo root
    pwsh -File scripts/Invoke-PrePushChecks.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot

Write-Host '[pre-push] PSScriptAnalyzer ...'
$findings = Invoke-ScriptAnalyzer -Path ./CpmfUipsPack -Recurse -Settings ./CpmfUipsPack/PSScriptAnalyzerSettings.psd1
if ($findings) {
    $findings | ForEach-Object {
        Write-Host "$($_.Severity)  $($_.RuleName)  $($_.ScriptName):$($_.Line)  $($_.Message)"
    }
    Write-Host '[pre-push] FAIL: PSScriptAnalyzer found findings. Push blocked.'
    exit 1
}
Write-Host '[pre-push] PSScriptAnalyzer OK'

Write-Host '[pre-push] Pester ...'
$result = Invoke-Pester ./CpmfUipsPack/tests/ -Output Normal -PassThru
if ($result.FailedCount -gt 0) {
    Write-Host "[pre-push] FAIL: $($result.FailedCount) test(s) failed. Push blocked."
    exit 1
}
Write-Host "[pre-push] Pester OK ($($result.PassedCount) passed)"
