@{
    ExcludeRules = @(
        # UTF-8 without BOM is intentional and correct for cross-platform PowerShell 7+ modules.
        'PSUseBOMForUnicodeEncodedFile'

        # Private helper functions (Get-CpmfUipsToolPaths, Test-CpmfUipsPackPrerequisites) use
        # plural/compound nouns intentionally — renaming would break clarity.
        'PSUseSingularNouns'

        # Remove-FromUserPath is a private helper. SupportsShouldProcess is only required
        # for public state-changing cmdlets.
        'PSUseShouldProcessForStateChangingFunctions'

        # PSScriptAnalyzer false-positives: parameters captured in script block closures
        # (FeedPath, UipcliArgs, NoBump, WorktreeBase in Invoke-CpmfUipsPack) appear unused
        # to static analysis but are referenced at runtime via closure capture.
        'PSReviewUnusedParameter'
    )
}
