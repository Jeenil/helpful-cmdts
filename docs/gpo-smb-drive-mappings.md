---
title: On-prem GPOs for SMB share mappings
parent: On-prem
---

# On-prem GPOs for SMB share mappings

How to find and export the on-prem Group Policy Objects that map SMB shares
(drive maps) so they can be reviewed or migrated.

Run on a domain-joined machine with RSAT (GroupPolicy module) as an account
with read access to GPOs.

```powershell
Import-Module GroupPolicy
```

## 1. Export every GPO as XML

```powershell
$out = 'C:\Temp\gpo-reports'
New-Item -ItemType Directory -Force $out | Out-Null
Get-GPO -All | ForEach-Object {
    Get-GPOReport -Guid $_.Id -ReportType Xml -Path "$out\$($_.DisplayName -replace '[\\/:*?""<>|]','_').xml"
}
```

## 2. Find GPOs that contain drive maps

Drive maps live under User Configuration > Preferences > Windows Settings >
Drive Maps (`Drives.xml` in SYSVOL).

```powershell
$domain = (Get-ADDomain).DNSRoot
Get-ChildItem "\\$domain\SYSVOL\$domain\Policies" -Recurse -Filter Drives.xml |
    ForEach-Object {
        $guid = ($_.FullName -split '\\')[6].Trim('{}')
        [xml]$x = Get-Content $_.FullName
        foreach ($d in $x.Drives.Drive) {
            [pscustomobject]@{
                GPO      = (Get-GPO -Guid $guid).DisplayName
                Letter   = $d.Properties.letter
                Path     = $d.Properties.path
                Label    = $d.Properties.label
                Action   = $d.Properties.action
                Filter   = $d.Filters.OuterXml -ne $null
            }
        }
    } | Export-Csv C:\Temp\gpo-drive-maps.csv -NoTypeInformation
```

## 3. Find where each GPO is linked

```powershell
Get-GPO -All | ForEach-Object {
    [xml]$r = Get-GPOReport -Guid $_.Id -ReportType Xml
    [pscustomobject]@{
        GPO   = $_.DisplayName
        Links = ($r.GPO.LinkedTo.SOMPath) -join '; '
    }
} | Where-Object Links
```

## 4. Other places SMB mappings hide

- Logon scripts (`net use`, `New-PSDrive`) under User Configuration >
  Policies > Windows Settings > Scripts.
- Security filtering and item-level targeting that limit who gets the map.
- `Get-GPOReport` XML: search for `\\server\share` patterns.

```powershell
Select-String -Path C:\Temp\gpo-reports\*.xml -Pattern '\\\\[\w.-]+\\[\w$.-]+' |
    Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value -Unique
```

## Notes

- Read-only: none of these commands change GPOs.
- Do not commit exported reports; they can expose internal server and share
  names.
