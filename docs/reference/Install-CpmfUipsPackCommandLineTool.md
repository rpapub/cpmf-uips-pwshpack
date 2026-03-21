---
external help file: CpmfUipsPack-help.xml
Module Name: CpmfUipsPack
online version:
schema: 2.0.0
---

# Install-CpmfUipsPackCommandLineTool

## SYNOPSIS
Downloads and installs uipcli and its required .NET runtime into the user
profile (%LOCALAPPDATA%\cpmf\tools).
No admin rights required.
Idempotent:
already-present artifacts are detected and skipped.

For uipcli 23.x (classic): downloads .NET 6.0.36 (base + WindowsDesktop)
and extracts uipcli from its NuGet package.

For uipcli 25.x+ (dotnet tool): downloads the .NET 8 SDK and installs
uipcli via \`dotnet tool install\` into the user profile.

## SYNTAX

```
Install-CpmfUipsPackCommandLineTool [[-CliVersion] <String>] [[-ToolBase] <String>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -CliVersion
UiPath CLI version to install.
Defaults to 23.10.2.6.
Versions matching '^23\.' use the classic nupkg extraction path.
All other versions use the dotnet tool install path.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: 23.10.2.6
Accept pipeline input: False
Accept wildcard characters: False
```

### -ToolBase
Root directory for all installed tools.
Defaults to %LOCALAPPDATA%\cpmf\tools.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: (Join-Path $env:LOCALAPPDATA 'cpmf\tools')
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
