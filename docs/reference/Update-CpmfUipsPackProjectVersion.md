---
external help file: CpmfUipsPack-help.xml
Module Name: CpmfUipsPack
online version:
schema: 2.0.0
---

# Update-CpmfUipsPackProjectVersion

## SYNOPSIS
Reads projectVersion from a UiPath project.json, increments it, writes it back,
and returns the new version string.

## SYNTAX

```
Update-CpmfUipsPackProjectVersion [-ProjectJson] <String> [-NoBump] [-ProgressAction <ActionPreference>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Version bump rules:
  - Prerelease suffix with numeric tail  (1.2.3-alpha.4)  → alpha.5
  - Prerelease suffix without numeric    (1.2.3-alpha)    → alpha.1
  - Build metadata with numeric tail     (1.2.3+build.4)  → build.5
  - Plain release                        (1.2.3)          → 1.3.0  (minor bump)

With -NoBump, the file is not modified; the current version is returned.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -ProjectJson
Path to the UiPath project.json file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoBump
Return the current version without writing any changes.

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

### [string] The new (or current, if -NoBump) version string.
## NOTES

## RELATED LINKS
