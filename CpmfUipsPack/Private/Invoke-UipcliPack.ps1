function Invoke-UipcliPack {
    param(
        [string]  $UipcliExe,
        [string[]]$PackArgs
    )
    & $UipcliExe @PackArgs
    return $LASTEXITCODE
}
