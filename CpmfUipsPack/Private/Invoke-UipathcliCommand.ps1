function Invoke-UipathcliCommand {
    param(
        [string]  $UipathcliExe,
        [string[]]$CliArgs
    )
    $capture = Invoke-NativeCommandCapture -FilePath $UipathcliExe -ArgumentList $CliArgs
    $output = @($capture.StdOutLines) + @($capture.StdErrLines)
    $exitCode = $capture.ExitCode

    if ($exitCode -ne 0) {
        foreach ($line in $output) {
            Write-Warning "[uipathcli] $line"
        }
    } else {
        foreach ($line in $output) {
            Write-Verbose "[uipathcli] $line"
        }
    }

    return $exitCode
}
