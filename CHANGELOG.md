# Changelog

All notable changes to CpmfUipsPack are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.2.5] — 2026-05-05

### Changed

- **`Install-CpmfUipsPackCommandLineTool`** / **`Uninstall-CpmfUipsPackCommandLineTool`** — default
  `CliVersion` changed from `23.10.2.6` to `25.10.15`.

- **`Get-CpmfUipsToolPaths`** — version dispatch replaced: the `^23\.` regex is removed in favour of a
  numeric comparison against the boundary version `25.10.2-20251124-7` (the first release that ships
  `UiPath.CLI.Windows` as a dotnet global tool rather than a self-contained exe). All versions
  `>= 25.10.2` use `dotnet tool install --tool-path`; all earlier versions use the classic nupkg
  extraction path. The returned hashtable gains an `IsDotnetTool` boolean key.

### Fixed

- **Version dispatch** — `24.*` and `25.4.*` versions were incorrectly routed to the dotnet-tool path
  by the old `^23\.` regex. They now correctly resolve to the classic path.

---

## [0.2.4] — 2026-03-24

### Fixed

- **`Install-CpmfUipsPackCommandLineTool`** — initialize `$LASTEXITCODE = 0` before
  each `dotnet-install.ps1` invocation. PowerShell scripts do not set `$LASTEXITCODE`
  as native executables do; under `Set-StrictMode -Version Latest` reading an unset
  variable throws `PropertyNotFoundException`, aborting the install.

---

## [0.2.3] — 2026-03-24

### Fixed

- **Revert v0.2.2** — removed the auto-migration of `dotnet\` → `dotnet6\`
  introduced in v0.2.2. The migration silently renamed a user folder inside an
  install function without explicit consent. A legacy `dotnet\` folder is a
  development artifact; users can remove it manually.

---

## [0.2.2] — 2026-03-24 *(yanked — reverted in 0.2.3)*

---

## [0.2.1] — 2026-03-24

### Fixed

- **`Install-UipathcliTool`** — the GitHub release asset is a zip archive
  (`uipathcli-windows-amd64.zip`) containing `uipath.exe`, not a bare `.exe`.
  The installer now downloads the zip, extracts it, and cleans up the archive.
  `UipathcliExe` path updated accordingly (`uipath.exe`).

---

## [0.2.0] — 2026-03-24

### Added

- **CLI adapter pattern** — `Invoke-CpmfUipsPack` gains a `-Backend` parameter
  (`'uipcli'` default | `'uipathcli'`). The new private `Invoke-CliBackend`
  function translates pack/analyze operations into the correct argument format
  for each CLI implementation.
- **`Invoke-CpmfUipsAnalyze`** — new public function that runs the UiPath
  workflow analyzer via either backend and returns output as `[string[]]`.
- **`Install-UipathcliTool` / `Uninstall-UipathcliTool`** — self-installs the
  uipathcli Go binary (https://github.com/UiPath/uipathcli) into
  `%LOCALAPPDATA%\cpmf\tools\uipathcli\`. Idempotent, no admin rights required.
- **`Get-CpmfUipsToolPaths`** — now returns `UipathcliDir` and `UipathcliExe`
  in its hashtable regardless of `CliVersion`.

---

## [0.1.2] — 2026-03-23

### Changed

- **Managed .NET 6 tool folder renamed** from `dotnet\` to `dotnet6\`
  (`%LOCALAPPDATA%\cpmf\tools\dotnet6\`). The .NET 8 folder was already named
  `dotnet8\`; this makes the naming symmetric and unambiguous.

### Migration

Users with an existing `dotnet\` install have two options:

```powershell
# Option A — rename in place (no re-download)
Rename-Item "$env:LOCALAPPDATA\cpmf\tools\dotnet" dotnet6

