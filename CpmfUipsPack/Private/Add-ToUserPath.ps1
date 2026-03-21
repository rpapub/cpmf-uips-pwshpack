function Add-ToUserPath {
    param([string]$Token)
    $expanded = [Environment]::ExpandEnvironmentVariables($Token)
    $raw      = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $entries  = if ([string]::IsNullOrEmpty($raw)) { @() }
                else { $raw -split ';' | Where-Object { $_ -ne '' } }
    $present  = $entries | Where-Object { $_ -ieq $Token -or $_ -ieq $expanded }
    if ($present) { return $false }
    $newRaw = ($Token + ';' + ($entries -join ';')).TrimEnd(';')
    [Environment]::SetEnvironmentVariable('PATH', $newRaw, 'User')
    return $true
}
