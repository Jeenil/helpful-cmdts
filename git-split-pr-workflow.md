# Git — Split PR Workflow & Branch Cleanup

Patterns for working with stacked/split PRs, resolving committed conflict
markers, cleaning commit history, and running Pester tests locally.

---

## PR merge order when branches depend on each other

If PR B targets PR A's branch as its base, merge A first.

```
gh pr list   # confirm base branches
```

After A merges into master, change PR B's base to master, then rebase:

```bash
git rebase origin/master
git push --force-with-lease
```

---

## Rebase onto the correct base branch

Running `grbm` (rebase onto master) does NOT fix conflicts when the PR
targets a different feature branch. Rebase onto the actual target:

```bash
git rebase origin/feat/policy-validation
git push --force-with-lease
```

---

## Finding committed merge conflict markers

If conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) were accidentally
committed, tests will fail to parse entirely.

```bash
grep -rn "<<<<<<\|=======\|>>>>>>>" ./EntraVacuum ./Tests
```

Resolve by picking the correct side, then commit and push normally.

---

## Running Pester tests locally in CI mode

Matches exactly what GitHub Actions runs:

```powershell
Invoke-Pester ./Tests -CI
```

Pester's `-CI` flag sets `$ErrorActionPreference = 'Stop'`, which causes
`Write-Error` to throw a terminating exception instead of writing to the
error stream.

---

## Testing Write-Error in Pester CI mode

`2>&1` does not capture `Write-Error` when `ErrorActionPreference = Stop`
because the error throws before reaching the stream redirect.

**Wrong:**
```powershell
$result = My-Function ... 2>&1
$result | Should -Not -BeNullOrEmpty
```

**Right — use `-ErrorVariable`:**
```powershell
$null = My-Function ... -ErrorAction SilentlyContinue -ErrorVariable testErrors
$testErrors | Should -Not -BeNullOrEmpty
```

`-ErrorAction SilentlyContinue` overrides the global Stop preference and
captures the error in `$testErrors` for assertion.

---

## Strip a line from recent commit messages (e.g. Co-Authored-By)

```bash
git filter-branch -f --msg-filter 'grep -v "Co-Authored-By"' HEAD~N..HEAD
git push --force-with-lease
```

Replace `N` with how many commits back to rewrite. This rewrites SHAs,
so only use on branches not shared with others.

---

## Delete merged branches after PRs land

```bash
# Find what's merged
git branch -r --merged origin/master

# Delete remote branches
git push origin --delete branch-name-1 branch-name-2

# Delete local branches (use -D if git thinks they're unmerged due to squash merge)
git branch -D branch-name-1 branch-name-2

# Prune stale remote-tracking refs
git fetch --prune
```