# Option B — re-run the installer (re-downloads .NET 6.0.36)
Install-CpmfUipsPackCommandLineTool
```

---

## [0.1.1] — 2026-03-21

### Fixed

- **Silent uipcli output on failure** — `INITIALIZATION:`, `PREPROCESSING:`, `COMPILER:`,
  repeated `CS1701` assembly-version warnings, empty lines, and the telemetry notice are
  now demoted to `Write-Verbose` even on failure. Only actionable lines (compile errors,
  failure summaries, exceptions) reach `Write-Warning`.
- **File-lock on repeated packs** — `Invoke-PackAndStage` now writes to a per-invocation
  GUID temp folder instead of a fixed `.pack-output` directory, eliminating the Windows
  file-lock that prevented back-to-back invocations. Temp folder is cleaned up in a
  `finally` block.
- **Fixture `projectProfile` incompatibility** — removed the `projectProfile` field from
  the `MinimalProcess` test fixture; uipcli 23.x does not recognise the `"Development"` enum
  value and rejected the pack. Committed the normalised fields uipcli adds on first pack.

### Added

- **`-PackFixture` switch in `scripts/Test-LocalInstall.ps1`** — after the Pester run,
  optionally invokes `Invoke-CpmfUipsPack -NoBump` against the repo-local zero-dependency
  fixture at `CpmfUipsPack/tests/fixtures/MinimalProcess/project.json` and exits 1 on
  failure.

---

## [0.1.0] — 2026-03-21

Initial release.

### Added

**Core pack workflow**
- `Invoke-CpmfUipsPack` — bumps `projectVersion` in `project.json`, calls uipcli to
  produce a `.nupkg`, and stages it to a local NuGet feed. Keeps the 3 most recent
  builds in `.pack-output\`. Rolls back the version bump automatically if packing fails.

**Version bump logic**
- Plain versions (`1.2.3`) → minor increment → `1.3.0`
- Pre-release segments (`1.2.3-alpha.4`) → `1.2.3-alpha.5`
- Build metadata segments (`1.2.3+build.4`) → `1.2.3+build.5`
- `Update-CpmfUipsPackProjectVersion` exposed as a standalone public function for
  use in custom workflows.

**Dual uipcli support — self-installed into user profile, no admin rights**
- `net6` target: downloads .NET 6.0.36 (base + WindowsDesktop) and uipcli 23.x
  (nupkg extraction) into `%LOCALAPPDATA%\cpmf\tools\`
- `net8` target: downloads .NET 8 SDK and uipcli 25.x+ (dotnet tool install)
  into `%LOCALAPPDATA%\cpmf\tools\dotnet8\`
- `Install-CpmfUipsPackCommandLineTool` and `Uninstall-CpmfUipsPackCommandLineTool`
  exposed as standalone public functions

**Multi-target builds**
- `-Targets @('net6','net8')` builds both families in one invocation; version is
  bumped exactly once
- Staged filenames gain a `.net6` / `.net8` infix when both targets are active to
  avoid feed collisions

**Library project MultiTfm merge**
- `-MultiTfm` merges `lib/net6*` entries from the net6 build into the net8 nupkg,
  producing a single multi-targeted package; patches the nuspec dependency group

**Git worktree isolation**
- `-UseWorktree` packs from a temporary `git worktree add HEAD` copy; working
  directory and open Studio instances are never touched

**Concurrency guard**
- File-based mutex (`.uipath-pack.lock`) prevents two simultaneous pack operations
  on the same project; warns, waits 10 s, retries once before failing

**Four-layer configuration hierarchy**
- Layer 1 — user config: `%LOCALAPPDATA%\cpmf\CpmfUipsPack\config.psd1`
- Layer 2 — environment variables: `UIPS_FEEDPATH`, `UIPS_TARGETS`, `UIPS_NO_BUMP`, …
- Layer 3 — project config: `-ConfigFile .\uipath-pack.psd1`
- Layer 4 — explicit parameters (always win)
- `Install-CpmfUipsPackConfig` / `Uninstall-CpmfUipsPackConfig` scaffold and remove
  the user-level config file

**Git pre-push hook**
- `Install-CpmfUipsPackGitHook` installs a pre-push hook that runs
  `Invoke-CpmfUipsPack` automatically on every `git push`

**Diagnostics**
- `Get-CpmfUipsPackDiagnostics` generates a pseudonymized environment report
  (OS, PowerShell version, managed tool paths, UIPS_* env var presence) safe
  for pasting into a GitHub issue
- Report is returned as `[string[]]` via the pipeline — capturable by wrapper
  modules and scripts; use `$report = Get-CpmfUipsPackDiagnostics` to collect

**Stream discipline — wrapper-safe output**
- All progress and status messages use `Write-Verbose` (off by default; opt in
  with `-Verbose`). No `Write-Host` anywhere in live code.
- Pipeline output (`Write-Output`) is reserved for machine-readable results:
  staged `.nupkg` paths from `Invoke-CpmfUipsPack`; version strings from
  `Update-CpmfUipsPackProjectVersion`; the diagnostics report from
  `Get-CpmfUipsPackDiagnostics`.
- This makes the module safe to use as a `RequiredModules` dependency in a
  wrapper module (e.g. `CpmfUipsCLI`) without console pollution.

**CI/CD workflows**
- `.github/workflows/ci.yml` — Pester + PSScriptAnalyzer on every push and
  pull request to `development` and `main`
- `.github/workflows/publish.yml` — tag-triggered PSGallery publish; guards:
  manifest version must match tag; CHANGELOG entry for the version must exist

**Reference documentation**
- `docs/reference/*.md` — platyPS-generated per-function reference pages for
  all 8 public functions
- `CpmfUipsPack/en-US/CpmfUipsPack-help.xml` — MAML help file; enables
  `Get-Help Invoke-CpmfUipsPack -Full` from the installed module
- `docs/diagrams.md` — 12 Mermaid architecture diagrams (module overview,
  execution flow, config hierarchy, uipcli family decision, install flow,
  version bump, multi-target sequence, worktree sequence, file lock,
  MultiTfm merge, API surface, tool path layout)

**PSGallery discovery**
- Tag `cpmf-uips` added to manifest — use `Find-Module -Tag 'cpmf-uips'` to
  discover all modules in the Cpmf UiPath integration family

[0.1.0]: https://github.com/rpapub/cpmf-uips-pwshpack/releases/tag/v0.1.0
