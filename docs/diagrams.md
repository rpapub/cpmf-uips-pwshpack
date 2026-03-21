# CpmfUipsPack — Architecture Diagrams

---

## 1. Module component overview

Who calls what. Public functions are the contract; private helpers are internal wiring.

```mermaid
graph TD
    subgraph Public
        A[Invoke-CpmfUipsPack]
        B[Install-CpmfUipsPackCommandLineTool]
        C[Uninstall-CpmfUipsPackCommandLineTool]
        D[Update-CpmfUipsPackProjectVersion]
        E[Install-CpmfUipsPackGitHook]
        F[Install-CpmfUipsPackConfig]
        G[Uninstall-CpmfUipsPackConfig]
        H[Get-CpmfUipsPackDiagnostics]
    end

    subgraph Private
        P1[Get-CpmfUipsPackEffectiveConfig]
        P2[Get-CpmfUipsToolPaths]
        P3[Test-CpmfUipsPackPrerequisites]
        P4[Read-CpmfUipsPackConfig]
        P5[Invoke-WithFileLock]
        P6[Invoke-PackAndStage]
        P7[Invoke-UipcliPack]
        P8[Invoke-GitWorktree]
        P9[Get-GitWorktreePath]
        P10[Invoke-MultiTfmMerge]
        P11[Add-ToUserPath]
        P12[Remove-FromUserPath]
    end

    A --> P1
    A --> P3
    A -->|unless -SkipInstall| B
    A --> P5
    A --> P6
    A --> P10
    B --> P2
    B --> P11
    C --> P2
    C --> P12
    P1 --> P4
    P6 --> D
    P6 --> P7
    P6 --> P8
    P8 --> P9
```

---

## 2. `Invoke-CpmfUipsPack` execution flow

The full orchestration from invocation to staged `.nupkg`.

```mermaid
flowchart TD
    Start([Invoke-CpmfUipsPack]) --> MergeConfig["Merge config layers<br/>Get-CpmfUipsPackEffectiveConfig"]
    MergeConfig --> Prereqs["Test-CpmfUipsPackPrerequisites<br/>PS7+ · git if worktree · dotnet if net8"]
    Prereqs --> SkipInstall{-SkipInstall?}
    SkipInstall -- no --> InstallLoop["Install-CpmfUipsPackCommandLineTool<br/>per target"]
    SkipInstall -- yes --> Lock
    InstallLoop --> Lock["Invoke-WithFileLock<br/>acquire .uipath-pack.lock"]
    Lock --> Worktree{-UseWorktree?}
    Worktree -- yes --> WT["Invoke-GitWorktree<br/>git worktree add HEAD"]
    Worktree -- no --> PackLoop
    WT --> PackLoop
    PackLoop[For each target in -Targets] --> Pack["Invoke-PackAndStage<br/>bump · uipcli pack · stage"]
    Pack --> More{more targets?}
    More -- "yes, NoBump=true" --> PackLoop
    More -- no --> MultiTfm{"-MultiTfm<br/>and 2 targets?"}
    MultiTfm -- yes --> Merge["Invoke-MultiTfmMerge<br/>merge lib/ TFMs"]
    MultiTfm -- no --> Return
    Merge --> Return(["return string[] nupkg paths"])
```

---

## 3. Config hierarchy — four-layer merge

Every setting resolves through four layers. Higher layers never need to remove lower ones.

```mermaid
flowchart BT
    L1["Layer 1 — User config<br/>%LOCALAPPDATA%\\cpmf\\CpmfUipsPack\\config.psd1<br/>Personal defaults across all projects"]
    L2["Layer 2 — Environment variables<br/>UIPS_FEEDPATH · UIPS_TARGETS · UIPS_NO_BUMP …<br/>CI/CD injection · wrapper tools"]
    L3["Layer 3 — Project config<br/>-ConfigFile .\\uipath-pack.psd1<br/>Per-project · checked into source control"]
    L4["Layer 4 — Explicit parameters<br/>-FeedPath · -Targets · -NoBump …<br/>One-off command-line overrides"]

    L1 -->|overridden by| L2
    L2 -->|overridden by| L3
    L3 -->|overridden by| L4
```

---

## 4. uipcli version family decision tree

Two families, two completely different install paths and exe locations.

