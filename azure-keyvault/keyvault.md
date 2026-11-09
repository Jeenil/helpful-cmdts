# Azure Key Vault Commands

Each command has a PowerShell and a Bash version. Set the vault name first.

PowerShell:

```powershell
$vault = '<vault-name>'
```

Bash:

```bash
vault='<vault-name>'
```

## Find secrets

Names only, never values.

PowerShell:

```powershell
az keyvault secret list --vault-name $vault --query "[?contains(name,'teams') || contains(name,'webhook')].name" -o tsv
```

Bash:

```bash
az keyvault secret list --vault-name "$vault" --query "[?contains(name,'teams') || contains(name,'webhook')].name" -o tsv
```

## Store a Teams webhook

PowerShell:

```powershell
$url = Read-Host -AsSecureString 'Webhook URL' | ConvertFrom-SecureString -AsPlainText
az keyvault secret set --vault-name $vault --name teams-webhook-<channel>-alerts --value $url --output none
```

Bash:

```bash
read -rs -p 'Webhook URL: ' url; echo
az keyvault secret set --vault-name "$vault" --name teams-webhook-<channel>-alerts --value "$url" --output none
```

## Test a stored webhook

This posts a real message to the channel, so warn the channel first.

PowerShell:

```powershell
$u = az keyvault secret show --vault-name $vault --name teams-webhook-<channel>-alerts --query value -o tsv
Invoke-RestMethod -Method Post -Uri $u -ContentType 'application/json' -Body '{"text":"Webhook test"}'
```

Bash:

```bash
u=$(az keyvault secret show --vault-name "$vault" --name teams-webhook-<channel>-alerts --query value -o tsv)
curl -sS -X POST "$u" -H 'Content-Type: application/json' -d '{"text":"Webhook test"}'
```
