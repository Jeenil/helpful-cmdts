#!/usr/bin/env bash
# Copies repo markdown into docs/
set -euo pipefail
cd "$(dirname "$0")/.."
copy() { # src dest title
  mkdir -p "$(dirname "docs/$2")"
  { printf -- '---\ntitle: %s\n---\n\n' "$3"; cat "$1"; } > "docs/$2"
}
copy azure-keyvault/keyvault.md keyvault.md "Azure Key Vault"
copy git/gh.md gh.md "GitHub CLI"
copy kubernetes/kubectl.md kubectl.md "kubectl"
copy msft-graph/graph.md graph.md "Microsoft Graph"
copy msft-graph/teams/cmdts.md teams-cmdts.md "Teams commands"
copy msft-graph/teams/webhook-setup.md webhook-setup.md "Teams alert channel + webhook"
