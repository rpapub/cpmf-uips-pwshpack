function Get-CpmfUipsToolPaths {
    param(
        [string]$CliVersion = '25.10.15',
        [string]$UipcliPath,
        [string]$ToolBase   = (Join-Path $env:LOCALAPPDATA 'cpmf\tools')
    )

    $resolvedToolBase = $ToolBase
    $resolvedCliVersion = $CliVersion
    $resolvedUipcliExe = $null
    $isDotnetTool = $false
    $generation = 'classic'

    if (-not [string]::IsNullOrWhiteSpace($UipcliPath)) {
        $normalizedPath = ($UipcliPath -replace '/', '\').Trim()
        if ($normalizedPath -match '^(?<toolBase>.+)\\uipcli-(?<version>[^\\]+)\\extracted\\tools\\uipcli\.exe$') {
            $resolvedToolBase = $Matches.toolBase
            $resolvedCliVersion = $Matches.version
            $resolvedUipcliExe = $normalizedPath
            $generation = 'classic'
            $isDotnetTool = $false
        } elseif ($normalizedPath -match '^(?<toolBase>.+)\\uipcli-(?<version>[^\\]+)\\uipcli\.exe$') {
            $resolvedToolBase = $Matches.toolBase
            $resolvedCliVersion = $Matches.version
            $resolvedUipcliExe = $normalizedPath
            $generation = 'dotnet-tool'
            $isDotnetTool = $true
        } else {
            throw "Unsupported UipcliPath format: $UipcliPath"
        }
    } else {
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
        $generation = if ($isDotnetTool) { 'dotnet-tool' } else { 'classic' }
    }

    if (-not $isDotnetTool) {
        # Classic nupkg extraction — requires .NET 6 (base + WindowsDesktop)
        $dotnetDir    = Join-Path $resolvedToolBase 'dotnet6'
        $dotnetToken  = $dotnetDir
        $dotnetMarker = Join-Path $dotnetDir "shared\Microsoft.WindowsDesktop.App\6.0.36"
        $uipcliExe    = if ($resolvedUipcliExe) { $resolvedUipcliExe } else { Join-Path $resolvedToolBase "uipcli-$resolvedCliVersion\extracted\tools\uipcli.exe" }
    } else {
        # dotnet tool install — requires .NET 8 SDK
        $dotnetDir    = Join-Path $resolvedToolBase 'dotnet8'
        $dotnetToken  = $dotnetDir
        # sdk\ subdirectory is created by dotnet-install.ps1 when the SDK is installed
        $dotnetMarker = Join-Path $dotnetDir 'sdk'
        $uipcliExe    = if ($resolvedUipcliExe) { $resolvedUipcliExe } else { Join-Path $resolvedToolBase "uipcli-$resolvedCliVersion\uipcli.exe" }
    }

    @{
        CliVersion      = $resolvedCliVersion
        ToolBase        = $resolvedToolBase
        IsDotnetTool    = $isDotnetTool
        Generation      = $generation
        DotnetDir       = $dotnetDir
        DotnetToken     = $dotnetToken
        DotnetMarker    = $dotnetMarker
        CliToolDir      = Join-Path $resolvedToolBase "uipcli-$resolvedCliVersion"
        UipcliExe       = $uipcliExe
        UipathcliDir    = Join-Path $resolvedToolBase 'uipathcli'
        UipathcliExe    = Join-Path $resolvedToolBase 'uipathcli\uipath.exe'
    }
}
