<#
.SYNOPSIS
    Configures git to use the tracked hooks/ directory for this repository.

.DESCRIPTION
    Runs `git config core.hooksPath ./hooks` so that the pre-push hook in
    hooks/pre-push is picked up automatically. Run once after cloning.

.EXAMPLE
    pwsh -File scripts/Install-GitHooks.ps1
#>
[CmdletBinding()]
param()

$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot

git config core.hooksPath ./hooks
Write-Host '[Install-GitHooks] core.hooksPath set to ./hooks'
Write-Host '[Install-GitHooks] pre-push hook is now active.'
