function Test-CpmfUipsPackPrerequisites {
<#
.SYNOPSIS
    Validates that required executables and conditions are present before
    Invoke-CpmfUipsPack starts work. Throws a descriptive error on the first
    unmet prerequisite.

.PARAMETER RequireGit
    Check that git is on PATH and is executable. Required for -UseWorktree.

.PARAMETER RequireDotnetCli
    Check that a dotnet executable is available (either on system PATH or in the
    module-managed dotnet8 directory). Called when -Targets includes 'net8'.
    Accepts -ToolBase to locate the module-managed dotnet8 install.
#>
    [CmdletBinding()]
    param(
        [switch]$RequireGit,
        [switch]$RequireDotnetCli,
        [string]$ToolBase = (Join-Path $env:LOCALAPPDATA 'cpmf\tools')
    )

    # PowerShell 7+ is enforced by #Requires in the psm1, but provide a clear
    # message in case someone loads the function directly.
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "CpmfUipsPack requires PowerShell 7 or later. Current version: $($PSVersionTable.PSVersion)"
    }

    if ($RequireGit) {
        $git = Get-Command git -ErrorAction SilentlyContinue
        if (-not $git) {
            throw "git executable not found on PATH. git is required for -UseWorktree / -WorktreeSibling."
        }

        # Sanity-check that git is actually runnable
        $null = git --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "git was found at '$($git.Source)' but 'git --version' failed (exit $LASTEXITCODE)."
        }
    }

    if ($RequireDotnetCli) {
        # Accept either the module-managed dotnet8 install or a system dotnet on PATH
        $managedDotnet = Join-Path $ToolBase 'dotnet8\dotnet.exe'
        $hasDotnet     = (Test-Path $managedDotnet) -or ($null -ne (Get-Command dotnet -ErrorAction SilentlyContinue))
        if (-not $hasDotnet) {
            throw "dotnet CLI not found. Install-CpmfUipsPackCommandLineTool will install .NET 8 SDK automatically for -Targets net8."
        }
    }
}
