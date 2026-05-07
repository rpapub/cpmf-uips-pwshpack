function Invoke-NativeCommandCapture {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$ArgumentList = @(),

        [string]$WorkingDirectory = (Get-Location).Path
    )

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    $stdoutPath = Join-Path $tempRoot 'stdout.txt'
    $stderrPath = Join-Path $tempRoot 'stderr.txt'

    $null = New-Item -ItemType Directory -Path $tempRoot -Force

    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $FilePath
        $psi.WorkingDirectory = $WorkingDirectory
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        if ($psi.PSObject.Properties.Name -contains 'StandardOutputEncoding') {
            $psi.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
        }
        if ($psi.PSObject.Properties.Name -contains 'StandardErrorEncoding') {
            $psi.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
        }
        foreach ($arg in $ArgumentList) {
            [void]$psi.ArgumentList.Add([string]$arg)
        }

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $psi

        if (-not $process.Start()) {
            throw "Failed to start native process: $FilePath"
        }

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        [System.Threading.Tasks.Task]::WaitAll(@([System.Threading.Tasks.Task]$stdoutTask, [System.Threading.Tasks.Task]$stderrTask))

        $stdoutText = $stdoutTask.Result
        $stderrText = $stderrTask.Result

        [pscustomobject]@{
            ExitCode    = $process.ExitCode
            StdOutLines = if ([string]::IsNullOrWhiteSpace($stdoutText)) { @() } else { @($stdoutText -split "`r?`n") | Where-Object { $_ -ne '' } }
            StdErrLines = if ([string]::IsNullOrWhiteSpace($stderrText)) { @() } else { @($stderrText -split "`r?`n") | Where-Object { $_ -ne '' } }
        }
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
