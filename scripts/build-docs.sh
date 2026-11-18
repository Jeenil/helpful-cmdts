#!/usr/bin/env bash
# Copies repo markdown into docs/ with Jekyll front matter (title and sidebar parent).
set -euo pipefail
cd "$(dirname "$0")/.."
copy() { # src dest title parent
  mkdir -p "$(dirname "docs/$2")"
  { printf -- '---\ntitle: %s\nparent: %s\n---\n\n' "$3" "$4"; cat "$1"; } > "docs/$2"
}
copy azure-keyvault/keyvault.md keyvault.md "Azure Key Vault" "Azure"
copy git/gh.md gh.md "GitHub CLI" "Git"
copy kubernetes/kubectl.md kubectl.md "kubectl" "Kubernetes"
copy msft-graph/graph.md graph.md "Microsoft Graph" "Microsoft"
copy msft-graph/teams/cmdts.md teams-cmdts.md "Teams commands" "Microsoft"
copy msft-graph/teams/webhook-setup.md webhook-setup.md "Teams alert channel + webhook" "Microsoft"
