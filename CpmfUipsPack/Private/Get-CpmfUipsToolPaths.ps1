function Get-CpmfUipsToolPaths {
    param(
        [string]$CliVersion = '23.10.2.6',
        [string]$ToolBase   = (Join-Path $env:LOCALAPPDATA 'cpmf\tools')
    )

    if ($CliVersion -match '^23\.') {
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
        Generation      = $generation
        DotnetDir       = $dotnetDir
        DotnetToken     = $dotnetToken
        DotnetMarker    = $dotnetMarker
        CliToolDir      = Join-Path $ToolBase "uipcli-$CliVersion"
        UipcliExe       = $uipcliExe
        UipathcliDir    = Join-Path $ToolBase 'uipathcli'
        UipathcliExe    = Join-Path $ToolBase 'uipathcli\uipathcli.exe'
    }
}
