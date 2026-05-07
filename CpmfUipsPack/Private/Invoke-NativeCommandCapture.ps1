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
        $process = Start-Process `
            -FilePath $FilePath `
            -ArgumentList $ArgumentList `
            -WorkingDirectory $WorkingDirectory `
            -PassThru `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath

        $process.WaitForExit()

        [pscustomobject]@{
            ExitCode    = $process.ExitCode
            StdOutLines = if (Test-Path -LiteralPath $stdoutPath) { @(Get-Content -LiteralPath $stdoutPath) } else { @() }
            StdErrLines = if (Test-Path -LiteralPath $stderrPath) { @(Get-Content -LiteralPath $stderrPath) } else { @() }
        }
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
