#Requires -Version 7
<#
.SYNOPSIS
    Bumps projectVersion, packs a UiPath project with uipcli, and stages the .nupkg
    to a local NuGet feed. With -Uninstall: removes installed tools and environment variables.

.DESCRIPTION
    Default (publish) mode:
      0. Idempotently installs .NET 6.0.36 runtimes (base + WindowsDesktop) into
         %LOCALAPPDATA%\cpmf\tools\dotnet\ — no admin rights required.
         Both runtimes are required: base provides dotnet.exe; WindowsDesktop is
         required by uipcli.
      1. Idempotently installs UiPath.CLI.Windows 23.10.2.6 into
         %LOCALAPPDATA%\cpmf\tools\uipcli-23.10.2.6\ via classic nupkg extraction.
      2. Bumps projectVersion in project.json by the smallest possible increment
         using a targeted regex replace that preserves all other formatting:
           - prerelease numeric suffix present  →  alpha.1 → alpha.2
           - build metadata numeric suffix      →  +build.1 → +build.2
           - plain release version              →  0.1.0 → 0.2.0  (minor)
      3. Packs the project with uipcli. Any extra flags can be passed via -UipcliArgs,
         e.g. -UipcliArgs '--traceLevel','Verbose','--outputType','Tests'
      4. Copies the resulting .nupkg to C:\Users\Public\nugetfeed\ (created if absent).

    Uninstall mode (-Uninstall):
      Removes the tool directories and cleans DOTNET_ROOT and the PATH entry
      from the user environment registry (handles both token and expanded forms).

.NOTES
    Run from any directory; paths are resolved relative to this script's location.
    No admin rights required for any step.
    PATH is persisted using the unexpanded token %LOCALAPPDATA%\cpmf\tools\dotnet
    so it remains valid if the user profile path ever changes.
#>

