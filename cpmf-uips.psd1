@{
    Backend        = 'uipcli'
    FeedPath       = 'C:\Users\Public\nugetfeed'
    Targets        = @('net6')
    UipcliPathNet6 = '$env:LOCALAPPDATA\cpmf\tools\uipcli-23.10.9351.15515\extracted\tools\uipcli.exe'
    UipcliPathNet8 = '$env:LOCALAPPDATA\cpmf\tools\uipcli-25.10.15\uipcli.exe'
    ToolBasePath   = '$env:LOCALAPPDATA\cpmf\tools'
}
