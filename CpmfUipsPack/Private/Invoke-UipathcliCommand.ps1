function Invoke-UipathcliCommand {
    param(
        [string]  $UipathcliExe,
        [string[]]$CliArgs
    )
    $output = & $UipathcliExe @CliArgs 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        foreach ($line in $output) {
            if ($line -is [System.Management.Automation.ErrorRecord]) {
                Write-Warning "[uipathcli:err] $($line.Exception.Message)"
            } else {
                Write-Warning "[uipathcli] $line"
            }
        }
    } else {
        foreach ($line in $output) {
            if ($line -isnot [System.Management.Automation.ErrorRecord]) {
                Write-Verbose "[uipathcli] $line"
            }
        }
    }

    return $exitCode
}
