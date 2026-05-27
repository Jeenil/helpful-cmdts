# Graph API opens up the door to a lot of MSFT Endpoints

```powershell
$pkg = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/accessPackages?`$filter=displayName eq 'brand-identity-v2-owners'" -Method GET).value[0].id
$uri = "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/accessPackages/$pkg/resourceRoleScopes?`$expand=role,scope"
(Invoke-MgGraphRequest -Uri $uri -Method GET).value | Select-Object @{n="Site";e={$_.scope.originId.Split("/")[-1]}}, @{n="Role";e={$_.role.displayName}} | Sort-Object Site
```
