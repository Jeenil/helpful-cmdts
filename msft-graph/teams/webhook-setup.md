# Teams alert channel + webhook (Azure Files storage alerts)

How the `Azure-Storage-Alerts` channel and its webhook were set up and tested.
Never paste the webhook URL in chat, tickets, or shell history.

## 1. Create the channel (Graph)

Sign in with the normal account (not the `az` admin account).

```powershell
Connect-MgGraph -Scopes 'Channel.Create'
$teamId = (Get-MgGroup -Filter "displayName eq 'Infrastructure and Security Monitoring'").Id
New-MgTeamChannel -TeamId $teamId -DisplayName 'Azure-Storage-Alerts' -Description 'Azure Files storage alerts (prod)' -MembershipType standard
```

Standard matches the other Azure alert channels.

## 2. Create the webhook (Teams UI only)

Graph cannot create a Workflows webhook.

1. Channel, then **Workflows**, then the template "Send webhook alerts to a channel".
2. Pick the team and channel, then **Add workflow**.
3. **Copy webhook link**.

## 3. Store the URL in Key Vault

Paste into the hidden prompt, then strip control characters. A bad paste (doubled
or with a stray control character) causes `401 AuthorizationFailed` or
`curl: (3) URL rejected`.

```bash
read -rsp "Paste webhook URL: " url; echo
url=$(printf '%s' "$url" | tr -d '[:cntrl:]')
echo "len=${#url}"
az keyvault secret set --vault-name lh-kv-lappsext-eus-prod --name teams-webhook-azure-storage-alerts --value "$url" --query name -o tsv
```

Do not delete and recreate the secret. Soft-delete reserves the name, and
`secret set` on an existing name just adds a new version.

## 4. Test

Read it back and post a card (expect `202`):

```bash
url=$(az keyvault secret show --vault-name lh-kv-lappsext-eus-prod --name teams-webhook-azure-storage-alerts --query value -o tsv | tr -d '[:cntrl:]')
curl -sS -o /dev/null -w "%{http_code}\n" -X POST "$url" -H 'Content-Type: application/json' -d '{"type":"message","attachments":[{"contentType":"application/vnd.microsoft.card.adaptive","content":{"type":"AdaptiveCard","version":"1.4","body":[{"type":"TextBlock","text":"test"}]}}]}'
```

Simulate what Azure Monitor sends (common alert schema):

```bash
curl -sS -o /dev/null -w "%{http_code}\n" -X POST "$url" -H 'Content-Type: application/json' -d '{"schemaId":"azureMonitorCommonAlertSchema","data":{"essentials":{"alertRule":"test-rule","severity":"Sev2","monitorCondition":"Fired","firedDateTime":"2026-01-01T00:00:00Z","alertTargetIDs":["/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/rg/providers/microsoft.storage/storageaccounts/acct/fileservices/default"],"description":"test"}}}'
```

`202` only means Power Automate accepted the request. Confirm the message in the
channel and check the workflow **Run history** for failed steps.

## 5. Make the workflow render Azure Monitor alerts

The template only posts requests that carry an Adaptive Card in `attachments`.
Azure Monitor sends the common alert schema instead, so by default nothing is
posted even though the webhook returns `202`.

Edit the workflow in Power Automate (make.powerautomate.com, My flows; the
Teams editor is too limited). In the "Attachments is null" condition, open
"Post card in a chat or channel 1" in the True branch and set its Adaptive Card
to a card built from `triggerBody()?['data']?['essentials']` (alertRule,
monitorCondition, severity, firedDateTime, alertTargetIDs, description).
Re-run the simulated Azure Monitor curl to confirm the card renders.

Build the text values defensively, because the card is assembled as a string
and a raw array, quote, or line break makes it invalid JSON ("message body is
invalid JSON"):

- `alertTargetIDs` is an array. Use
  `split(first(triggerBody()?['data']?['essentials']?['alertTargetIDs']), '/')?[8]`
  for the storage account name.
- The file share is a metric dimension. Use
  `coalesce(triggerBody()?['data']?['alertContext']?['condition']?['allOf']?[0]?['dimensions']?[0]?['value'], 'all')`.
- Wrap `description` in `replace` calls to strip double quotes and newlines.
- Every element in the card `body` needs a `type`; facts belong inside the
  `FactSet` `facts` array. Otherwise Teams rejects the card ("Required property
  'type' not found").

Full card used in the True branch:

```json
{
  "type": "AdaptiveCard",
  "version": "1.4",
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "body": [
    {
      "type": "TextBlock",
      "weight": "Bolder",
      "size": "Medium",
      "wrap": true,
      "text": "@{triggerBody()?['data']?['essentials']?['monitorCondition']}: @{triggerBody()?['data']?['essentials']?['alertRule']}"
    },
    {
      "type": "FactSet",
      "facts": [
        {
          "title": "Severity",
          "value": "@{triggerBody()?['data']?['essentials']?['severity']}"
        },
        {
          "title": "Fired",
          "value": "@{triggerBody()?['data']?['essentials']?['firedDateTime']}"
        },
        {
          "title": "Target",
          "value": "@{split(first(triggerBody()?['data']?['essentials']?['alertTargetIDs']), '/')?[8]}"
        },
        {
          "title": "Share",
          "value": "@{coalesce(triggerBody()?['data']?['alertContext']?['condition']?['allOf']?[0]?['dimensions']?[0]?['value'], 'all')}"
        },
        {
          "title": "Suggested quota",
          "value": "@{if(contains(triggerBody()?['data']?['essentials']?['alertRule'], 'capacity'), concat(string(mul(int(formatNumber(add(div(float(triggerBody()?['data']?['alertContext']?['condition']?['allOf']?[0]?['metricValue']), 429496729600), 0.4999), '0')), 500)), ' GiB (80% used)'), 'n/a')}"
        }
      ]
    },
    {
      "type": "TextBlock",
      "wrap": true,
      "text": "@{replace(replace(coalesce(triggerBody()?['data']?['essentials']?['description'], ''), '\"', ''''), decodeUriComponent('%0A'), ' ')}"
    }
  ]
}
```

The suggested quota is the current usage (`metricValue`, bytes) divided by the
bytes in 0.8 GiB, rounded up to the next 500 GiB with `formatNumber` (`int`
fails on fractional values). It only applies to capacity
alerts. Applying it means changing the share quota in Terraform.

A curl test must include `alertTargetIDs` and `firedDateTime`; the minimal
payload hides these failures. To replay a real alert, use Resubmit on a run in
the workflow Run history.

## Troubleshooting

| Symptom                                                                      | Cause                                                                          |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `401 AuthorizationFailed`                                                    | URL is truncated, doubled, or has stray characters. Re-copy and re-store       |
| `curl: (3) URL rejected`                                                     | Control character in the URL. Strip with `tr -d '[:cntrl:]'`                   |
| `AuthorizationFailed` on `az monitor action-group test-notifications create` | The admin account lacks `createNotifications`. Use the curl simulation instead |

## Terraform

`alerts.tf` in `infrastructure-prod-sub-eus/storage-account/modules` reads
`teams-webhook-azure-storage-alerts` and passes it to the `storage-file-alerts`
module as the `storage` channel.
