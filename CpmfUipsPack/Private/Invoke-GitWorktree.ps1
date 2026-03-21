function Invoke-GitWorktree {
<#
.SYNOPSIS
    Creates a temporary git worktree at HEAD, invokes a script block inside it,
    then removes the worktree — even on failure.

.PARAMETER RepoRoot
    Root of the git repository.

.PARAMETER WorktreePath
    Full path where the worktree will be created.

.PARAMETER ScriptBlock
    Code to run inside the worktree. Receives the worktree path as the first argument.

.EXAMPLE
    Invoke-GitWorktree -RepoRoot C:\repos\MyProject -WorktreePath C:\Temp\wt-MyProject {
        param($wt)
        Write-Host "Packing from $wt"
    }
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$WorktreePath,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    Write-Verbose "[Worktree] Creating worktree at $WorktreePath"
    git -C $RepoRoot worktree add $WorktreePath HEAD
    if ($LASTEXITCODE -ne 0) { throw "git worktree add failed (exit $LASTEXITCODE)" }

    try {
        & $ScriptBlock $WorktreePath
    } finally {
        Write-Verbose "[Worktree] Removing worktree $WorktreePath"
        git -C $RepoRoot worktree remove --force $WorktreePath 2>$null
        git -C $RepoRoot worktree prune 2>$null
    }
}