[CmdletBinding()]
param(
    [string]$ProjectJson = (Join-Path $PSScriptRoot '..\project.json'),
    [switch]$Uninstall,
    [string[]]$UipcliArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Paths
#   $DotnetDir      — expanded at runtime, used for filesystem operations
#   $DotnetDirToken — unexpanded, stored in the registry PATH (REG_EXPAND_SZ)
#   $DotnetMarker   — presence means both base + WindowsDesktop are installed
# ---------------------------------------------------------------------------
$CliVersion      = '23.10.2.6'
$ToolBase        = Join-Path $env:LOCALAPPDATA 'cpmf\tools'
$DotnetDir       = Join-Path $ToolBase 'dotnet'
$DotnetDirToken  = '%LOCALAPPDATA%\cpmf\tools\dotnet'
$DotnetMarker    = Join-Path $DotnetDir "shared\Microsoft.WindowsDesktop.App\6.0.36"
$CliToolDir      = Join-Path $ToolBase "uipcli-$CliVersion"
$UipcliExe       = Join-Path $CliToolDir 'extracted\tools\uipcli.exe'
$ProjectJson     = (Resolve-Path $ProjectJson).Path
$ProjectRoot     = Split-Path $ProjectJson -Parent
$NugetFeed       = 'C:\Users\Public\nugetfeed'

# ---------------------------------------------------------------------------
# Helpers — user PATH manipulation using unexpanded token form
# ---------------------------------------------------------------------------
function Add-ToUserPath {
    param([string]$Token)
    $expanded = [Environment]::ExpandEnvironmentVariables($Token)
    $raw      = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $entries  = if ([string]::IsNullOrEmpty($raw)) { @() }
                else { $raw -split ';' | Where-Object { $_ -ne '' } }
    $present  = $entries | Where-Object { $_ -ieq $Token -or $_ -ieq $expanded }
    if ($present) { return $false }
    $newRaw = ($Token + ';' + ($entries -join ';')).TrimEnd(';')
    [Environment]::SetEnvironmentVariable('PATH', $newRaw, 'User')
    return $true
}

function Remove-FromUserPath {
    param([string]$Token)
    $expanded = [Environment]::ExpandEnvironmentVariables($Token)
    $raw      = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ([string]::IsNullOrEmpty($raw)) { return $false }
    $entries  = $raw -split ';' | Where-Object { $_ -ne '' -and $_ -ne $Token -and $_ -ne $expanded }
    $newRaw   = $entries -join ';'
    if ($newRaw -eq $raw) { return $false }
    [Environment]::SetEnvironmentVariable('PATH', $newRaw, 'User')
    return $true
}

# ---------------------------------------------------------------------------
# Uninstall mode
# ---------------------------------------------------------------------------
if ($Uninstall) {
    Write-Host "[Uninstall] Removing uipcli $CliVersion ..."
    if (Test-Path $CliToolDir) {
        Remove-Item $CliToolDir -Recurse -Force
        Write-Host "[Uninstall] Removed $CliToolDir"
    } else {
        Write-Host "[Uninstall] $CliToolDir not found — skipping"
    }

    Write-Host "[Uninstall] Removing .NET runtime ..."
    if (Test-Path $DotnetDir) {
        Remove-Item $DotnetDir -Recurse -Force
        Write-Host "[Uninstall] Removed $DotnetDir"
    } else {
        Write-Host "[Uninstall] $DotnetDir not found — skipping"
    }

    Write-Host "[Uninstall] Cleaning user environment variables ..."
    [Environment]::SetEnvironmentVariable('DOTNET_ROOT', $null, 'User')
    Write-Host "[Uninstall] Cleared DOTNET_ROOT"

    if (Remove-FromUserPath $DotnetDirToken) {
        Write-Host "[Uninstall] Removed $DotnetDirToken from user PATH"
    } else {
        Write-Host "[Uninstall] $DotnetDirToken not found in user PATH — skipping"
    }

    Write-Host "[Uninstall] Done"
    return
}

# ---------------------------------------------------------------------------
# Step 0 — idempotent .NET 6.0.36 install (base + WindowsDesktop, no admin)
# ---------------------------------------------------------------------------
Write-Host "[Publish] Checking .NET 6.0.36 WindowsDesktop runtime in $DotnetDir"

if (Test-Path $DotnetMarker) {
    Write-Host "[Publish] .NET 6.0.36 already installed — skipping"
} else {
    Write-Host "[Publish] Installing .NET 6.0.36 into $DotnetDir ..."
    $null = New-Item -ItemType Directory -Path $DotnetDir -Force
    $installScript = Join-Path ([System.IO.Path]::GetTempPath()) 'dotnet-install.ps1'

    try {
        Invoke-WebRequest `
            -Uri 'https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.ps1' `
            -OutFile $installScript `
            -UseBasicParsing

        # Base runtime first — provides dotnet.exe host
        Write-Host "[Publish] Installing base runtime ..."
        & $installScript -Runtime dotnet -Version 6.0.36 -InstallDir $DotnetDir
        if (-not (Test-Path (Join-Path $DotnetDir 'dotnet.exe'))) {
            throw "Base runtime install failed — dotnet.exe not found in $DotnetDir"
        }

        # WindowsDesktop runtime — required by uipcli (Microsoft.WindowsDesktop.App)
        Write-Host "[Publish] Installing WindowsDesktop runtime ..."
        & $installScript -Runtime windowsdesktop -Version 6.0.36 -InstallDir $DotnetDir
        if (-not (Test-Path $DotnetMarker)) {
            throw "WindowsDesktop runtime install failed — marker not found: $DotnetMarker"
        }
    } finally {
        Remove-Item $installScript -Force -ErrorAction SilentlyContinue
    }

    # Persist PATH using unexpanded token (portable; stored as REG_EXPAND_SZ)
    if (Add-ToUserPath $DotnetDirToken) {
        Write-Host "[Publish] Added $DotnetDirToken to user PATH"
    }
    # DOTNET_ROOT stored expanded (REG_SZ — Windows does not expand it automatically)
    [Environment]::SetEnvironmentVariable('DOTNET_ROOT', $DotnetDir, 'User')
    Write-Host "[Publish] .NET 6.0.36 installed at $DotnetDir"
}

# Ensure current session sees the local runtime
$env:DOTNET_ROOT = $DotnetDir
if ($env:PATH -notlike "*$DotnetDir*") {
    $env:PATH = "$DotnetDir;$env:PATH"
}

# ---------------------------------------------------------------------------
# Step 1 — idempotent uipcli install (classic nupkg)
# ---------------------------------------------------------------------------
Write-Host "[Publish] Checking uipcli $CliVersion in $CliToolDir"

if (Test-Path $UipcliExe) {
    Write-Host "[Publish] uipcli $CliVersion already installed — skipping"
} else {
    $feedBase     = 'https://uipath.pkgs.visualstudio.com/Public.Feeds/_packaging/UiPath-Official/nuget/v3/flat2/uipath.cli.windows'
    $nupkgUrl     = "$feedBase/$CliVersion/uipath.cli.windows.$CliVersion.nupkg"
    $downloadPath = Join-Path $CliToolDir 'uipcli.nupkg'
    $null = New-Item -ItemType Directory -Path $CliToolDir -Force

    try {
        Write-Host "[Publish] Downloading uipcli $CliVersion ..."
        Invoke-WebRequest -Uri $nupkgUrl -OutFile $downloadPath -UseBasicParsing
        Expand-Archive -Path $downloadPath -DestinationPath (Join-Path $CliToolDir 'extracted') -Force
        if (-not (Test-Path $UipcliExe)) {
            throw "uipcli extraction failed — exe not found at $UipcliExe"
        }
    } catch {
        # Clean up partial extraction so the next run retries cleanly
        Remove-Item $CliToolDir -Recurse -Force -ErrorAction SilentlyContinue
        throw
    } finally {
        Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
    }

    Write-Host "[Publish] Installed uipcli $CliVersion at $UipcliExe"
}

# ---------------------------------------------------------------------------
# Step 2 — version bump (targeted regex — preserves all other JSON formatting)
# ---------------------------------------------------------------------------
Write-Host "[Publish] Reading $ProjectJson"
$raw = Get-Content $ProjectJson -Raw
if ($raw -notmatch '"projectVersion"\s*:\s*"([^"]*)"') {
    throw "projectVersion key not found in $ProjectJson"
}
$current = $Matches[1]
Write-Host "[Publish] Current version: $current"

$newVersion = if ($current -match '^(\d+\.\d+\.\d+)-(.+)$') {
    $base = $Matches[1]; $pre = $Matches[2]
    $bumped = if ($pre -match '^(.+\.)(\d+)$') { "$($Matches[1])$([int]$Matches[2] + 1)" } else { "$pre.1" }
    "$base-$bumped"
} elseif ($current -match '^(\d+\.\d+\.\d+)\+(.+)$') {
    $base = $Matches[1]; $build = $Matches[2]
    $bumped = if ($build -match '^(.+\.)(\d+)$') { "$($Matches[1])$([int]$Matches[2] + 1)" } else { "$build.1" }
    "$base+$bumped"
} else {
    $parts = $current -split '\.'
    if ($parts.Count -ne 3) { throw "Cannot parse version '$current' — expected major.minor.patch" }
    "$($parts[0]).$([int]$parts[1] + 1).0"
}

Write-Host "[Publish] New version:     $newVersion"
$updated = $raw -replace '("projectVersion"\s*:\s*")[^"]*(")', "`${1}$newVersion`${2}"
[System.IO.File]::WriteAllText($ProjectJson, $updated, (New-Object System.Text.UTF8Encoding $false))
Write-Host "[Publish] project.json updated"

# ---------------------------------------------------------------------------
# Step 3 — pack
# ---------------------------------------------------------------------------
$OutputDir = Join-Path $ProjectRoot '.pack-output'
$null = New-Item -ItemType Directory -Path $OutputDir -Force

Write-Host "[Publish] Packing with uipcli"
$packArgs = @('package', 'pack', $ProjectJson, '-o', $OutputDir)
if ($env:UIPATH_DISABLE_TELEMETRY) { $packArgs += '--disableTelemetry' }
if ($UipcliArgs.Count -gt 0) { $packArgs += $UipcliArgs }
& $UipcliExe @packArgs
if ($LASTEXITCODE -ne 0) { throw "uipcli pack failed (exit $LASTEXITCODE)" }

# ---------------------------------------------------------------------------
# Step 4 — copy to local NuGet feed
# ---------------------------------------------------------------------------
$null = New-Item -ItemType Directory -Path $NugetFeed -Force

$nupkg = Get-ChildItem -Path $OutputDir -Filter '*.nupkg' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $nupkg) { throw "No .nupkg found in $OutputDir after pack" }

$dest = Join-Path $NugetFeed $nupkg.Name
Copy-Item -Path $nupkg.FullName -Destination $dest -Force
Write-Host "[Publish] Copied: $($nupkg.Name) → $NugetFeed"
Write-Host "[Publish] Done"
