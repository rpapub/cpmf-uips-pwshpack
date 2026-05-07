function Get-CpmfUipsPackEffectiveConfig {
<#
.SYNOPSIS
    Merges the config sources into a single effective hashtable.
    Priority (lowest to highest): user config → repo config → env vars → project config.
    Explicit command-line parameters are NOT applied here — that is done by
    the caller (Invoke-CpmfUipsPack) using PSBoundParameters.

.DESCRIPTION
    Layer 1 — User config (XDG-inspired):
        %LOCALAPPDATA%\cpmf\CpmfUipsPack\config.psd1
        Loaded silently if present; missing file is not an error.

    Layer 2 — Repo config (opinionated defaults):
        cpmf-uips.psd1 next to the module repo root.
        Loaded silently if present; missing file is not an error.

    Layer 3 — Environment variables:
        CPMF_UIPS_UIPCLI_NET6_PATH → UipcliPathNet6
        CPMF_UIPS_UIPCLI_NET8_PATH → UipcliPathNet8
        CPMF_UIPS_TOOLBASE_PATH    → ToolBasePath
        CPMF_UIPS_OUTPUT_PATH      → OutputPath
        CPMF_UIPS_OUTPUT_DIR       → OutputPath (compatibility)
        UIPS_FEEDPATH         → FeedPath
        UIPS_TOOLBASE         → ToolBase
        UIPS_TARGETS          → Targets  (comma-separated: 'net6,net8')
        UIPS_CLIVERSION_NET6  → CliVersionNet6
        UIPS_CLIVERSION_NET8  → CliVersionNet8
        UIPS_WORKTREE_BASE    → WorktreeBase
        UIPS_USE_WORKTREE     → UseWorktree  (any non-empty value = $true)
        UIPS_NO_BUMP          → NoBump        (any non-empty value = $true)

    Layer 4 — Project config (-ConfigFile):
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

    # ── Layer 2: repo-level opinionated defaults ──────────────────────────────
    $repoCfg = @{}
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $repoConfigPath = Join-Path $repoRoot 'cpmf-uips.psd1'
    if (Test-Path -LiteralPath $repoConfigPath) {
        Write-Verbose "[Config] Loading repo config: $repoConfigPath"
        $repoCfg = Read-CpmfUipsPackConfig -Path $repoConfigPath
    }

    function Resolve-ConfigValue {
        param([object]$Value)

        if ($Value -is [string] -and $Value -match '^\$env:([^\\]+)(.*)$') {
            $envName = $Matches[1]
            $suffix = $Matches[2]
            $envValue = [Environment]::GetEnvironmentVariable($envName)
            if ([string]::IsNullOrWhiteSpace($envValue)) {
                throw "Environment variable $envName is not set for config value '$Value'."
            }

            return Join-Path $envValue $suffix.TrimStart('\')
        }

        return $Value
    }

    # Expand repo-config values before merging so path defaults can use $env:...
    foreach ($key in @($repoCfg.Keys)) {
        $repoCfg[$key] = Resolve-ConfigValue $repoCfg[$key]
    }

    # ── Layer 3: environment variables ────────────────────────────────────────
    $envCfg = @{}
    $envMap = [ordered]@{
        'CPMF_UIPS_UIPCLI_NET6_PATH' = 'UipcliPathNet6'
        'CPMF_UIPS_UIPCLI_NET8_PATH' = 'UipcliPathNet8'
        'CPMF_UIPS_TOOLBASE_PATH'    = 'ToolBasePath'
        'CPMF_UIPS_OUTPUT_DIR'       = 'OutputPath'
        'CPMF_UIPS_OUTPUT_PATH'      = 'OutputPath'
        'UIPS_FEEDPATH'              = 'FeedPath'
        'UIPS_TOOLBASE'              = 'ToolBasePath'
        'UIPS_TARGETS'               = 'Targets'
        'UIPS_CLIVERSION_NET6'       = 'CliVersionNet6'
        'UIPS_CLIVERSION_NET8'       = 'CliVersionNet8'
        'UIPS_WORKTREE_BASE'         = 'WorktreeBase'
        'UIPS_USE_WORKTREE'          = 'UseWorktree'
        'UIPS_NO_BUMP'               = 'NoBump'
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

    # ── Layer 4: project-level config (-ConfigFile) ───────────────────────────
    $projCfg = if (-not [string]::IsNullOrWhiteSpace($ConfigFile)) {
        Write-Verbose "[Config] Loading project config: $ConfigFile"
        Read-CpmfUipsPackConfig -Path $ConfigFile
    } else {
        @{}
    }

    # Merge: userCfg < repoCfg < envCfg < projCfg (later sources overwrite earlier)
    $merged = @{}
    foreach ($src in @($userCfg, $repoCfg, $envCfg, $projCfg)) {
        foreach ($k in $src.Keys) { $merged[$k] = $src[$k] }
    }

    return $merged
}
