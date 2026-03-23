@{
    RootModule        = 'CpmfUipsPack.psm1'
    ModuleVersion     = '0.1.2'
    GUID              = '6cc9c20d-f534-483d-851f-a9441b56d4e9'
    Author            = 'Christian Prior-Mamulyan'
    CompanyName       = 'cprima'
    Copyright         = '(c) Christian Prior-Mamulyan. All rights reserved.'
    Description       = 'Bumps projectVersion, packs a UiPath project with uipcli, and stages the .nupkg to a local NuGet feed. Supports uipcli 23.x (.NET 6) and 25.x+ (.NET 8). Self-installs required runtimes without admin rights. UiPath and UiPath Studio are trademarks of UiPath Inc. This module is not affiliated with or endorsed by UiPath Inc.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Invoke-CpmfUipsPack'
        'Install-CpmfUipsPackCommandLineTool'
        'Uninstall-CpmfUipsPackCommandLineTool'
        'Update-CpmfUipsPackProjectVersion'
        'Install-CpmfUipsPackGitHook'
        'Install-CpmfUipsPackConfig'
        'Uninstall-CpmfUipsPackConfig'
        'Get-CpmfUipsPackDiagnostics'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags        = @('UiPath', 'RPA', 'NuGet', 'CI', 'pack', 'cpmf-uips')
            LicenseUri  = 'https://github.com/rpapub/cpmf-uips-pwshpack/blob/main/LICENSE'
            ProjectUri  = 'https://github.com/rpapub/cpmf-uips-pwshpack'
            ReleaseNotes = 'Rename managed .NET 6 tool folder from dotnet\ to dotnet6\ for clarity (dotnet8\ was already version-suffixed). Existing installs: rename %LOCALAPPDATA%\cpmf\tools\dotnet to dotnet6, or re-run Install-CpmfUipsPackCommandLineTool. Full changelog: https://github.com/rpapub/cpmf-uips-pwshpack/blob/main/CHANGELOG.md'
        }
    }
}
