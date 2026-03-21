function Invoke-UipcliPack {
    param(
        [string]  $UipcliExe,
        [string[]]$PackArgs
    )
    $output = & $UipcliExe @PackArgs 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        # On failure: emit everything so the caller can see what went wrong
        foreach ($line in $output) {
            if ($line -is [System.Management.Automation.ErrorRecord]) {
                Write-Warning "[uipcli:err] $($line.Exception.Message)"
            } else {
                Write-Warning "[uipcli] $line"
            }
        }
    } else {
        # On success: stdout to Verbose only
        foreach ($line in $output) {
            if ($line -isnot [System.Management.Automation.ErrorRecord]) {
                Write-Verbose "[uipcli] $line"
            }
        }
    }

    return $exitCode
}
