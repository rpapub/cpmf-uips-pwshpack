function Invoke-UipcliPack {
    param(
        [string]  $UipcliExe,
        [string[]]$PackArgs
    )
    $capture = Invoke-NativeCommandCapture -FilePath $UipcliExe -ArgumentList $PackArgs
    $output = @($capture.StdOutLines) + @($capture.StdErrLines)
    $exitCode = $capture.ExitCode

    if ($exitCode -ne 0) {
        # On failure: only surface actionable lines (errors / failures / exceptions).
        # INITIALIZATION, PREPROCESSING, repeated CS1701 warnings, empty lines and
        # the telemetry notice are all noise — route to Verbose only.
        $noisePattern = '^(INITIALIZATION:|PREPROCESSING:|COMPILER:|$)' +
                        '|uipcli: Data collection' +
                        '|warning CS1701:'
        foreach ($line in $output) {
            if ($line -is [System.Management.Automation.ErrorRecord]) {
                $msg = $line.Exception.Message
                if ($msg -match $noisePattern) {
                    Write-Verbose "[uipcli:err] $msg"
                } else {
                    Write-Warning "[uipcli:err] $msg"
                }
            } else {
                $str = "$line"
                if ($str -match $noisePattern) {
                    Write-Verbose "[uipcli] $str"
                } else {
                    Write-Warning "[uipcli] $str"
                }
            }
        }
    } else {
        # On success: stdout/stderr to Verbose only
        foreach ($line in $output) {
            Write-Verbose "[uipcli] $line"
        }
    }

    return $exitCode
}
