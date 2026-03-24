# CpmfUipsPack

A PowerShell 7 module that bumps the version, packs a UiPath Studio project with `uipcli`, and stages the resulting `.nupkg` to a local NuGet feed — with no admin rights and no manual tool installs.

> **Trademark notice:** UiPath and UiPath Studio are trademarks of UiPath Inc.
> This module is not affiliated with or endorsed by UiPath Inc.

---

## Requirements

- PowerShell 7.0 or later
- Windows (x64)
- Git — only when using `-UseWorktree`

Everything else (.NET runtimes, uipcli) is downloaded and installed automatically on first use.

---

## Installation

```powershell
Install-Module CpmfUipsPack -Scope CurrentUser
```

### Update

```powershell
# If originally installed via Install-Module:
Update-Module CpmfUipsPack

# If installed any other way (local copy, manual import, etc.):
Install-Module CpmfUipsPack -Scope CurrentUser -Force
Import-Module CpmfUipsPack -Force
```

---

## Quick start

```powershell
# Bump version, pack, copy .nupkg to C:\Users\Public\nugetfeed\
Invoke-CpmfUipsPack -ProjectJson 'C:\repos\MyProject\project.json'
```

On first run the module downloads and installs .NET 6.0.36 and uipcli 23.x into
`%LOCALAPPDATA%\cpmf\tools\`. Subsequent runs skip the install check and go straight
to packing.

---

## What it does

1. **Version bump** — reads `projectVersion` from `project.json`, increments it, writes it back
2. **Pack** — calls `uipcli package pack` to produce a `.nupkg`
3. **Stage** — copies the `.nupkg` to the feed directory, keeps the 3 most recent builds
4. **Rollback** — if the pack step fails, the version bump is automatically reversed

| Version format | Bump result |
|---|---|
| `1.2.3` | `1.3.0` |
| `1.2.3-alpha.4` | `1.2.3-alpha.5` |
| `1.2.3+build.4` | `1.2.3+build.5` |

---

## Common options

```powershell
# Pack without bumping the version (re-pack after a rollback)
Invoke-CpmfUipsPack -ProjectJson '...' -NoBump

# Pack from a clean git worktree — avoids Studio file locks
Invoke-CpmfUipsPack -ProjectJson '...' -UseWorktree

# Send the .nupkg to a different feed directory
Invoke-CpmfUipsPack -ProjectJson '...' -FeedPath 'D:\nugetfeed'

# Dry run — shows what would happen without making any changes
Invoke-CpmfUipsPack -ProjectJson '...' -WhatIf

# Build for both .NET 6 and .NET 8 Orchestrators
Invoke-CpmfUipsPack -ProjectJson '...' -Targets net6, net8
```

---

## uipcli versions

The module supports two uipcli families selected via `-Targets`:

| Target | uipcli | .NET | Orchestrator |
|---|---|---|---|
| `net6` (default) | 23.x | 6.0.36 | .NET 6 |
| `net8` | 25.x+ | 8.0 SDK | .NET 8 |

Both runtimes are self-installed into `%LOCALAPPDATA%\cpmf\tools\` on demand.

```powershell
# net8 only
Invoke-CpmfUipsPack -ProjectJson '...' -Targets net8

# Both — produces two .nupkg files, one per target
Invoke-CpmfUipsPack -ProjectJson '...' -Targets net6, net8

# Library projects: merge both TFMs into one .nupkg
Invoke-CpmfUipsPack -ProjectJson '...' -Targets net6, net8 -MultiTfm
```

---

## Configuration

Settings come from four sources, merged in priority order. A higher-priority source
always wins — you never need to remove a lower-priority setting to override it.

```
Priority (lowest → highest)
────────────────────────────────────────────────────────────────
 1. User config     %LOCALAPPDATA%\cpmf\CpmfUipsPack\config.psd1
 2. Env vars        UIPS_*
 3. Project config  -ConfigFile .\uipath-pack.psd1
 4. Parameters      -FeedPath, -Targets, ...   ← always win
