<#
.SYNOPSIS
    Installs CpmfUipsPack from a local repo copy into the user PSModulePath,
    then runs the full Pester suite against that installed copy.

.DESCRIPTION
    Simulates the user experience of a deployed module without requiring a
    PSGallery publish. Distinct from in-repo testing (which loads the module
    directly by path).

    Flow:
      1. Copy  <RepoRoot>\CpmfUipsPack\ → <UserModules>\CpmfUipsPack\
      2. Import the module by name (not by path)
      3. Run Pester against the installed copy's tests\
      4. Report pass/fail
      5. Optionally remove the installed copy (-Cleanup)

.PARAMETER RepoRoot
    Path to the repository root. Defaults to the parent of this script's directory.

.PARAMETER Cleanup
    Remove the installed module copy after the test run (pass or fail).

.PARAMETER SkipInstall
    Skip step 1 (copy). Useful when you want to re-run tests against a copy
    that is already in place.

.EXAMPLE
    # Run from anywhere
    pwsh -File 'D:\github.com\cprima\gist_Invoke-UiPathPack_04ae-1fa6c8\scripts\Test-LocalInstall.ps1'

.EXAMPLE
    # Run and clean up afterwards
    .\scripts\Test-LocalInstall.ps1 -Cleanup

.EXAMPLE
    # Run a live pack against the repo fixture project
    .\scripts\Test-LocalInstall.ps1 -PackFixture

.PARAMETER PackFixture
    After the Pester run, invoke Invoke-CpmfUipsPack against the repo-local
    MinimalProcess fixture (CpmfUipsPack\tests\fixtures\MinimalProcess\project.json).
    Requires uipcli to be installed.

.NOTES
    For the PSGallery variant, replace step 1 with:
        Install-Module CpmfUipsPack -Repository PSGallery -Scope CurrentUser -Force
    The rest of the script (steps 2-5) is identical.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot  = (Split-Path $PSScriptRoot -Parent),
    [switch]$Cleanup,
    [switch]$SkipInstall,
    [switch]$PackFixture
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleName  = 'CpmfUipsPack'
$moduleSource = Join-Path $RepoRoot $moduleName
$userModules  = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
$installDest  = Join-Path $userModules $moduleName

# ── Step 1: copy to user PSModulePath ────────────────────────────────────────
if (-not $SkipInstall) {
    if (-not (Test-Path $moduleSource)) {
        throw "Module source not found: $moduleSource"
    }

    Write-Host "[Test-LocalInstall] Copying $moduleName → $installDest"
    if (Test-Path $installDest) {
        Remove-Item $installDest -Recurse -Force
    }
    $null = New-Item -ItemType Directory -Path $userModules -Force
    Copy-Item -LiteralPath $moduleSource -Destination $installDest -Recurse -Force
    Write-Host "[Test-LocalInstall] Copy complete."
} else {
    Write-Host "[Test-LocalInstall] -SkipInstall: using existing copy at $installDest"
}

if (-not (Test-Path (Join-Path $installDest "$moduleName.psd1"))) {
    throw "Installed manifest not found at $installDest\$moduleName.psd1 — copy may have failed."
}

# ── Step 2: import by name ────────────────────────────────────────────────────
Remove-Module $moduleName -Force -ErrorAction SilentlyContinue
Write-Host "[Test-LocalInstall] Importing $moduleName by name..."
Import-Module $moduleName -Force

$importedFrom = (Get-Module $moduleName).ModuleBase
Write-Host "[Test-LocalInstall] Loaded from: $importedFrom"
if ($importedFrom -ne $installDest) {
    Write-Warning "[Test-LocalInstall] Module loaded from unexpected location: $importedFrom (expected $installDest)"
}

# ── Step 3: run Pester against the installed copy's tests ────────────────────
$testsPath = Join-Path $installDest 'tests'
Write-Host "[Test-LocalInstall] Running Pester tests from $testsPath ..."

$result = Invoke-Pester -Path $testsPath -Output Normal -PassThru

# ── Step 4: report ────────────────────────────────────────────────────────────
Write-Host ""
if ($result.FailedCount -eq 0) {
    Write-Host "[Test-LocalInstall] PASS — $($result.PassedCount) tests passed." -ForegroundColor Green
} else {
    Write-Host "[Test-LocalInstall] FAIL — $($result.FailedCount) failed, $($result.PassedCount) passed." -ForegroundColor Red
}

# ── Step 4b: optional live pack against repo fixture ─────────────────────────
$fixtureResult = $null
if ($PackFixture) {
    $fixtureJson = Join-Path $RepoRoot 'CpmfUipsPack' 'tests' 'fixtures' 'MinimalProcess' 'project.json'
    if (-not (Test-Path $fixtureJson)) {
        Write-Warning "[Test-LocalInstall] Fixture not found: $fixtureJson — skipping -PackFixture"
    } else {
        Write-Host "[Test-LocalInstall] Running live pack against fixture: $fixtureJson"
        try {
            $null = Invoke-CpmfUipsPack -ProjectJson $fixtureJson -NoBump
            $fixtureResult = $true
            Write-Host "[Test-LocalInstall] PASS — fixture pack succeeded." -ForegroundColor Green
        } catch {
            $fixtureResult = $false
            Write-Host "[Test-LocalInstall] FAIL — fixture pack failed: $_" -ForegroundColor Red
        }
    }
}

# ── Step 5: optional cleanup ──────────────────────────────────────────────────
if ($Cleanup) {
    Remove-Module $moduleName -Force -ErrorAction SilentlyContinue
    Remove-Item $installDest -Recurse -Force
    Write-Host "[Test-LocalInstall] Cleaned up: $installDest removed."
}

# Propagate failure to calling process
if ($result.FailedCount -gt 0) {
    exit 1
}
if ($fixtureResult -eq $false) {
    exit 1
}
