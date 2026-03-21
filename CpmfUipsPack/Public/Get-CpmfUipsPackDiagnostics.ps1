function Get-CpmfUipsPackDiagnostics {
<#
.SYNOPSIS
    Generates a pseudonymized diagnostic report suitable for pasting into a
    GitHub issue or support request.

.DESCRIPTION
    Collects environment information relevant to CpmfUipsPack installation and
    operation. All personal identifiers (username, computer name, domain) are
    replaced with placeholders. Environment variable values are never emitted —
    only whether each UIPS_* variable is set or not.

.EXAMPLE
    Get-CpmfUipsPackDiagnostics

    Prints a report block to the console. Copy and paste the output directly
    into https://github.com/rpapub/cpmf-uips-pwshpack/issues
#>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # ── helpers ───────────────────────────────────────────────────────────────
    function Redact([string]$text) {
        $text `
            -replace [regex]::Escape($env:USERNAME),     '<username>' `
            -replace [regex]::Escape($env:COMPUTERNAME), '<computername>' `
            -replace [regex]::Escape($env:USERDOMAIN),   '<domain>' `
            -replace [regex]::Escape($env:LOCALAPPDATA), '%LOCALAPPDATA%' `
            -replace [regex]::Escape($env:USERPROFILE),  '%USERPROFILE%'
    }

    function YesNo([bool]$val) { if ($val) { 'yes' } else { 'no' } }

    function DirStatus([string]$path) {
        if (Test-Path $path) {
            $items = @(Get-ChildItem $path -ErrorAction SilentlyContinue)
            "exists ($($items.Count) items)"
        } else {
            'not found'
        }
    }

    # ── gather ────────────────────────────────────────────────────────────────
    $os      = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    $arch    = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    $psVer   = $PSVersionTable.PSVersion.ToString()
    $modVer  = (Get-Module CpmfUipsPack -ErrorAction SilentlyContinue)?.Version?.ToString() ?? 'not loaded'

    # system dotnet versions
    $sysDotnet = & { dotnet --list-runtimes 2>$null } -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0 -or $null -eq $sysDotnet) { $sysDotnet = @('(dotnet not on PATH)') }

    # managed tool paths
    $toolBase   = Join-Path $env:LOCALAPPDATA 'cpmf\tools'
    $dotnet6Dir = Join-Path $toolBase 'dotnet'
    $dotnet8Dir = Join-Path $toolBase 'dotnet8'

    # uipcli versions installed under toolBase
    $cliDirs = @()
    if (Test-Path $toolBase) {
        $cliDirs = @(Get-ChildItem $toolBase -Directory -Filter 'uipcli-*' -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty Name)
    }

    # disk space on %LOCALAPPDATA% drive
    $drive     = Split-Path $env:LOCALAPPDATA -Qualifier
    $diskFree  = try {
        $d = Get-PSDrive ($drive.TrimEnd(':')) -ErrorAction Stop
        "$([math]::Round($d.Free / 1GB, 1)) GB free"
    } catch { 'unknown' }

    # UIPS_* env vars — present/absent only, never values
    $envVars = @(
        'UIPS_FEEDPATH', 'UIPS_TOOLBASE', 'UIPS_TARGETS',
        'UIPS_CLIVERSION_NET6', 'UIPS_CLIVERSION_NET8',
        'UIPS_WORKTREE_BASE', 'UIPS_USE_WORKTREE', 'UIPS_NO_BUMP'
    )
    $envLines = $envVars | ForEach-Object {
        $set = -not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
        "  $_ = $(if ($set) { 'set' } else { 'not set' })"
    }

    # ── render ────────────────────────────────────────────────────────────────
    $lines = @(
        '--- CpmfUipsPack diagnostics ---'
        ''
        "Module version   : $modVer"
        "PowerShell       : $psVer"
        "OS               : $(Redact $os)"
        "Architecture     : $arch"
        ''
        '-- Managed tool paths (%LOCALAPPDATA%\cpmf\tools\) --'
        "  dotnet  (net6) : $(DirStatus $dotnet6Dir)"
        "  dotnet8 (net8) : $(DirStatus $dotnet8Dir)"
        "  uipcli dirs    : $(if ($cliDirs.Count) { $cliDirs -join ', ' } else { 'none' })"
        "  drive space    : $diskFree"
        ''
        '-- System dotnet runtimes (dotnet --list-runtimes) --'
    ) + ($sysDotnet | ForEach-Object { "  $_" }) + @(
        ''
        '-- UIPS_* environment variables (set/not set only) --'
    ) + $envLines + @(
        ''
        '--- end ---'
    )

    Write-Output $lines
}
