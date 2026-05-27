# GitHub CLI (gh) Commands

> **Docs:** [GitHub CLI reference](https://cli.github.com/manual/)

---

## Auth

```bash
# Add a new OAuth scope (e.g. when a command says you're missing a scope)
gh auth refresh -h github.com -s delete_repo
```

> Required before `gh repo delete` the default token doesn't include this scope.

---

## Repos

```bash
# Delete a repo (requires delete_repo scope see Auth above)
gh repo delete <owner>/<repo> --yes

# Create a new public repo (empty no README, license, or .gitignore)
gh repo create <owner>/<repo> --public --description "your description"
```

> Recreating a repo with the same name and then pushing the same tags is enough
> for the Terraform Registry to retain all module versions automatically.

---

## Pull Requests

```bash
# List all PRs including merged and closed
gh pr list --state all

# Inspect the full commit messages of every commit in a PR
# Useful for checking Co-Authored-By lines or verifying squash behaviour
gh pr view <number> --json commits --jq '.commits[] | {oid: .oid, headline: .messageHeadline, body: .messageBody}'
```

## Branch Rulesets

> **Docs:** [GitHub Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)

```bash
# List existing rulesets on a repo
gh api repos/<owner>/<repo>/rulesets --jq '.[] | {id, name}'

# Get full details of a specific ruleset
gh api repos/<owner>/<repo>/rulesets/<id>

# Create a ruleset require PR + squash only + block force push/delete + required CI checks
gh api repos/<owner>/<repo>/rulesets \
  --method POST \
  --input - <<'EOF'
{
  "name": "main-ci-checks",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "required_reviewers": [],
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          { "context": "<job-name>", "integration_id": 15368 }
        ]
      }
    }
  ],
  "bypass_actors": []
}
EOF

# Update an existing ruleset (same body, use PUT with the ruleset ID)
gh api repos/<owner>/<repo>/rulesets/<id> \
  --method PUT \
  --input - <<'EOF'
{ ... }
EOF
```

> `integration_id: 15368` is the GitHub Actions app ID use it for any job
> name that comes from a `.github/workflows/*.yml` file.
>
> Only require status checks that run on **every** PR (not path-conditional ones)
> a required check that doesn't trigger will block the PR indefinitely.

---

## Git Refs

```bash
# Inspect all remote refs including PR branch heads and tags
# Useful for checking what commits GitHub is tracking beyond main
git ls-remote origin
```

> PR branch refs (`refs/pull/N/head`) are GitHub-managed and cannot be deleted
> or rewritten by pushing. Any `Co-Authored-By:` in those commits will persist
> on the PR page permanently the only fix is to delete and recreate the repo.
