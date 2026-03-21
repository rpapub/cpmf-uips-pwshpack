function Invoke-CpmfUipsPack {
<#
.SYNOPSIS
    Bumps projectVersion, packs a UiPath project with uipcli, and stages the
    .nupkg to a local NuGet feed.

.DESCRIPTION
    Execution order:
      1. Install-CpmfUipsPackCommandLineTool  (skipped with -SkipInstall; repeated per target)
      2. Update-CpmfUipsPackProjectVersion  (skipped with -NoBump; runs once before all targets)
      3. uipcli package pack  (once per entry in -Targets)
      4. Copy .nupkg to -FeedPath  (once per target)
      5. If -MultiTfm and both net6+net8 targets: merge lib/ TFMs into one nupkg

    With -UseWorktree, steps 2-5 run inside a temporary git worktree created at
    HEAD. The working directory is never modified. The worktree is always removed
    on exit, even on failure.

    If the pack step fails after the version has been bumped (non-worktree mode),
    the original version is restored in project.json.

    Returns the full path(s) of staged .nupkg files as [string[]].

.PARAMETER ProjectJson
    Path to the UiPath project.json.

    Default: ..\project.json relative to the module root. Always pass this
    parameter explicitly when using the module from any location other than
    a Scripts\ subfolder of the UiPath project:

        Invoke-CpmfUipsPack -ProjectJson 'C:\repos\MyProject\project.json'

.PARAMETER FeedPath
    Destination directory for the staged .nupkg. Defaults to C:\Users\Public\nugetfeed.

.PARAMETER UipcliArgs
    Additional arguments passed verbatim to uipcli, e.g.
    -UipcliArgs '--traceLevel','Verbose','--outputType','Tests'

.PARAMETER NoBump
    Skip the version bump. Useful when repacking after a rollback.

.PARAMETER SkipInstall
    Skip Install-CpmfUipsPackCommandLineTool. Use when .NET and uipcli are already installed.

.PARAMETER UseWorktree
    Pack from a clean git worktree instead of the working directory. Requires
    the project to be inside a git repository.

.PARAMETER WorktreeBase
    Parent directory for the temporary worktree. Defaults to the system temp
    directory. Ignored unless -UseWorktree is set.

.PARAMETER WorktreeSibling
    Place the worktree as a sibling of the git repo root rather than in temp.
    Implies -UseWorktree.

.PARAMETER CliVersionNet6
    UiPath CLI version for the net6 target (23.x classic). Default: 23.10.2.6.

.PARAMETER CliVersionNet8
    UiPath CLI version for the net8 target (25.x dotnet tool). Default: 25.10.11.

.PARAMETER Targets
    Which CLI versions to build with. Valid values: 'net6', 'net8'.
    Defaults to @('net6'). Use @('net6','net8') to build for both.

.PARAMETER MultiTfm
    For Library projects: after building with both net6 and net8 targets, merge
    the lib/ TFM folders into a single nupkg. Requires -Targets @('net6','net8').
    Ignored for Process/Tests projects (a warning is emitted).

.PARAMETER CliVersion
    Deprecated. Use -CliVersionNet6 or -CliVersionNet8 instead.
    Versions matching '^23\.' map to -CliVersionNet6; others map to -CliVersionNet8.

.PARAMETER ToolBase
    Tool root directory. Forwarded to Install-CpmfUipsPackCommandLineTool. Defaults to
    %LOCALAPPDATA%\cpmf\tools.

.PARAMETER ConfigFile
    Path to a .psd1 config file that supplies default values for any parameter
    not explicitly passed on the command line. Explicit parameters always win.

    Supported keys: FeedPath, UipcliArgs, NoBump, SkipInstall, UseWorktree,
    WorktreeBase, WorktreeSibling, CliVersionNet6, CliVersionNet8, Targets,
    MultiTfm, ToolBase.

.OUTPUTS
    [string[]] Full path(s) of the staged .nupkg file(s).

.NOTES
    Set $env:UIPATH_DISABLE_TELEMETRY to any non-empty value (e.g. '1' or 'true')
    to suppress uipcli telemetry data transmission. The telemetry banner will still
    be printed — that is expected uipcli 23.x behaviour, not a bug.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string[]])]
    param(
        [string]  $ProjectJson     = (Join-Path $PSScriptRoot '..\project.json'),
        [string]  $FeedPath        = 'C:\Users\Public\nugetfeed',
        [string[]]$UipcliArgs      = @(),
        [switch]  $NoBump,
        [switch]  $SkipInstall,
        [switch]  $UseWorktree,
        [string]  $WorktreeBase    = [System.IO.Path]::GetTempPath(),
        [switch]  $WorktreeSibling,
        [string]  $CliVersionNet6  = '23.10.2.6',
        [string]  $CliVersionNet8  = '25.10.11',
        [string[]]$Targets         = @('net6'),
        [switch]  $MultiTfm,
        [string]  $CliVersion      = '',   # deprecated
        [string]  $ToolBase        = (Join-Path $env:LOCALAPPDATA 'cpmf\tools'),
        [string]  $ConfigFile      = ''
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Deprecated -CliVersion shim
    if ($PSBoundParameters.ContainsKey('CliVersion') -and $CliVersion -ne '') {
        Write-Warning "[CpmfUipsPack] -CliVersion is deprecated. Use -CliVersionNet6 or -CliVersionNet8."
        if ($CliVersion -match '^23\.') { $CliVersionNet6 = $CliVersion }
        else                            { $CliVersionNet8 = $CliVersion }
    }

    # Apply layered config defaults (user config < env vars < project config)
    # Explicit command-line parameters always win over all config sources.
    $cfg = Get-CpmfUipsPackEffectiveConfig -ConfigFile $ConfigFile

    foreach ($key in @('FeedPath', 'WorktreeBase', 'CliVersionNet6', 'CliVersionNet8', 'ToolBase')) {
        if (-not $PSBoundParameters.ContainsKey($key) -and $cfg.ContainsKey($key)) {
            Set-Variable -Name $key -Value $cfg[$key]
        }
    }
    foreach ($key in @('UipcliArgs', 'Targets')) {
        if (-not $PSBoundParameters.ContainsKey($key) -and $cfg.ContainsKey($key)) {
            Set-Variable -Name $key -Value ([string[]]$cfg[$key])
        }
    }
    foreach ($key in @('NoBump', 'SkipInstall', 'UseWorktree', 'WorktreeSibling', 'MultiTfm')) {
        if (-not $PSBoundParameters.ContainsKey($key) -and $cfg.ContainsKey($key) -and $cfg[$key]) {
            Set-Variable -Name $key -Value ([switch]$true)
        }
    }
    # Deprecated CliVersion in config
    if (-not $PSBoundParameters.ContainsKey('CliVersionNet6') -and
        -not $PSBoundParameters.ContainsKey('CliVersionNet8') -and
        $cfg.ContainsKey('CliVersion') -and $cfg['CliVersion'] -ne '') {
        Write-Warning "[CpmfUipsPack] Config key 'CliVersion' is deprecated. Use 'CliVersionNet6' or 'CliVersionNet8'."
        $v = $cfg['CliVersion']
        if ($v -match '^23\.') { $CliVersionNet6 = $v } else { $CliVersionNet8 = $v }
    }

    # Validate -Targets
    $validTargets = @('net6', 'net8')
    foreach ($t in $Targets) {
        if ($t -notin $validTargets) {
            throw "-Targets contains invalid value '$t'. Valid values: net6, net8"
        }
    }

    $resolvedUseWorktree = $UseWorktree -or $WorktreeSibling

    Test-CpmfUipsPackPrerequisites `
        -RequireGit:$resolvedUseWorktree `
        -RequireDotnetCli:($Targets -contains 'net8') `
        -ToolBase $ToolBase

    $ProjectJson = (Resolve-Path $ProjectJson).Path
    $ProjectRoot = Split-Path $ProjectJson -Parent

    # Pre-install all requested CLI versions before acquiring the lock
    if (-not $SkipInstall) {
        foreach ($target in $Targets) {
            $cliVer = if ($target -eq 'net6') { $CliVersionNet6 } else { $CliVersionNet8 }
            Install-CpmfUipsPackCommandLineTool -CliVersion $cliVer -ToolBase $ToolBase
        }
    }

    $lockFile = Join-Path $ProjectRoot '.uipath-pack.lock'

    Invoke-WithFileLock -LockFile $lockFile -ScriptBlock {

    if ($resolvedUseWorktree) {
        $repoRoot = git -C $ProjectRoot rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
            throw "Cannot use -UseWorktree: $ProjectRoot is not inside a git repository"
        }
        $repoRoot = $repoRoot.Trim() -replace '/', '\'

        if ($WorktreeSibling) {
            $WorktreeBase = Split-Path $repoRoot -Parent
        }

        $relativeProjectJson = $ProjectJson.Substring($repoRoot.Length).TrimStart('\', '/')

        $worktreePath = Get-GitWorktreePath `
            -ProjectJson  $ProjectJson `
            -RepoRoot     $repoRoot `
            -WorktreeBase $WorktreeBase

        Invoke-GitWorktree -RepoRoot $repoRoot -WorktreePath $worktreePath -ScriptBlock {
            param($wt)
            $wtProjectJson = Join-Path $wt $relativeProjectJson
            Invoke-MultiTargetPack `
                -ProjectJson     $wtProjectJson `
                -FeedPath        $FeedPath `
                -UipcliArgs      $UipcliArgs `
                -NoBump:$NoBump `
                -Targets         $Targets `
                -CliVersionNet6  $CliVersionNet6 `
                -CliVersionNet8  $CliVersionNet8 `
                -MultiTfm:$MultiTfm `
                -ToolBase        $ToolBase
        }
    } else {
        Write-Output (Invoke-MultiTargetPack `
            -ProjectJson     $ProjectJson `
            -FeedPath        $FeedPath `
            -UipcliArgs      $UipcliArgs `
            -NoBump:$NoBump `
            -Targets         $Targets `
            -CliVersionNet6  $CliVersionNet6 `
            -CliVersionNet8  $CliVersionNet8 `
            -MultiTfm:$MultiTfm `
            -ToolBase        $ToolBase)
    }

    } # end Invoke-WithFileLock
}

