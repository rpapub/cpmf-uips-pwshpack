function Invoke-WithFileLock {
<#
.SYNOPSIS
    Acquires a file-based lock, runs a script block, then releases the lock.
    On contention, warns the user, waits 10 seconds, and retries once before failing.

.PARAMETER LockFile
    Full path of the lock file to create.

.PARAMETER ScriptBlock
    Code to run while the lock is held.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LockFile,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    function _TryAcquire {
        if (-not (Test-Path $LockFile)) {
            "$PID $(Get-Date -Format 'o')" |
                Set-Content -Path $LockFile -Encoding UTF8 -NoNewline
            return $true
        }
        return $false
    }

    if (-not (_TryAcquire)) {
        $info = Get-Content $LockFile -Raw -ErrorAction SilentlyContinue
        Write-Warning "[Lock] Another Invoke-CpmfUipsPack is running ($info). Waiting 10 seconds before retrying..."
        Start-Sleep -Seconds 10
        if (-not (_TryAcquire)) {
            throw "Lock file still present at '$LockFile'. If no other process is running, delete it manually."
        }
    }

    try {
        & $ScriptBlock
    } finally {
        Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    }
}
