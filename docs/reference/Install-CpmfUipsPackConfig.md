---
external help file: CpmfUipsPack-help.xml
Module Name: CpmfUipsPack
online version:
schema: 2.0.0
---

# Install-CpmfUipsPackConfig

## SYNOPSIS
Scaffolds the user-level CpmfUipsPack config file at the XDG-inspired location:
    %LOCALAPPDATA%\cpmf\CpmfUipsPack\config.psd1

## SYNTAX

```
Install-CpmfUipsPackConfig [-Force] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Copies the bundled examples\uipath-pack.psd1 to the user config directory.
All keys in the file are commented examples - edit the file to activate them.

The user config is the lowest-priority config source.
It is overridden by:
    env vars (UIPS_*)  \>  -ConfigFile  \>  explicit parameters

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Force
Overwrite an existing config file.
Without -Force, the command does nothing
if the target file already exists.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
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
