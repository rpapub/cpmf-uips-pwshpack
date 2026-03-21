---
external help file: CpmfUipsPack-help.xml
Module Name: CpmfUipsPack
online version:
schema: 2.0.0
---

# Get-CpmfUipsPackDiagnostics

## SYNOPSIS
Generates a pseudonymized diagnostic report suitable for pasting into a
GitHub issue or support request.

## SYNTAX

```
Get-CpmfUipsPackDiagnostics [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Collects environment information relevant to CpmfUipsPack installation and
operation.
All personal identifiers (username, computer name, domain) are
replaced with placeholders.
Environment variable values are never emitted -
only whether each UIPS_* variable is set or not.

## EXAMPLES

### EXAMPLE 1
```
Get-CpmfUipsPackDiagnostics
```

Prints a report block to the console.
Copy and paste the output directly
into https://github.com/rpapub/cpmf-uips-pwshpack/issues

## PARAMETERS

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

### System.String[]
## NOTES

## RELATED LINKS
