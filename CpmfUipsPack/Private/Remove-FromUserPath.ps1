function Remove-FromUserPath {
    param([string]$Token)
    $expanded = [Environment]::ExpandEnvironmentVariables($Token)
    $raw      = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ([string]::IsNullOrEmpty($raw)) { return $false }
    $entries = $raw -split ';' | Where-Object { $_ -ne '' -and $_ -ne $Token -and $_ -ne $expanded }
    $newRaw  = $entries -join ';'
    if ($newRaw -eq $raw) { return $false }
    [Environment]::SetEnvironmentVariable('PATH', $newRaw, 'User')
    return $true
}
