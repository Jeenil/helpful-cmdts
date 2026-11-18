# helpful-cmdts

A personal reference for commands used day-to-day.

Browse it as a site: <https://jeenil.github.io/helpful-cmdts/>

## Contents

- [Azure Key Vault](azure-keyvault/keyvault.md)
- [GitHub CLI (gh)](git/gh.md) ([manual](https://cli.github.com/manual/))
- [kubectl + Flux](kubernetes/kubectl.md)
  ([quick reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/))
- [Microsoft Graph](msft-graph/graph.md)
- [Microsoft Teams commands](msft-graph/teams/cmdts.md)
- [Teams alert channel + webhook](msft-graph/teams/webhook-setup.md)
- [On-prem GPOs for SMB share mappings](docs/gpo-smb-drive-mappings.md)

## Development

```bash
bun install
bun run lint
bun docs
```

`bun docs` copies the markdown above into `docs/` for the Pages site. The home
page, the section pages and `docs/gpo-smb-drive-mappings.md` are written
directly in `docs/`. See [how this site is built](docs/index.md).