────────────────────────────────────────────────────────────────
```

This means you can set your personal feed path once in the user config and never
think about it again, let a CI system inject a different feed via env var, let a
project override the target version in its own config file, and still be able to
do a one-off override on the command line — all without touching each other.

### Layer 1 — User config (your personal defaults)

Applies to every project on your machine. Set it once, forget it.

```powershell
# Scaffold the file (all keys are commented out by default)
Install-CpmfUipsPackConfig

# Edit it
notepad "$env:LOCALAPPDATA\cpmf\CpmfUipsPack\config.psd1"
```

```powershell
# Example: always send packages to your personal feed
@{
    FeedPath    = 'D:\nugetfeed'
    UseWorktree = $true
}
```

### Layer 2 — Environment variables (CI / wrapper injection)

Set these in your pipeline or shell profile to inject settings without touching
any file on disk. A wrapper tool driving this module should prefer env vars over
building PowerShell parameter plumbing.

| Variable | Parameter | Notes |
|---|---|---|
| `UIPS_FEEDPATH` | `-FeedPath` | |
| `UIPS_TOOLBASE` | `-ToolBase` | |
| `UIPS_TARGETS` | `-Targets` | comma-separated: `net6,net8` |
| `UIPS_CLIVERSION_NET6` | `-CliVersionNet6` | |
| `UIPS_CLIVERSION_NET8` | `-CliVersionNet8` | |
| `UIPS_WORKTREE_BASE` | `-WorktreeBase` | |
| `UIPS_USE_WORKTREE` | `-UseWorktree` | any non-empty value = `$true` |
| `UIPS_NO_BUMP` | `-NoBump` | any non-empty value = `$true` |

```powershell
# Example: CI pipeline overrides the feed path
$env:UIPS_FEEDPATH = '\\buildserver\nugetfeed'
Invoke-CpmfUipsPack -ProjectJson '...'
```

### Layer 3 — Project config (per-project defaults)

Lives alongside `project.json`. Check it into source control so every team member
and every CI run uses the same defaults for that project.

```powershell
# Scaffold a fully-commented template
Copy-Item `
    (Join-Path (Split-Path (Get-Module CpmfUipsPack -ListAvailable).Path) 'examples\uipath-pack.psd1') `
    .\uipath-pack.psd1

# Use it
Invoke-CpmfUipsPack -ProjectJson '...' -ConfigFile '.\uipath-pack.psd1'
```

```powershell
# Example: pin the CLI version and always use worktree mode
@{
    CliVersionNet6 = '23.10.2.6'
    UseWorktree    = $true
    FeedPath       = 'C:\Users\Public\nugetfeed'
}
```

### Layer 4 — Explicit parameters (one-off overrides)

Parameters passed directly on the command line always win, regardless of what any
config layer says.

```powershell
# Override the feed path for this one run only
Invoke-CpmfUipsPack -ProjectJson '...' -FeedPath 'D:\temp\testfeed'
```

---

## Git hook

Auto-pack on every `git push`:

```powershell
Install-CpmfUipsPackGitHook -ProjectJson 'C:\repos\MyProject\project.json'
```

---

## Uninstall

```powershell
# Remove uipcli and .NET runtimes
Uninstall-CpmfUipsPackCommandLineTool                        # net6 (23.10.2.6)
Uninstall-CpmfUipsPackCommandLineTool -CliVersion '25.10.11' # net8

# Remove user-level config
Uninstall-CpmfUipsPackConfig

# Remove the module
Uninstall-Module CpmfUipsPack
```

---

## Help wanted

The live install path (downloading .NET and uipcli from scratch) has not been verified
on a machine without any pre-installed .NET. If you test this on a clean machine, please
[open an issue](https://github.com/rpapub/cpmf-uips-pwshpack/issues/1) and report your findings.

---

## License

Apache 2.0 — © 2026 Christian Prior-Mamulyan
