# CpmfUipsPack project-level configuration file
#
# Place this file alongside (or near) your project.json and pass it via:
#   Invoke-CpmfUipsPack -ProjectJson '.\project.json' -ConfigFile '.\uipath-pack.psd1'
#
# Explicit command-line parameters always override values set here.
# All keys are optional — omit any key to use the built-in default.

@{
    # ── Output ───────────────────────────────────────────────────────────────
    # Local NuGet feed directory where the staged .nupkg is copied.
    FeedPath = 'C:\Users\Public\nugetfeed'

    # ── CLI versions ─────────────────────────────────────────────────────────
    # Which uipcli versions to build with. Valid values: 'net6', 'net8'.
    # Default: @('net6')  — net6 targets uipcli 23.x (.NET 6 Orchestrators)
    #                       net8 targets uipcli 25.x+ (.NET 8 Orchestrators)
    Targets        = @('net6')

    # Pinned version for the net6 (classic nupkg) build path.
    CliVersionNet6 = '23.10.2.6'

    # Pinned version for the net8 (dotnet tool) build path.
    CliVersionNet8 = '25.10.11'

    # ── Library projects: multi-TFM merge ────────────────────────────────────
    # Set to $true to merge lib/ TFM folders from both net6 and net8 builds
    # into a single nupkg. Requires Targets = @('net6', 'net8').
    # Ignored (with a warning) for Process/Tests projects.
    MultiTfm = $false

    # ── Tools root ───────────────────────────────────────────────────────────
    # Root directory for self-installed .NET runtimes and uipcli binaries.
    #   net6: <ToolBase>\dotnet\        + <ToolBase>\uipcli-<ver>\extracted\
    #   net8: <ToolBase>\dotnet8\       + <ToolBase>\uipcli-<ver>\
    ToolBase = '%LOCALAPPDATA%\cpmf\tools'

    # ── Git worktree ─────────────────────────────────────────────────────────
    # Pack from a clean git worktree at HEAD instead of the live working
    # directory. Avoids Studio lock conflicts and working-dir noise.
    UseWorktree    = $false

    # Parent directory for the temporary worktree (default: system temp).
    # WorktreeBase = 'D:\worktrees'

    # Place the worktree as a sibling of the git repo root instead of temp.
    # Useful when temp is on a different volume.
    WorktreeSibling = $false

    # ── Pack behaviour ───────────────────────────────────────────────────────
    # Skip the projectVersion increment. Useful when repacking after a rollback.
    NoBump      = $false

    # Skip Install-CpmfUipsPackCommandLineTool. Use when runtimes and uipcli are already in place.
    SkipInstall = $false

    # Additional arguments forwarded verbatim to uipcli, e.g.:
    #   UipcliArgs = @('--traceLevel', 'Verbose', '--outputType', 'Tests')
    # UipcliArgs = @()
}
