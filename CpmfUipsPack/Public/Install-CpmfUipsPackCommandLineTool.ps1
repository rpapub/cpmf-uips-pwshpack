function Install-CpmfUipsPackCommandLineTool {
<#
.SYNOPSIS
    Downloads and installs uipcli and its required .NET runtime into the user
    profile (%LOCALAPPDATA%\cpmf\tools). No admin rights required. Idempotent:
    already-present artifacts are detected and skipped.

    For uipcli 23.x (classic): downloads .NET 6.0.36 (base + WindowsDesktop)
    and extracts uipcli from its NuGet package.

    For uipcli 25.x+ (dotnet tool): downloads the .NET 8 SDK and installs
    uipcli via `dotnet tool install` into the user profile.

.PARAMETER CliVersion
    UiPath CLI version to install. Defaults to 23.10.2.6.
    Versions matching '^23\.' use the classic nupkg extraction path.
    All other versions use the dotnet tool install path.

.PARAMETER ToolBase
    Root directory for all installed tools. Defaults to %LOCALAPPDATA%\cpmf\tools.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$CliVersion = '23.10.2.6',
        [string]$ToolBase   = (Join-Path $env:LOCALAPPDATA 'cpmf\tools')
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $p = Get-CpmfUipsToolPaths -CliVersion $CliVersion -ToolBase $ToolBase

    if ($CliVersion -match '^23\.') {
        # ── Classic path: .NET 6.0.36 (base + WindowsDesktop) + nupkg extraction ──

        # Migrate legacy dotnet\ → dotnet6\ in place (v0.1.2 renamed the folder; existing
        # installs are not automatically migrated and would trigger a needless re-download).
        $legacyDotnetDir = Join-Path $ToolBase 'dotnet'
        if ((Test-Path $legacyDotnetDir) -and -not (Test-Path $p.DotnetDir)) {
            Write-Verbose "[Install] Migrating legacy dotnet\ to dotnet6\ ..."
            Rename-Item $legacyDotnetDir $p.DotnetDir
            $legacyToken = '%LOCALAPPDATA%\cpmf\tools\dotnet'
            if (Remove-FromUserPath $legacyToken) {
                Write-Verbose "[Install] Removed legacy $legacyToken from user PATH"
            }
            if (Add-ToUserPath $p.DotnetToken) {
                Write-Verbose "[Install] Added $($p.DotnetToken) to user PATH"
            }
            $oldRoot = [Environment]::GetEnvironmentVariable('DOTNET_ROOT', 'User')
            if ($oldRoot -eq $legacyDotnetDir) {
                [Environment]::SetEnvironmentVariable('DOTNET_ROOT', $p.DotnetDir, 'User')
            }
        }

        Write-Verbose "[Install] Checking .NET 6.0.36 WindowsDesktop runtime in $($p.DotnetDir)"

        if (Test-Path $p.DotnetMarker) {
            Write-Verbose "[Install] .NET 6.0.36 already installed — skipping"
        } elseif ($PSCmdlet.ShouldProcess($p.DotnetDir, 'Install .NET 6.0.36 (base + WindowsDesktop)')) {
            Write-Progress -Activity 'CpmfUipsPack: install' -Status 'Downloading .NET 6.0.36 runtime …'
            Write-Verbose "[Install] Installing .NET 6.0.36 into $($p.DotnetDir) ..."
            $null = New-Item -ItemType Directory -Path $p.DotnetDir -Force
            $installScript = Join-Path ([System.IO.Path]::GetTempPath()) 'dotnet-install.ps1'

            try {
                Invoke-WebRequest `
                    -Uri 'https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.ps1' `
                    -OutFile $installScript `
                    -UseBasicParsing `
                    -TimeoutSec 120

                Write-Verbose "[Install] Installing base runtime ..."
                & $installScript -Runtime dotnet -Version 6.0.36 -InstallDir $p.DotnetDir
                if ($LASTEXITCODE -ne 0) { throw "dotnet-install.ps1 (base) exited with code $LASTEXITCODE" }
                if (-not (Test-Path (Join-Path $p.DotnetDir 'dotnet.exe'))) {
                    throw "Base runtime install failed — dotnet.exe not found in $($p.DotnetDir)"
                }

                Write-Verbose "[Install] Installing WindowsDesktop runtime ..."
                & $installScript -Runtime windowsdesktop -Version 6.0.36 -InstallDir $p.DotnetDir
                if ($LASTEXITCODE -ne 0) { throw "dotnet-install.ps1 (windowsdesktop) exited with code $LASTEXITCODE" }
                if (-not (Test-Path $p.DotnetMarker)) {
                    throw "WindowsDesktop runtime install failed — marker not found: $($p.DotnetMarker)"
                }
            } finally {
                Remove-Item $installScript -Force -ErrorAction SilentlyContinue
            }

            # Persist PATH using unexpanded token (portable; stored as REG_EXPAND_SZ)
            if (Add-ToUserPath $p.DotnetToken) {
                Write-Verbose "[Install] Added $($p.DotnetToken) to user PATH"
            }
            # DOTNET_ROOT stored expanded (REG_SZ — Windows does not expand it automatically)
            [Environment]::SetEnvironmentVariable('DOTNET_ROOT', $p.DotnetDir, 'User')
            Write-Verbose "[Install] .NET 6.0.36 installed at $($p.DotnetDir)"
        }

        # Ensure current session sees the local runtime
        $env:DOTNET_ROOT = $p.DotnetDir
        if ($env:PATH -notlike "*$($p.DotnetDir)*") {
            $env:PATH = "$($p.DotnetDir);$env:PATH"
        }

        # ── Step 1a: uipcli 23.x — nupkg download + ZipFile extraction ──
        Write-Verbose "[Install] Checking uipcli $CliVersion in $($p.CliToolDir)"

        if (Test-Path $p.UipcliExe) {
            Write-Verbose "[Install] uipcli $CliVersion already installed — skipping"
            return
        }

        if (-not $PSCmdlet.ShouldProcess($p.CliToolDir, "Download and extract uipcli $CliVersion")) { return }

        Write-Progress -Activity 'CpmfUipsPack: install' -Status "Downloading uipcli $CliVersion …"
        $feedBase     = 'https://uipath.pkgs.visualstudio.com/Public.Feeds/_packaging/UiPath-Official/nuget/v3/flat2/uipath.cli.windows'
        $nupkgUrl     = "$feedBase/$CliVersion/uipath.cli.windows.$CliVersion.nupkg"
        $downloadPath = Join-Path $p.CliToolDir 'uipcli.nupkg'
        $null = New-Item -ItemType Directory -Path $p.CliToolDir -Force

        try {
            Write-Verbose "[Install] Downloading uipcli $CliVersion ..."
            Invoke-WebRequest -Uri $nupkgUrl -OutFile $downloadPath -UseBasicParsing -TimeoutSec 120
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, (Join-Path $p.CliToolDir 'extracted'))
            if (-not (Test-Path $p.UipcliExe)) {
                throw "uipcli extraction failed — exe not found at $($p.UipcliExe)"
            }
        } catch {
            Remove-Item $p.CliToolDir -Recurse -Force -ErrorAction SilentlyContinue
            throw
        } finally {
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
        }

        Write-Progress -Activity 'CpmfUipsPack: install' -Completed
        Write-Verbose "[Install] Installed uipcli $CliVersion at $($p.UipcliExe)"

    } else {
        # ── dotnet-tool path: minimal .NET 8 SDK + dotnet tool install ──

        Write-Verbose "[Install] Checking .NET 8 SDK in $($p.DotnetDir)"

        $dotnetExe = Join-Path $p.DotnetDir 'dotnet.exe'

        if (Test-Path $dotnetExe) {
            Write-Verbose "[Install] .NET 8 SDK already installed — skipping"
        } elseif ($PSCmdlet.ShouldProcess($p.DotnetDir, 'Install .NET 8 SDK (minimal)')) {
            Write-Verbose "[Install] Installing .NET 8 SDK into $($p.DotnetDir) ..."
            $null = New-Item -ItemType Directory -Path $p.DotnetDir -Force
            $installScript = Join-Path ([System.IO.Path]::GetTempPath()) 'dotnet-install-8.ps1'

            try {
                Invoke-WebRequest `
                    -Uri 'https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.ps1' `
                    -OutFile $installScript `
                    -UseBasicParsing `
                    -TimeoutSec 120

                # No -Runtime flag = SDK install (includes dotnet CLI for tool commands)
                & $installScript -Channel 8.0 -InstallDir $p.DotnetDir
                if ($LASTEXITCODE -ne 0) { throw "dotnet-install.ps1 (.NET 8 SDK) exited with code $LASTEXITCODE" }
                if (-not (Test-Path $dotnetExe)) {
                    throw ".NET 8 SDK install failed — dotnet.exe not found in $($p.DotnetDir)"
                }
            } finally {
                Remove-Item $installScript -Force -ErrorAction SilentlyContinue
            }

            # Persist PATH so the uipcli shim can locate dotnet at runtime
            if (Add-ToUserPath $p.DotnetToken) {
                Write-Verbose "[Install] Added $($p.DotnetToken) to user PATH"
            }
            Write-Verbose "[Install] .NET 8 SDK installed at $($p.DotnetDir)"
        }

        # Ensure current session sees the local .NET 8 SDK
        if ($env:PATH -notlike "*$($p.DotnetDir)*") {
            $env:PATH = "$($p.DotnetDir);$env:PATH"
        }

        # ── Step 1b: uipcli 25.x+ — dotnet tool install ──
        Write-Verbose "[Install] Checking uipcli $CliVersion in $($p.CliToolDir)"

        if (Test-Path $p.UipcliExe) {
            Write-Verbose "[Install] uipcli $CliVersion already installed — skipping"
            return
        }

        if (-not $PSCmdlet.ShouldProcess($p.CliToolDir, "dotnet tool install UiPath.CLI.Windows $CliVersion")) { return }

        $null = New-Item -ItemType Directory -Path $p.CliToolDir -Force
        $feedUrl = 'https://uipath.pkgs.visualstudio.com/Public.Feeds/_packaging/UiPath-Official/nuget/v3/index.json'

        try {
            Write-Verbose "[Install] Installing uipcli $CliVersion via dotnet tool ..."
            & $dotnetExe tool install UiPath.CLI.Windows `
                --tool-path  $p.CliToolDir `
                --version    $CliVersion `
                --add-source $feedUrl
            if ($LASTEXITCODE -ne 0) {
                throw "dotnet tool install UiPath.CLI.Windows $CliVersion failed (exit $LASTEXITCODE)"
            }
            if (-not (Test-Path $p.UipcliExe)) {
                throw "dotnet tool install succeeded but uipcli.exe not found at $($p.UipcliExe)"
            }
        } catch {
            Remove-Item $p.CliToolDir -Recurse -Force -ErrorAction SilentlyContinue
            throw
        }

        Write-Verbose "[Install] Installed uipcli $CliVersion at $($p.UipcliExe)"
    }
}
