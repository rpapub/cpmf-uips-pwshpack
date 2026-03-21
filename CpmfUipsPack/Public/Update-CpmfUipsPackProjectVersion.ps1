function Update-CpmfUipsPackProjectVersion {
<#
.SYNOPSIS
    Reads projectVersion from a UiPath project.json, increments it, writes it back,
    and returns the new version string.

.DESCRIPTION
    Version bump rules:
      - Prerelease suffix with numeric tail  (1.2.3-alpha.4)  → alpha.5
      - Prerelease suffix without numeric    (1.2.3-alpha)    → alpha.1
      - Build metadata with numeric tail     (1.2.3+build.4)  → build.5
      - Plain release                        (1.2.3)          → 1.3.0  (minor bump)

    With -NoBump, the file is not modified; the current version is returned.

.PARAMETER ProjectJson
    Path to the UiPath project.json file.

.PARAMETER NoBump
    Return the current version without writing any changes.

.OUTPUTS
    [string] The new (or current, if -NoBump) version string.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectJson,

        [switch]$NoBump
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $ProjectJson = (Resolve-Path $ProjectJson).Path
    $raw = Get-Content $ProjectJson -Raw

    if ($raw -notmatch '"projectVersion"\s*:\s*"([^"]*)"') {
        throw "projectVersion key not found in $ProjectJson — is this a valid UiPath project.json?"
    }
    $current = $Matches[1]

    if ($NoBump) {
        Write-Output $current
        return
    }

    $newVersion = if ($current -match '^(\d+\.\d+\.\d+)-(.+)$') {
        $base = $Matches[1]; $pre = $Matches[2]
        $bumped = if ($pre -match '^(.+\.)(\d+)$') { "$($Matches[1])$([int]$Matches[2] + 1)" } else { "$pre.1" }
        "$base-$bumped"
    } elseif ($current -match '^(\d+\.\d+\.\d+)\+(.+)$') {
        $base = $Matches[1]; $build = $Matches[2]
        $bumped = if ($build -match '^(.+\.)(\d+)$') { "$($Matches[1])$([int]$Matches[2] + 1)" } else { "$build.1" }
        "$base+$bumped"
    } else {
        $parts = $current -split '\.'
        if ($parts.Count -ne 3) { throw "Cannot parse version '$current' — expected major.minor.patch" }
        "$($parts[0]).$([int]$parts[1] + 1).0"
    }

    $updated = $raw -replace '("projectVersion"\s*:\s*")[^"]*(")', "`${1}$newVersion`${2}"
    if ($PSCmdlet.ShouldProcess($ProjectJson, "Write projectVersion $current → $newVersion")) {
        [System.IO.File]::WriteAllText($ProjectJson, $updated, (New-Object System.Text.UTF8Encoding $false))
    }

    Write-Output $newVersion
}