# ---------------------------------------------------------------------------
# Internal helper — orchestrates version bump + one-or-more PackAndStage calls
# + optional MultiTfm merge.
# ---------------------------------------------------------------------------
function Invoke-MultiTargetPack {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string[]])]
    param(
        [string]   $ProjectJson,
        [string]   $FeedPath,
        [string[]] $UipcliArgs,
        [switch]   $NoBump,
        [string[]] $Targets,
        [string]   $CliVersionNet6,
        [string]   $CliVersionNet8,
        [switch]   $MultiTfm,
        [string]   $ToolBase
    )

    $results      = [System.Collections.Generic.List[string]]::new()
    $isFirstTarget = $true

    foreach ($target in $Targets) {
        $cliVer    = if ($target -eq 'net6') { $CliVersionNet6 } else { $CliVersionNet8 }
        $p         = Get-CpmfUipsToolPaths -CliVersion $cliVer -ToolBase $ToolBase
        # Use a target tag in the filename only when building multiple targets
        $targetTag = if ($Targets.Count -gt 1) { $target } else { '' }

        # Version bump runs inside the first Invoke-PackAndStage only
        $thisBump  = if ($isFirstTarget) { $NoBump } else { [switch]$true }

        $staged = Invoke-PackAndStage `
            -ProjectJson $ProjectJson `
            -FeedPath    $FeedPath `
            -UipcliArgs  $UipcliArgs `
            -NoBump:$thisBump `
            -UipcliExe   $p.UipcliExe `
            -TargetTag   $targetTag

        if ($staged) { $results.Add($staged) }
        $isFirstTarget = $false
    }

    # Multi-TFM merge: combine net8 + net6 builds into one nupkg
    if ($MultiTfm -and $Targets.Count -eq 2 -and
        $Targets -contains 'net6' -and $Targets -contains 'net8') {

        $net8Path = $results | Where-Object { $_ -like '*.net8.nupkg' } | Select-Object -First 1
        $net6Path = $results | Where-Object { $_ -like '*.net6.nupkg' } | Select-Object -First 1

        if ($net8Path -and $net6Path) {
            # Output name: strip .net8 infix → <name>.<version>.nupkg
            $mergedName = [System.IO.Path]::GetFileName($net8Path) -replace '\.net8\.nupkg$', '.nupkg'
            $mergedPath = Join-Path $FeedPath $mergedName

            $merged = Invoke-MultiTfmMerge `
                -Net8Nupkg  $net8Path `
                -Net6Nupkg  $net6Path `
                -OutputPath $mergedPath

            # Remove the two per-target nupkgs; return merged path only
            Remove-Item $net8Path, $net6Path -Force -ErrorAction SilentlyContinue
            $results.Clear()
            if ($merged) { $results.Add($merged) }
        } else {
            Write-Warning "[Publish] -MultiTfm specified but could not locate both net6 and net8 nupkgs for merge."
        }
    } elseif ($MultiTfm) {
        Write-Warning "[Publish] -MultiTfm requires -Targets @('net6','net8') — ignored."
    }

    Write-Output ($results.ToArray())
}

# ---------------------------------------------------------------------------
# Internal helper — version bump + pack + stage, with rollback on failure.
# Extracted so both worktree and non-worktree paths share identical logic.
# ---------------------------------------------------------------------------
function Invoke-PackAndStage {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [string]  $ProjectJson,
        [string]  $FeedPath,
        [string[]]$UipcliArgs,
        [switch]  $NoBump,
        [string]  $UipcliExe,
        [string]  $TargetTag = ''
    )

    $ProjectRoot = Split-Path $ProjectJson -Parent

    # Version bump (capture current for rollback)
    $versionBumped   = $false
    $previousVersion = Update-CpmfUipsPackProjectVersion -ProjectJson $ProjectJson -NoBump

    if (-not $NoBump) {
        $newVersion    = Update-CpmfUipsPackProjectVersion -ProjectJson $ProjectJson
        Write-Verbose "[Publish] Version: $previousVersion → $newVersion"
        $versionBumped = $true
    } else {
        Write-Verbose "[Publish] Version bump skipped (-NoBump). Current: $previousVersion"
    }

    try {
        $OutputDir = Join-Path $ProjectRoot '.pack-output'
        $null = New-Item -ItemType Directory -Path $OutputDir -Force

        if ($PSCmdlet.ShouldProcess($ProjectJson, 'Pack with uipcli and stage to feed')) {
            $label = if ($TargetTag) { " [$TargetTag]" } else { '' }
            Write-Verbose "[Publish] Packing with uipcli$label"
            $packArgs = @('package', 'pack', $ProjectJson, '-o', $OutputDir)
            if ($env:UIPATH_DISABLE_TELEMETRY) { $packArgs += '--disableTelemetry' }
            if ($UipcliArgs.Count -gt 0) { $packArgs += $UipcliArgs }
            $exitCode = Invoke-UipcliPack -UipcliExe $UipcliExe -PackArgs $packArgs
            if ($exitCode -ne 0) { throw "uipcli pack failed (exit $exitCode)" }

            $nupkg = Get-ChildItem -Path $OutputDir -Filter '*.nupkg' |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            if (-not $nupkg) { throw "No .nupkg found in $OutputDir after pack" }

            $null = New-Item -ItemType Directory -Path $FeedPath -Force
            $destName = if ($TargetTag) {
                $nupkg.Name -replace '\.nupkg$', ".$TargetTag.nupkg"
            } else {
                $nupkg.Name
            }
            $dest = Join-Path $FeedPath $destName
            Copy-Item -Path $nupkg.FullName -Destination $dest -Force
            Write-Verbose "[Publish] Copied: $destName → $FeedPath"

            # Prune .pack-output\ — keep the 3 most recent .nupkg files
            Get-ChildItem -Path $OutputDir -Filter '*.nupkg' |
                Sort-Object LastWriteTime -Descending |
                Select-Object -Skip 3 |
                Remove-Item -Force
            Write-Verbose "[Publish] Done"

            Write-Output $dest
        }
    } catch {
        if ($versionBumped) {
            Write-Warning "[Publish] Pack failed — restoring version to $previousVersion"
            $raw      = Get-Content $ProjectJson -Raw
            $restored = $raw -replace '("projectVersion"\s*:\s*")[^"]*(")', "`${1}$previousVersion`${2}"
            [System.IO.File]::WriteAllText($ProjectJson, $restored, (New-Object System.Text.UTF8Encoding $false))
        }
        throw
    }
}
