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
Drive Maps. Read them through `Get-GPOReport` (AD permissions) rather than
crawling `Drives.xml` in SYSVOL, which fails with "Access denied" on GPOs whose
folder ACL excludes your account.

```powershell
$d = 'corp.logixhealth.local'   # variables do not carry over between sessions
$out = Get-GPO -All -Domain $d | ForEach-Object {
    $gpo = $_
    [xml]$x = Get-GPOReport -Guid $gpo.Id -Domain $d -ReportType Xml
    foreach ($dr in $x.GPO.User.ExtensionData.Extension.DriveMapSettings.Drive) {
        [pscustomobject]@{
            GPO    = $gpo.DisplayName
            Letter = $dr.Properties.letter
            Path   = $dr.Properties.path
            Label  = $dr.Properties.label
            Action = $dr.Properties.action   # C=Create U=Update R=Replace D=Delete
            Filter = ($dr.Filters.InnerText -join '; ')   # item-level targeting
        }
    }
}
$out | Sort GPO, Letter | Format-Table -AutoSize
$out | Export-Csv C:\_IT\DATA\drive_maps_actions.csv -NoTypeInformation
```

Pull a single GPO:

```powershell
[xml]$x = Get-GPOReport -Name 'User - Mapped_Drives' -Domain $d -ReportType Xml
$x.GPO.User.ExtensionData.Extension.DriveMapSettings.Drive
```

`Action` `D` entries only remove a drive; do not recreate them elsewhere.

## 3. Check status, links and who it applies to

Run for the GPOs found above. Shows whether the GPO is enabled, where it is
linked (the OU level), whether the link is enabled or enforced, and the security
filtering.

```powershell
$names = 'Mapped_Drives|Drive_Mapping|QuickBooksDrive'
$rows = Get-GPO -All -Domain $d | Where DisplayName -match $names | ForEach-Object {
    $gpo = $_
    [xml]$x = Get-GPOReport -Guid $gpo.Id -Domain $d -ReportType Xml
    $apply = (Get-GPPermission -Guid $gpo.Id -All -Domain $d |
              Where Permission -eq GpoApply | ForEach-Object { $_.Trustee.Name }) -join '; '
    $links = @($x.GPO.LinksTo); if (-not $links) { $links = @($null) }
    foreach ($l in $links) {
        [pscustomobject]@{
            GPO         = $gpo.DisplayName
            GpoStatus   = $gpo.GpoStatus     # AllSettingsEnabled / UserSettingsDisabled / AllSettingsDisabled
            UserEnabled = $x.GPO.User.Enabled
            LinkedTo    = $l.SOMPath         # empty = not linked anywhere
            LinkEnabled = $l.Enabled
            Enforced    = $l.NoOverride
            AppliesTo   = $apply             # security filtering
            WmiFilter   = $gpo.WmiFilter.Name
        }
    }
}
$rows | Sort GPO, LinkedTo | Format-Table -AutoSize -Wrap
```

Also check loopback policy (`Computer - Loopback_Merge/Replace_User_Policy`) on
the linked OUs, since it changes which user GPOs apply on shared machines such
as Citrix and AVD.

## 4. Other places SMB mappings hide

- Logon scripts (`net use`, `New-PSDrive`) under User Configuration >
  Policies > Windows Settings > Scripts.
- Security filtering and item-level targeting that limit who gets the map.
- `Get-GPOReport` XML: search for `\\server\share` patterns.

```powershell
Select-String -Path C:\Temp\gpo-reports\*.xml -Pattern '\\\\[\w.-]+\\[\w$.-]+' |
    Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value -Unique
```

## Troubleshooting

- `The specified domain either does not exist or could not be contacted`: run in
  a session logged on to the domain (`nltest /dsgetdc:<domain>` should return a
  DC), or pass `-Domain <fqdn>`.
- `Get-GPO` prompts for `Guid`: use `Get-GPO -All`, not `Get-GPO *`.
- `Access ... is denied` on a SYSVOL policy folder: `Get-GPO` uses AD
  permissions, SYSVOL has a separate NTFS ACL. Use `Get-GPOReport`, or an
  account with SYSVOL read.
- `-Domain` empty or bound twice: set `$d` in the current session first.

## Notes

- Read-only: none of these commands change GPOs.
- Do not commit exported reports; they can expose internal server and share
  names.