```mermaid
flowchart TD
    V[CliVersion] --> Match{"matches '^23\\.'?"}

    Match -- yes --> Classic["Generation: classic<br/>.NET 6.0.36<br/>base + WindowsDesktop"]
    Match -- no  --> DotnetTool["Generation: dotnet-tool<br/>.NET 8 SDK<br/>dotnet tool install"]

    Classic --> ClassicExe["uipcli exe:<br/>ToolBase\\uipcli-VER\\extracted\\tools\\uipcli.exe"]
    Classic --> ClassicDotnet["dotnet dir:<br/>ToolBase\\dotnet\\"]

    DotnetTool --> DotnetToolExe["uipcli exe:<br/>ToolBase\\uipcli-VER\\uipcli.exe"]
    DotnetTool --> DotnetToolDir["dotnet dir:<br/>ToolBase\\dotnet8\\"]
```

---

## 5. `Install-CpmfUipsPackCommandLineTool` — user-profile install flow

Downloads uipcli and its .NET runtime into `%LOCALAPPDATA%\cpmf\tools\` (user profile, no admin rights).
Each step checks whether the artifact already exists before downloading — safe to call repeatedly.

```mermaid
flowchart TD
    Start(["Install-CpmfUipsPackCommandLineTool -CliVersion"]) --> Family{"'^23\\.' match?"}

    Family -- yes --> Check6{".NET 6.0.36<br/>marker exists?"}
    Check6 -- yes --> Skip6[skip .NET 6 install]
    Check6 -- no  --> DL6["dotnet-install.ps1<br/>-Runtime dotnet -Version 6.0.36<br/>-Runtime windowsdesktop -Version 6.0.36"]
    DL6 --> Path6["Add-ToUserPath<br/>Set DOTNET_ROOT"]
    Skip6 --> CheckCli6{"uipcli.exe<br/>exists?"}
    Path6 --> CheckCli6
    CheckCli6 -- yes --> Done([done])
    CheckCli6 -- no  --> DLNupkg["Invoke-WebRequest<br/>uipath.cli.windows.VER.nupkg"]
    DLNupkg --> Extract["ZipFile::ExtractToDirectory<br/>→ extracted\\tools\\uipcli.exe"]
    Extract --> Done

    Family -- no  --> Check8{".NET 8 SDK<br/>dotnet.exe exists?"}
    Check8 -- yes --> Skip8[skip .NET 8 install]
    Check8 -- no  --> DL8["dotnet-install.ps1<br/>-Channel 8.0"]
    DL8 --> Path8[Add-ToUserPath]
    Skip8 --> CheckCli8{"uipcli.exe<br/>exists?"}
    Path8 --> CheckCli8
    CheckCli8 -- yes --> Done
    CheckCli8 -- no  --> DotnetTool["dotnet tool install<br/>UiPath.CLI.Windows --tool-path"]
    DotnetTool --> Done
```

---

## 6. Version bump logic

Three version formats, three bump rules.

```mermaid
flowchart TD
    V[read projectVersion] --> Pre{"contains<br/>'-' prerelease?"}
    Pre -- yes --> BumpPre["increment last prerelease segment<br/>1.2.3-alpha.4 → 1.2.3-alpha.5"]
    Pre -- no  --> Build{"contains<br/>'+' build metadata?"}
    Build -- yes --> BumpBuild["increment last build segment<br/>1.2.3+build.4 → 1.2.3+build.5"]
    Build -- no  --> BumpMinor["minor increment, reset patch<br/>1.2.3 → 1.3.0"]
    BumpPre --> Write[write back to project.json]
    BumpBuild --> Write
    BumpMinor --> Write
    Write --> Return([return new version string])
```

---

## 7. Multi-target build — version bump coordination

The version is bumped exactly once regardless of how many targets are built.

```mermaid
sequenceDiagram
    participant I as Invoke-CpmfUipsPack
    participant P as Invoke-PackAndStage
    participant V as Update-CpmfUipsPackProjectVersion
    participant U as Invoke-UipcliPack

    I->>P: target=net6, NoBump=false
    P->>V: bump projectVersion
    V-->>P: 1.3.0
    P->>U: uipcli pack → MyProject.1.3.0.net6.nupkg
    U-->>P: exit 0
    P-->>I: path to .net6.nupkg

    I->>P: target=net8, NoBump=true
    Note over P,V: version already 1.3.0 — no second bump
    P->>U: uipcli pack → MyProject.1.3.0.net8.nupkg
    U-->>P: exit 0
    P-->>I: path to .net8.nupkg

    I-->>I: return [net6path, net8path]
