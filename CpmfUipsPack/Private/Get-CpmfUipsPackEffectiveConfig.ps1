function Get-CpmfUipsPackEffectiveConfig {
<#
.SYNOPSIS
    Merges the three config sources into a single effective hashtable.
    Priority (lowest to highest): user config → env vars → project config.
    Explicit command-line parameters are NOT applied here — that is done by
    the caller (Invoke-CpmfUipsPack) using PSBoundParameters.

.DESCRIPTION
    Layer 1 — User config (XDG-inspired):
        %LOCALAPPDATA%\cpmf\CpmfUipsPack\config.psd1
        Loaded silently if present; missing file is not an error.

    Layer 2 — Environment variables:
        UIPS_FEEDPATH         → FeedPath
        UIPS_TOOLBASE         → ToolBase
        UIPS_TARGETS          → Targets  (comma-separated: 'net6,net8')
        UIPS_CLIVERSION_NET6  → CliVersionNet6
        UIPS_CLIVERSION_NET8  → CliVersionNet8
        UIPS_WORKTREE_BASE    → WorktreeBase
        UIPS_USE_WORKTREE     → UseWorktree  (any non-empty value = $true)
        UIPS_NO_BUMP          → NoBump        (any non-empty value = $true)

    Layer 3 — Project config (-ConfigFile):
        Explicit .psd1 file; same format as examples\uipath-pack.psd1.
        Values here override the user config and env vars.

.PARAMETER ConfigFile
    Path to the project-level .psd1 config file (the -ConfigFile parameter
    from Invoke-CpmfUipsPack). Empty string means no project config.
#>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$ConfigFile = ''
    )

    # ── Layer 1: user-level config ────────────────────────────────────────────
    $userConfigPath = Join-Path $env:LOCALAPPDATA 'cpmf\CpmfUipsPack\config.psd1'
    $userCfg = if (Test-Path -LiteralPath $userConfigPath) {
        Write-Verbose "[Config] Loading user config: $userConfigPath"
        Read-CpmfUipsPackConfig -Path $userConfigPath
    } else {
        @{}
    }

    # ── Layer 2: environment variables ────────────────────────────────────────
    $envCfg = @{}
    $envMap = [ordered]@{
        'UIPS_FEEDPATH'        = 'FeedPath'
        'UIPS_TOOLBASE'        = 'ToolBase'
        'UIPS_TARGETS'         = 'Targets'
        'UIPS_CLIVERSION_NET6' = 'CliVersionNet6'
        'UIPS_CLIVERSION_NET8' = 'CliVersionNet8'
        'UIPS_WORKTREE_BASE'   = 'WorktreeBase'
        'UIPS_USE_WORKTREE'    = 'UseWorktree'
        'UIPS_NO_BUMP'         = 'NoBump'
    }

    foreach ($envKey in $envMap.Keys) {
        $val = [Environment]::GetEnvironmentVariable($envKey)
        if (-not [string]::IsNullOrWhiteSpace($val)) {
            $paramKey = $envMap[$envKey]
            switch ($paramKey) {
                'Targets' {
                    $envCfg[$paramKey] = [string[]]($val -split ',\s*' | Where-Object { $_ -ne '' })
                }
                { $_ -in @('UseWorktree', 'NoBump') } {
                    $envCfg[$paramKey] = $true
                }
                default {
                    $envCfg[$paramKey] = $val
                }
            }
            Write-Verbose "[Config] Env var $envKey → $paramKey = $val"
        }
    }

    # ── Layer 3: project-level config (-ConfigFile) ───────────────────────────
    $projCfg = if (-not [string]::IsNullOrWhiteSpace($ConfigFile)) {
        Write-Verbose "[Config] Loading project config: $ConfigFile"
        Read-CpmfUipsPackConfig -Path $ConfigFile
    } else {
        @{}
    }

    # Merge: userCfg < envCfg < projCfg (later sources overwrite earlier)
    $merged = @{}
    foreach ($src in @($userCfg, $envCfg, $projCfg)) {
        foreach ($k in $src.Keys) { $merged[$k] = $src[$k] }
    }

    return $merged
}
