---
title: How this site is hosted
---

# How this site is hosted

This site is GitHub Pages serving a Jekyll build of the `docs/` folder.
Reference: [About GitHub Pages and Jekyll](https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/about-github-pages-and-jekyll).

## Flow

1. Markdown lives next to the code (`git/gh.md`, `kubernetes/kubectl.md`, ...).
2. `bun run docs` runs `scripts/build-docs.sh`, which copies each file into
   `docs/` and adds front matter (`title`).
3. Commit and push. GitHub Pages runs Jekyll on `docs/` and publishes the
   result at `https://jeenil.github.io/helpful-cmdts/`.

Edit the original files, not the copies in `docs/`. The copies are overwritten
on every run. The exceptions are hand-written pages that exist only in
`docs/` (`index.md`, `gpo-smb-drive-mappings.md`, this page).

## Jekyll basics

- Jekyll turns Markdown and HTML into a static site using layouts. It supports
  Markdown and Liquid templating.
- `docs/_config.yml` holds site settings (`title`, `theme`). Some settings
  (such as `safe: true`) are fixed by GitHub Pages and can't be changed.
- Front matter (the `---` block at the top of a file) sets per-page metadata
  like `title`. Pages without it are only processed if they have front matter
  or `jekyll-optional-front-matter` picks them up.
- Files and folders starting with `_`, `.` or `#`, and `node_modules`, are not
  built unless listed under `include`.
- The theme is `jekyll-theme-cayman`, one of the themes GitHub supports
  out of the box.
- Only GitHub-supported plugins work with the branch-based build. See
  <https://pages.github.com/versions.json>.

## Publishing settings

Settings > Pages > Build and deployment:

- Source: Deploy from a branch
- Branch: `master`, folder `/docs`

GitHub's docs now recommend GitHub Actions for deploying and automating Pages.
Switching later means adding a workflow and changing the source to
"GitHub Actions"; the `docs/` content stays the same.

## Preview locally (optional)

Jekyll isn't officially supported on Windows; use WSL or Linux.

```bash
gem install bundler jekyll
cd docs
jekyll serve
```

Then open <http://localhost:4000>. Local builds can differ from GitHub's.
To match it exactly, use the `github-pages` gem.

## Gotchas

- Free Pages requires a public repository. Everything in `docs/` becomes
  public, including internal server, team and vault names.
- Links between pages use the page name without extension, for example
  `[kubectl](kubectl)`.
- Changes can take a minute or two to appear after a push.
