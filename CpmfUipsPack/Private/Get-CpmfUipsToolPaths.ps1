function Get-CpmfUipsToolPaths {
    param(
        [string]$CliVersion = '25.10.15',
        [string]$ToolBase   = (Join-Path $env:LOCALAPPDATA 'cpmf\tools')
    )

    # Dotnet global tool packaging was introduced in 25.10.2-20251124-7.
    # Strip prerelease suffix (e.g. "25.10.2-20251124-7" → "25.10.2") for comparison.
    $vBase  = ($CliVersion -split '-')[0]
    $parts  = $vBase -split '\.'
    $isDotnetTool = (
        $parts.Count -ge 3 -and
        (
            [int]$parts[0] -gt 25 -or
            ([int]$parts[0] -eq 25 -and [int]$parts[1] -gt 10) -or
            ([int]$parts[0] -eq 25 -and [int]$parts[1] -eq 10 -and [int]$parts[2] -ge 2)
        )
    )

    if (-not $isDotnetTool) {
        # Classic nupkg extraction — requires .NET 6 (base + WindowsDesktop)
        $dotnetDir    = Join-Path $ToolBase 'dotnet6'
        $dotnetToken  = '%LOCALAPPDATA%\cpmf\tools\dotnet6'
        $dotnetMarker = Join-Path $dotnetDir "shared\Microsoft.WindowsDesktop.App\6.0.36"
        $uipcliExe    = Join-Path $ToolBase "uipcli-$CliVersion\extracted\tools\uipcli.exe"
        $generation   = 'classic'
    } else {
        # dotnet tool install — requires .NET 8 SDK
        $dotnetDir    = Join-Path $ToolBase 'dotnet8'
        $dotnetToken  = '%LOCALAPPDATA%\cpmf\tools\dotnet8'
        # sdk\ subdirectory is created by dotnet-install.ps1 when the SDK is installed
        $dotnetMarker = Join-Path $dotnetDir 'sdk'
        $uipcliExe    = Join-Path $ToolBase "uipcli-$CliVersion\uipcli.exe"
        $generation   = 'dotnet-tool'
    }

    @{
        CliVersion      = $CliVersion
        ToolBase        = $ToolBase
        IsDotnetTool    = $isDotnetTool
        Generation      = $generation
        DotnetDir       = $dotnetDir
        DotnetToken     = $dotnetToken
        DotnetMarker    = $dotnetMarker
        CliToolDir      = Join-Path $ToolBase "uipcli-$CliVersion"
        UipcliExe       = $uipcliExe
        UipathcliDir    = Join-Path $ToolBase 'uipathcli'
        UipathcliExe    = Join-Path $ToolBase 'uipathcli\uipath.exe'
    }
}
