#Requires -Version 7

foreach ($file in (Get-ChildItem "$PSScriptRoot/Private/*.ps1" -ErrorAction Stop)) {
    . $file.FullName
}
foreach ($file in (Get-ChildItem "$PSScriptRoot/Public/*.ps1" -ErrorAction Stop)) {
    . $file.FullName
}

Write-Verbose "[CpmfUipsPack] © 2026 Christian Prior-Mamulyan — Apache 2.0"
# UiPath and UiPath Studio are trademarks of UiPath Inc. This module is not affiliated with or endorsed by UiPath Inc.
