function Invoke-MultiTfmMerge {
<#
.SYNOPSIS
    Merges the lib/ TFM entries from a net6 nupkg into a net8 nupkg,
    producing a single multi-targeted nupkg. For Library projects only.

.DESCRIPTION
    1. Extracts the net8 nupkg to a temp directory.
    2. Reads the net6 nupkg and copies lib/net6* entries into the temp directory.
    3. Patches the nuspec: adds a net6.0-windows7.0 dependency group cloned from
       the net8.0-windows7.0 group (minus System.Activities.ViewModels).
    4. Re-packs the temp directory into OutputPath.
    5. Cleans up the temp directory in a finally block.

.PARAMETER Net8Nupkg
    Full path to the net8-built .nupkg file.

.PARAMETER Net6Nupkg
    Full path to the net6-built .nupkg file.

.PARAMETER OutputPath
    Full path for the merged .nupkg output file.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Net8Nupkg,

        [Parameter(Mandatory)]
        [string]$Net6Nupkg,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    if (-not (Test-Path $Net8Nupkg)) { throw "Net8 nupkg not found: $Net8Nupkg" }
    if (-not (Test-Path $Net6Nupkg)) { throw "Net6 nupkg not found: $Net6Nupkg" }

    if (-not $PSCmdlet.ShouldProcess($OutputPath, 'Merge net6 and net8 TFMs into single nupkg')) { return }

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "uipack-merge-$([guid]::NewGuid().ToString('N').Substring(0,8))"

    try {
        # 1. Extract net8 nupkg
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Net8Nupkg, $tempDir)

        # 2. Copy lib/net6* entries from net6 nupkg
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Net6Nupkg)
        try {
            $net6Entries = $zip.Entries | Where-Object {
                $_.FullName -match '^lib/net6' -and $_.Length -gt 0
            }
            foreach ($entry in $net6Entries) {
                $destPath = Join-Path $tempDir ($entry.FullName -replace '/', '\')
                $destDir  = Split-Path $destPath -Parent
                if (-not (Test-Path $destDir)) {
                    $null = New-Item -ItemType Directory -Path $destDir -Force
                }
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destPath, $true)
            }
            if ($net6Entries) {
                $tfmName = ($net6Entries | Select-Object -First 1).FullName -replace '^lib/([^/]+)/.*', '$1'
                Write-Verbose "[MultiTfm] Merged lib/$tfmName/ ($($net6Entries.Count) files) from net6 build"
            } else {
                Write-Warning "[MultiTfm] net6 nupkg had no lib/net6* entries — merged nupkg will be net8 only"
            }
        } finally {
            $zip.Dispose()
        }

        # 3. Patch nuspec: add net6.0-windows7.0 dependency group
        $nuspecPath = Get-ChildItem -Path $tempDir -Filter '*.nuspec' | Select-Object -First 1 -ExpandProperty FullName
        if ($nuspecPath) {
            [xml]$nuspec = Get-Content $nuspecPath -Raw -Encoding UTF8
            $ns    = $nuspec.DocumentElement.NamespaceURI
            $nsMgr = New-Object System.Xml.XmlNamespaceManager($nuspec.NameTable)
            $nsMgr.AddNamespace('nu', $ns)

            $depsNode = $nuspec.SelectSingleNode('//nu:dependencies', $nsMgr)
            if ($depsNode) {
                $existingNet6 = $depsNode.SelectSingleNode("nu:group[@targetFramework='net6.0-windows7.0']", $nsMgr)
                if (-not $existingNet6) {
                    $net8Group = $depsNode.SelectSingleNode("nu:group[@targetFramework='net8.0-windows7.0']", $nsMgr)
                    if ($net8Group) {
                        $net6Group = $net8Group.CloneNode($true)
                        $net6Group.SetAttribute('targetFramework', 'net6.0-windows7.0')
                        # Remove net8-only dependency
                        $viewModelsDep = $net6Group.SelectSingleNode("nu:dependency[@id='System.Activities.ViewModels']", $nsMgr)
                        if ($viewModelsDep) {
                            $net6Group.RemoveChild($viewModelsDep) | Out-Null
                        }
                        $depsNode.AppendChild($net6Group) | Out-Null

                        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                        $writer    = New-Object System.IO.StreamWriter($nuspecPath, $false, $utf8NoBom)
                        try { $nuspec.Save($writer) } finally { $writer.Close() }
                        Write-Verbose "[MultiTfm] Added net6.0-windows7.0 dependency group to nuspec"
                    }
                }
            }
        }

        # 4. Re-pack into OutputPath
        $null = New-Item -ItemType Directory -Path (Split-Path $OutputPath -Parent) -Force
        if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $tempDir,
            $OutputPath,
            [System.IO.Compression.CompressionLevel]::Optimal,
            $false
        )
        Write-Verbose "[MultiTfm] Created merged nupkg: $(Split-Path $OutputPath -Leaf)"

        Write-Output $OutputPath

    } finally {
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
