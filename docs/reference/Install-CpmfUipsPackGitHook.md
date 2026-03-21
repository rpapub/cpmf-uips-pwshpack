---
external help file: CpmfUipsPack-help.xml
Module Name: CpmfUipsPack
online version:
schema: 2.0.0
---

# Install-CpmfUipsPackGitHook

## SYNOPSIS
Installs a git pre-push hook that calls Invoke-CpmfUipsPack -UseWorktree
automatically before every push.

## SYNTAX

```
Install-CpmfUipsPackGitHook [[-RepoRoot] <String>] [-ProjectJson] <String> [[-ModulePath] <String>]
 [[-AdditionalArgs] <String[]>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Writes a pre-push hook script to \<RepoRoot\>/.git/hooks/pre-push with
LF line endings and no file extension (required by Git for Windows).

The hook calls Invoke-CpmfUipsPack with -UseWorktree so it packs from a
clean worktree, never touching the working directory.

ProjectJson is written as an absolute path at install time.
If you move
or re-clone the repository, re-run Install-CpmfUipsPackGitHook.

## EXAMPLES

### EXAMPLE 1
```
Install-CpmfUipsPackGitHook `
    -RepoRoot    'C:\repos\MyProject' `
    -ProjectJson 'C:\repos\MyProject\project.json'
```

## PARAMETERS

### -RepoRoot
Root of the git repository.
Defaults to the current directory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: (Get-Location).Path
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProjectJson
Absolute path to the UiPath project.json.
Written verbatim into the hook.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModulePath
Path to CpmfUipsPack.psd1.
Written verbatim into the hook so the hook can
Import-Module without relying on the user's PSModulePath.
Defaults to
the path of the currently loaded CpmfUipsPack module manifest.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: (Get-Module CpmfUipsPack | Select-Object -ExpandProperty Path)
Accept pipeline input: False
Accept wildcard characters: False
```

### -AdditionalArgs
Extra arguments appended to the Invoke-CpmfUipsPack call in the hook,
e.g.
@('-SkipInstall', '-FeedPath', 'C:\myfeed').

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
