function Get-GitWorktreePath {
<#
.SYNOPSIS
    Derives a deterministic worktree directory path from project name, git branch,
    and short commit SHA. Does not create the directory.

.PARAMETER ProjectJson
    Path to the UiPath project.json — used to read the project name.

.PARAMETER RepoRoot
    Root of the git repository.

.PARAMETER WorktreeBase
    Parent directory under which the worktree folder will sit.
    Defaults to the system temp directory.

.OUTPUTS
    [string] Full path of the (not yet created) worktree directory.
#>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectJson,

        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [string]$WorktreeBase = [System.IO.Path]::GetTempPath()
    )

    # Read project name from project.json
    $raw = Get-Content $ProjectJson -Raw
    $projectName = if ($raw -match '"name"\s*:\s*"([^"]+)"') { $Matches[1] } else { 'uipath-project' }
    # Sanitise: replace characters invalid in directory names
    $projectName = $projectName -replace '[\\/:*?"<>|]', '_'

    $branch = git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
        throw "Failed to determine git branch in $RepoRoot"
    }
    $branch = $branch.Trim() -replace '[\\/:*?"<>|]', '_'

    $sha = git -C $RepoRoot rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sha)) {
        throw "Failed to determine git commit SHA in $RepoRoot"
    }
    $sha = $sha.Trim()

    $folderName = "uipath-worktree-$projectName-$branch-$sha"
    Write-Output (Join-Path $WorktreeBase $folderName)
}
