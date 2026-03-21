# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A PowerShell 7 module (`CpmfUipsPack`) that automates packing a UiPath project into a `.nupkg`
and staging it to a local NuGet feed. It self-installs its own dependencies (no admin rights required):

- .NET 6.0.36 base + WindowsDesktop runtimes → `%LOCALAPPDATA%\cpmf\tools\dotnet\`
- UiPath CLI (uipcli) 23.10.2.6 → `%LOCALAPPDATA%\cpmf\tools\uipcli-23.10.2.6\`

The repo also contains the original monolithic `Invoke-UiPathPack.ps1` gist at the root — preserved
for reference. All active development is in `CpmfUipsPack/`.

## Module structure

```
CpmfUipsPack/
  CpmfUipsPack.psd1              # PS Gallery manifest
  CpmfUipsPack.psm1              # Loader: dot-sources Private/ then Public/
  PSScriptAnalyzerSettings.psd1
  Private/
    Add-ToUserPath.ps1
    Get-GitWorktreePath.ps1    # Derives worktree folder name from projectName+branch+sha
    Get-CpmfUipsToolPaths.ps1  # Returns hashtable of all computed tool paths
    Invoke-GitWorktree.ps1     # Creates/runs/removes git worktree around a ScriptBlock
    Invoke-UipcliPack.ps1      # Thin wrapper so Pester can mock the & call
    Invoke-WithFileLock.ps1    # File-based mutex with 10s retry
    Read-CpmfUipsPackConfig.ps1  # Reads .psd1 config file via Import-PowerShellDataFile
    Remove-FromUserPath.ps1
    Test-CpmfUipsPackPrerequisites.ps1
  Public/
    Install-CpmfUipsPackCommandLineTool.ps1
    Install-CpmfUipsPackGitHook.ps1
    Invoke-CpmfUipsPack.ps1      # Also contains private Invoke-PackAndStage
    Uninstall-CpmfUipsPackCommandLineTool.ps1
    Update-CpmfUipsPackProjectVersion.ps1
  tests/
    Install-CpmfUipsPackCommandLineTool.Tests.ps1
    Invoke-CpmfUipsPack.Tests.ps1
    Uninstall-CpmfUipsPackCommandLineTool.Tests.ps1
    Update-CpmfUipsPackProjectVersion.Tests.ps1
    helpers/PathHelpers.Tests.ps1
```

## Commands

```powershell
# Run all tests
Invoke-Pester ./CpmfUipsPack/tests/ -Output Normal

# Run a single test file
Invoke-Pester ./CpmfUipsPack/tests/Invoke-CpmfUipsPack.Tests.ps1 -Output Detailed

# Lint (suppress intentional warnings via settings file)
Invoke-ScriptAnalyzer -Path ./CpmfUipsPack -Recurse -Settings ./CpmfUipsPack/PSScriptAnalyzerSettings.psd1

# Validate manifest
Test-ModuleManifest ./CpmfUipsPack/CpmfUipsPack.psd1
```

## Usage

```powershell
Import-Module ./CpmfUipsPack/CpmfUipsPack.psd1 -Force

# Default: bumps version, packs, copies to feed
Invoke-CpmfUipsPack -ProjectJson 'C:\repos\MyProject\project.json'

# Pack from a clean git worktree (avoids Studio lock, no working-dir changes)
Invoke-CpmfUipsPack -ProjectJson '...' -UseWorktree

# Repack same version (no bump)
Invoke-CpmfUipsPack -ProjectJson '...' -NoBump

# Use a .psd1 config file for per-project defaults
Invoke-CpmfUipsPack -ProjectJson '...' -ConfigFile '.\uipath-pack.psd1'

# Dry run
Invoke-CpmfUipsPack -ProjectJson '...' -WhatIf

# Install git pre-push hook
Install-CpmfUipsPackGitHook -ProjectJson 'C:\repos\MyProject\project.json'

# Uninstall tools
Uninstall-CpmfUipsPackCommandLineTool
```

Config file format (`uipath-pack.psd1`):
```powershell
@{
    FeedPath    = 'D:\nugetfeed'
    UseWorktree = $true
    CliVersion  = '23.10.2.6'
}
```
Supported keys: `FeedPath`, `UipcliArgs`, `NoBump`, `SkipInstall`, `UseWorktree`,
`WorktreeBase`, `WorktreeSibling`, `CliVersion`, `ToolBase`. Explicit parameters always
override config values.

## Execution flow

`Invoke-CpmfUipsPack` orchestrates:

1. `Test-CpmfUipsPackPrerequisites` — PS 7+, git (if worktree mode)
2. `Install-CpmfUipsPackCommandLineTool` — downloads uipcli and .NET runtime into user profile; idempotent; skipped with `-SkipInstall`
3. `Invoke-WithFileLock` — file-based mutex; warns + retries once on contention
4. Inside lock: `Invoke-PackAndStage` (version bump → pack → stage → prune)
   - With `-UseWorktree`: wraps step 4 in `Invoke-GitWorktree` so everything runs
     against a temporary `git worktree add HEAD` copy; working directory untouched
   - On pack failure: version bump is rolled back in `project.json`
   - On success: `.pack-output\` is pruned to the 3 most recent `.nupkg` files

## Version bump logic

| Current version format | Bump behaviour |
|---|---|
| `1.2.3-alpha.4` (prerelease) | `alpha.4 → alpha.5` |
| `1.2.3+build.4` (build metadata) | `build.4 → build.5` |
| `1.2.3` (plain release) | minor increment → `1.3.0` |

## Key paths (defaults)

| Parameter / Variable | Default value |
|---|---|
| `$ToolBase` | `%LOCALAPPDATA%\cpmf\tools\` |
| `$FeedPath` | `C:\Users\Public\nugetfeed\` |
| `$UipcliExe` | `%LOCALAPPDATA%\cpmf\tools\uipcli-23.10.2.6\extracted\tools\uipcli.exe` |
| Pack output | `<ProjectRoot>\.pack-output\` |
| Lock file | `<ProjectRoot>\.uipath-pack.lock` |

## Known issues (see TODO.md)

- uipcli 23.x is pinned deliberately (requires .NET 6; target Orchestrator is .NET 6).
- Set `$env:UIPATH_DISABLE_TELEMETRY = '1'` to suppress data transmission; the telemetry
  banner still prints — that is expected uipcli 23.x behaviour.

## Test patterns

All tests use **Pester 5** with `InModuleScope CpmfUipsPack`. Key patterns:

- Pass `BeforeEach` variables into `InModuleScope` via `-Parameters @{ key = $script:var }` +
  `param($key)` — direct `$script:` access does not work inside `InModuleScope`.
- Mock `Invoke-UipcliPack` (not `&`) to control uipcli exit codes.
- Mock `Invoke-WithFileLock` as a pass-through: `param($LockFile, $ScriptBlock); & $ScriptBlock`.

## Future CLI wrapper

This module is designed to eventually be wrapped by an external CLI tool (not yet built). Architectural implications already in place:

- Public functions return machine-readable output (`[string[]]` paths, thrown exceptions for errors)
- All user-facing messages go through `Write-Host`/`Write-Verbose` (suppressible; not mixed into pipeline output)
- Config is fully layerable: env vars → user config → project config → explicit params — a wrapper can inject settings via env vars without touching the filesystem
- `SupportsShouldProcess` on all state-changing functions enables dry-run mode

When implementing the CLI wrapper, prefer driving via env vars (`UIPS_*`) or `-ConfigFile` rather than building PowerShell parameter plumbing in the wrapper.
