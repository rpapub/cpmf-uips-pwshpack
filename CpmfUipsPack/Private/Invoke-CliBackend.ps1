function Invoke-CliBackend {
    <#
    .SYNOPSIS
        Adapter that dispatches pack or analyze to either uipcli or uipathcli.

    .NOTES
        uipathcli flag names verified against `uipathcli --help` from
        https://github.com/UiPath/uipathcli releases. Update if the Go CLI
        changes its argument interface.
    #>
    param(
        [ValidateSet('pack', 'analyze')]
        [string]   $Op,

        [ValidateSet('uipcli', 'uipathcli')]
        [string]   $Backend,

        [string]   $UipcliExe,
        [string]   $UipathcliExe,
        [string]   $ProjectJson,
        [string]   $OutputDir    = '',   # pack only
        [string[]] $ExtraArgs    = @()
    )

    if ($Backend -eq 'uipcli') {
        switch ($Op) {
            'pack' {
                $packArgs = @('package', 'pack', $ProjectJson, '-o', $OutputDir)
                if ($env:UIPATH_DISABLE_TELEMETRY) { $packArgs += '--disableTelemetry' }
                if ($ExtraArgs.Count -gt 0) { $packArgs += $ExtraArgs }
                return Invoke-UipcliPack -UipcliExe $UipcliExe -PackArgs $packArgs
            }
            'analyze' {
                $analyzeArgs = @('package', 'analyze', $ProjectJson)
                if ($ExtraArgs.Count -gt 0) { $analyzeArgs += $ExtraArgs }
                return Invoke-UipathcliCommand -UipathcliExe $UipcliExe -CliArgs $analyzeArgs
            }
        }
    } else {
        # uipathcli (Go binary) — syntax: uipath studio package <op> --source <path> ...
        switch ($Op) {
            'pack' {
                $packArgs = @('studio', 'package', 'pack', '--source', $ProjectJson, '--destination', $OutputDir)
                if ($ExtraArgs.Count -gt 0) { $packArgs += $ExtraArgs }
                return Invoke-UipathcliCommand -UipathcliExe $UipathcliExe -CliArgs $packArgs
            }
            'analyze' {
                $analyzeArgs = @('studio', 'package', 'analyze', '--source', $ProjectJson)
                if ($ExtraArgs.Count -gt 0) { $analyzeArgs += $ExtraArgs }
                return Invoke-UipathcliCommand -UipathcliExe $UipathcliExe -CliArgs $analyzeArgs
            }
        }
    }
}
