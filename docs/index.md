---
title: Home
nav_order: 1
permalink: /
---

# How this site is built

A personal reference for commands used day-to-day. Use the search box or the
sidebar to find a page, and the sun/moon slider to switch between light
and dark. It starts in dark mode, like [sillydodo.net](https://sillydodo.net), and
remembers your choice.

This site is GitHub Pages serving a Jekyll build of the `docs/` folder with the
[Just the Docs](https://just-the-docs.com/) theme. Reference:
[About GitHub Pages and Jekyll](https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/about-github-pages-and-jekyll).

## Flow

1. Markdown lives next to the code (`git/gh.md`, `kubernetes/kubectl.md`, ...).
2. `bun run docs` runs `scripts/build-docs.sh`, which copies each file into
   `docs/` and adds front matter (`title`, `parent`).
3. Commit and push to `master`. The `Deploy docs to GitHub Pages` workflow
   (`.github/workflows/pages.yml`) runs `bun run docs`, builds `docs/` with
   Jekyll, and publishes the result at
   `https://jeenil.github.io/helpful-cmdts/`.

Edit the original files, not the copies in `docs/`. The copies are overwritten
on every run. The exceptions are hand-written pages that exist only in `docs/`:
this page, the section pages (`azure.md`, `git.md`, `kubernetes.md`,
`microsoft.md`, `on-prem.md`) and `gpo-smb-drive-mappings.md`.

## Adding a page

1. Write the markdown next to the code, or directly in `docs/` for a
   docs-only page.
2. For a copied page, add a `copy` line to `scripts/build-docs.sh` with its
   title and the section (`parent`) it belongs under.
3. For a new section, add a section page with `has_children: true` and a
   `nav_order`.

## Jekyll and theme basics

- Jekyll turns Markdown and HTML into a static site using layouts. It supports
  Markdown and Liquid templating.
- `docs/_config.yml` holds site settings (title, theme, search). Some settings
  (such as `safe: true`) are fixed by GitHub Pages and can't be changed.
- Front matter (the `---` block at the top of a file) sets per-page metadata
  like `title`, `parent` and `nav_order`.
- Files and folders starting with `_`, `.` or `#`, and `node_modules`, are not
  built unless listed under `include`.
- The theme comes from `remote_theme` (the `jekyll-remote-theme` plugin, which
  GitHub Pages supports). Search is built in and runs in the browser.
- The light and dark styles are `docs/assets/css/just-the-docs-light.scss` and
  `just-the-docs-dark.scss`. The toggle button lives in
  `docs/_includes/header_custom.html` and is styled in
  `docs/_sass/custom/custom.scss`.
- To change colours, add `docs/_sass/color_schemes/<name>.scss` that overrides
  theme variables and use it in the same way as the dark and light files.

## Publishing settings

Settings > Pages > Build and deployment:

- Source: GitHub Actions

The workflow also runs on demand from the Actions tab (`workflow_dispatch`). The
copies in `docs/` are regenerated in CI, so committing them is optional, but it
keeps the repo browsable without a build.

## Preview locally (optional)

Jekyll isn't officially supported on Windows; use WSL or Linux.

```bash
gem install bundler jekyll
cd docs
jekyll serve
```

Then open <http://localhost:4000/helpful-cmdts/>. Local builds can differ from
GitHub's, and the remote theme needs the `jekyll-remote-theme` gem and network
access.

## Gotchas

- Free Pages requires a public repository. Everything in `docs/` becomes
  public, including internal server, team and vault names.
- Links between pages use the page name without extension, for example
  `[kubectl](kubectl)`.
- Changes can take a minute or two to appear after a push.
