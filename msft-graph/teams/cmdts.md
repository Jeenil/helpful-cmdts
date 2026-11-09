# Microsoft Teams Commands

Find the teams and channels that can receive monitoring alerts.

## Teams PowerShell module

`Get-Team` only lists teams the signed-in account is a member of. Sign in with
your normal account, not an admin or `az` account, which is usually in no teams.

```powershell
Install-Module MicrosoftTeams -Scope CurrentUser
Connect-MicrosoftTeams -AccountId <you>@<domain>

# Every team you belong to
Get-Team | Sort-Object DisplayName | Select-Object DisplayName, GroupId

# Channels in one team
$team = Get-Team -DisplayName 'Infrastructure and Security Monitoring'
Get-TeamChannel -GroupId $team.GroupId | Select-Object DisplayName, MembershipType
```

Pick channels by severity, for example one Critical and one Warning channel for
the environment, then create one Workflows webhook in each.

## Azure CLI and Microsoft Graph

Alternative if the Teams module is unavailable. Needs `az login` with your
normal account and a Graph token with `Team.ReadBasic.All` and
`Channel.ReadBasic.All`.

```powershell
$teams = az rest --method get --url "https://graph.microsoft.com/v1.0/me/joinedTeams" --query "value[].{name:displayName,id:id}" -o json | ConvertFrom-Json
$teams | ForEach-Object {
  $t = $_
  az rest --method get --url "https://graph.microsoft.com/v1.0/teams/$($t.id)/channels" --query "value[].displayName" -o tsv |
    ForEach-Object { "$($t.name) / $_" }
}
```

## Graph with Microsoft.Graph (all teams, no module bug)

```powershell
Connect-MgGraph -Scopes Group.Read.All, Channel.ReadBasic.All -NoWelcome

$teams = Get-MgGroup -All -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -Property Id,DisplayName
$rows = $teams | Sort-Object DisplayName | ForEach-Object {
  $t = $_
  try {
    Get-MgTeamChannel -TeamId $t.Id -ErrorAction Stop | ForEach-Object {
      [pscustomobject]@{ Team = $t.DisplayName; Channel = $_.DisplayName; Type = $_.MembershipType }
    }
  } catch { Write-Warning "skipped $($t.DisplayName): $($_.Exception.Message)" }
}
$rows | Export-Csv "$env:TEMP\teams-channels-all.csv" -NoTypeInformation
```

Listing every team needs consent for `Group.Read.All`. Without it, use
`Get-MgUserJoinedTeam -UserId <you>` for your own teams.

## Create a channel

You must own the team, or hold a role that can create channels. Sign in again
after activating a role, because role changes only appear in a new token.

```powershell
Connect-MgGraph -Scopes Channel.Create -NoWelcome
$teamId = (Get-MgGroup -Filter "displayName eq '<team name>'").Id
New-MgTeamChannel -TeamId $teamId -DisplayName '<channel name>' -Description '<purpose>' -MembershipType standard
```

## Webhooks

Graph cannot create the webhook, because it belongs to Power Automate. Teams does
not list webhook URLs. Create one per channel in Teams:
channel menu, Workflows, "Post to a channel when a webhook request is received".
Store the URL in Key Vault, see `azure-keyvault/keyvault.md`.
