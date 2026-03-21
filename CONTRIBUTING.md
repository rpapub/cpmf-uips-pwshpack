# Contributing to CpmfUipsPack

## Prerequisites

- PowerShell 7+
- Git
- Pester 5: `Install-Module Pester -Scope CurrentUser -Force`
- PSScriptAnalyzer: `Install-Module PSScriptAnalyzer -Scope CurrentUser -Force`

## Setup after cloning

```powershell
# Activate the pre-push hook (once per clone)
pwsh -File scripts/Install-GitHooks.ps1
```

This sets `core.hooksPath = ./hooks` in your local git config so that
`hooks/pre-push` runs automatically before every `git push`.

## Running checks locally

```powershell
# All Pester tests
Invoke-Pester ./CpmfUipsPack/tests/ -Output Normal

# Single test file
Invoke-Pester ./CpmfUipsPack/tests/Invoke-CpmfUipsPack.Tests.ps1 -Output Detailed

# PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path ./CpmfUipsPack -Recurse -Settings ./CpmfUipsPack/PSScriptAnalyzerSettings.psd1

# Validate manifest
Test-ModuleManifest ./CpmfUipsPack/CpmfUipsPack.psd1

# Full pre-push gate (same as the hook)
pwsh -File scripts/Invoke-PrePushChecks.ps1

# Install locally and run full test suite including live pack
pwsh -File scripts/Test-LocalInstall.ps1

# Include a live pack against the repo fixture
pwsh -File scripts/Test-LocalInstall.ps1 -PackFixture
```

## Branch workflow

- `development` — active development; PRs target this branch
- `main` — protected; only merged via PR after CI passes
- Branch protection requires: CI green, no direct pushes

## Pre-push hook

`hooks/pre-push` is a bash shim (tracked in the repo) that calls
`scripts/Invoke-PrePushChecks.ps1`. It runs PSScriptAnalyzer and Pester and
blocks the push if either fails.

The hook only activates after running `scripts/Install-GitHooks.ps1` once.
Without that step git uses `.git/hooks/` (empty on a fresh clone).

## Releasing

1. Bump `ModuleVersion` in `CpmfUipsPack/CpmfUipsPack.psd1`
2. Add a `## [x.y.z]` entry in `CHANGELOG.md`
3. Commit, push `development`, open PR → `main`
4. After merge: `git tag vx.y.z origin/main && git push origin vx.y.z`
5. The `publish.yml` workflow publishes to PSGallery automatically on a
   non-prerelease semver tag (`v[0-9]+.[0-9]+.[0-9]+`)
