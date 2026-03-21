function Read-CpmfUipsPackConfig {
<#
.SYNOPSIS
    Reads a CpmfUipsPack .psd1 config file and returns a hashtable of defaults.

.DESCRIPTION
    Loads a PowerShell data file (.psd1) and validates that its keys match
    the known Invoke-CpmfUipsPack parameter names. Unknown keys produce a warning.

    Returns an empty hashtable when -Path is empty or not provided.

.PARAMETER Path
    Full path to the .psd1 config file.
#>
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return @{} }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }

    $cfg = Import-PowerShellDataFile -LiteralPath $Path

    $knownKeys = @(
        'FeedPath', 'UipcliArgs', 'NoBump', 'SkipInstall',
        'UseWorktree', 'WorktreeBase', 'WorktreeSibling',
        'CliVersionNet6', 'CliVersionNet8', 'Targets', 'MultiTfm',
        'ToolBase',
        'CliVersion'   # deprecated — warns at runtime; use CliVersionNet6 or CliVersionNet8
    )

    foreach ($key in $cfg.Keys) {
        if ($key -notin $knownKeys) {
            Write-Warning "[Config] Unknown key '$key' in config file — ignored."
        }
    }

    return $cfg
}