```

---

## 8. Git worktree mode — working directory isolation

When `-UseWorktree` is set, packing happens in a throw-away git worktree. The
working directory and any open Studio instances are never touched.

```mermaid
sequenceDiagram
    participant I as Invoke-CpmfUipsPack
    participant W as Invoke-GitWorktree
    participant G as git
    participant P as Invoke-PackAndStage

    I->>W: -UseWorktree, ScriptBlock
    W->>G: git worktree add path HEAD
    G-->>W: clean tree at HEAD
    W->>P: run ScriptBlock in worktree path
    P-->>W: packed .nupkg
    W->>G: git worktree remove --force
    Note over G: temp directory cleaned up
    W-->>I: result (even on failure)
```

---

## 9. File lock — concurrency guard

Prevents two simultaneous pack operations on the same project from corrupting
`project.json` or the feed directory.

```mermaid
flowchart TD
    A([Invoke-WithFileLock]) --> TryAcq{"lock file<br/>exists?"}
    TryAcq -- no  --> Create["write PID + timestamp<br/>to .uipath-pack.lock"]
    Create --> Run[run ScriptBlock]
    Run --> Release["delete lock file<br/>finally block"]
    Release --> Done([done])

    TryAcq -- yes --> Warn["Write-Warning<br/>waiting 10 seconds..."]
    Warn --> Sleep[Start-Sleep 10]
    Sleep --> Retry{"lock file<br/>still exists?"}
    Retry -- no  --> Create
    Retry -- yes --> Throw["throw — delete lock<br/>manually if stale"]
```

---

## 10. MultiTfm merge — single nupkg from two builds

For Library projects: takes the net8 nupkg as the base, injects the net6 TFM
from the net6 build, patches the nuspec, and re-packs.

```mermaid
flowchart TD
    Start([Invoke-MultiTfmMerge]) --> Ex8["ZipFile::ExtractToDirectory<br/>net8.nupkg → tempDir"]
    Ex8 --> ReadNet6["ZipFile::OpenRead<br/>net6.nupkg"]
    ReadNet6 --> Filter["filter entries: ^lib/net6.*"]
    Filter --> Copy["copy lib/net6* files<br/>into tempDir"]
    Copy --> Nuspec["patch .nuspec<br/>add net6.0-windows7.0 dependency group<br/>clone of net8 group<br/>minus System.Activities.ViewModels"]
    Nuspec --> Repack["ZipFile::CreateFromDirectory<br/>tempDir → OutputPath"]
    Repack --> Cleanup["finally: remove tempDir"]
    Cleanup --> Return([return OutputPath])
```

---

## 11. Public API surface — grouped by role

```mermaid
graph LR
    subgraph Primary
        IP["Invoke-CpmfUipsPack<br/>Main entry point"]
    end

    subgraph Lifecycle
        IC[Install-CpmfUipsPackCommandLineTool]
        UC[Uninstall-CpmfUipsPackCommandLineTool]
    end

    subgraph Config
        IPC[Install-CpmfUipsPackConfig]
        UPC[Uninstall-CpmfUipsPackConfig]
    end

    subgraph Integration
        GH[Install-CpmfUipsPackGitHook]
    end

    subgraph Composable
        UV[Update-CpmfUipsPackProjectVersion]
        DX[Get-CpmfUipsPackDiagnostics]
    end

    IP -->|calls internally| IC
    IP -->|calls internally| UV
    GH -->|triggers| IP
```

---

## 12. Tool path filesystem layout

What `Get-CpmfUipsToolPaths` computes and where each artifact lives on disk.

```mermaid
graph TD
    TBase["%LOCALAPPDATA%\\cpmf\\tools\\"]

    TBase --> DN6["dotnet\\<br/>.NET 6.0.36 runtime<br/>base + WindowsDesktop"]
    TBase --> DN8["dotnet8\\<br/>.NET 8.0 SDK"]
    TBase --> CLI6["uipcli-23.10.2.6\\"]
    TBase --> CLI8["uipcli-25.10.11\\"]

    DN6 --> Marker6["shared\\Microsoft.WindowsDesktop.App\\6.0.36<br/>install marker"]
    DN6 --> Dotnet6Exe[dotnet.exe]

    DN8 --> Marker8["sdk\\<br/>install marker"]
    DN8 --> Dotnet8Exe[dotnet.exe]

    CLI6 --> Extracted["extracted\\tools\\"]
    Extracted --> Exe6["uipcli.exe — classic path"]

    CLI8 --> Exe8["uipcli.exe — dotnet-tool shim"]
```
