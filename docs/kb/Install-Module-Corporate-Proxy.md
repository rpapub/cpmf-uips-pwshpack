# Install-Module fails behind a corporate proxy

## Symptom

Running `Install-Module CpmfUipsPack` (or any module from PSGallery) produces:

```
Exception: End of central directory record could not be found.
```

## Cause

A corporate proxy with an interstitial / captive-portal page intercepts the
HTTPS download and returns an HTML page instead of the `.nupkg` file.
PowerShell saves the HTML as-is and then fails when it tries to open it as a
ZIP archive.

## Workarounds

### Option A — Pass proxy credentials to `Install-Module`

```powershell
$cred = Get-Credential   # domain\username + password
Install-Module CpmfUipsPack -Proxy 'http://proxy.corp.example:8080' -ProxyCredential $cred
```

### Option B — Download manually, install from local path

1. On a machine that can reach PSGallery (or via a browser after authenticating
   the proxy interstitial), download the `.nupkg`:
   `https://www.powershellgallery.com/api/v2/package/CpmfUipsPack`

2. Rename it to `.zip`, extract, then install:

```powershell
Save-Module CpmfUipsPack -Path C:\Temp\modules -Proxy 'http://proxy.corp.example:8080'
# — or copy the extracted folder manually —
Copy-Item C:\Temp\modules\CpmfUipsPack -Destination ($env:PSModulePath -split ';')[0] -Recurse
```

### Option C — Register an internal NuGet feed

Publish the module to an internal feed (Azure Artifacts, Nexus, ProGet, etc.)
that is reachable without proxy interception, then point PowerShell at it:

```powershell
Register-PSRepository -Name Internal -SourceLocation 'https://pkgs.dev.azure.com/…' -InstallationPolicy Trusted
Install-Module CpmfUipsPack -Repository Internal
```

## See also

- [PowerShell docs — Install-Module](https://learn.microsoft.com/powershell/module/powershellget/install-module)
- [about_Profiles — PSModulePath](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_psmodulepath)
