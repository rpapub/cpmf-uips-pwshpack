@{
    RootModule        = 'CpmfUipsPack.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = '6cc9c20d-f534-483d-851f-a9441b56d4e9'
    Author            = 'Christian Prior-Mamulyan'
    CompanyName       = 'cprima'
    Copyright         = '(c) Christian Prior-Mamulyan. All rights reserved.'
    Description       = 'Bumps projectVersion, packs a UiPath project with uipcli, and stages the .nupkg to a local NuGet feed. Supports uipcli 23.x (.NET 6) and 25.x+ (.NET 8). Self-installs required runtimes without admin rights. UiPath and UiPath Studio are trademarks of UiPath Inc. This module is not affiliated with or endorsed by UiPath Inc.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Invoke-CpmfUipsPack'
        'Invoke-CpmfUipsAnalyze'
        'Install-CpmfUipsPackCommandLineTool'
        'Uninstall-CpmfUipsPackCommandLineTool'
        'Install-UipathcliTool'
        'Uninstall-UipathcliTool'
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
            ReleaseNotes = 'Add CLI adapter pattern: -Backend uipcli|uipathcli on Invoke-CpmfUipsPack and new Invoke-CpmfUipsAnalyze. Install-UipathcliTool/Uninstall-UipathcliTool manage the Go binary. Full changelog: https://github.com/rpapub/cpmf-uips-pwshpack/blob/main/CHANGELOG.md'
        }
    }
}
