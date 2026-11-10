# CLAUDE.md — lukaserlenbach.github.io

Hakyll portfolio site (Haskell, stack). Framework-free by design: no CSS/JS
frameworks, modern CSS3 only. Keep it that way.

## Build & verify

- `stack build` — compile the generator; must be warning-clean.
- `stack run build` — generate the full site into `_site/`; must succeed.
- `stack run watch` — local preview at http://localhost:35730 (interactive only).

A change is only done when both `stack build` and `stack run build` pass.

## Deploy

`./deploy.sh` (agents: `./deploy.sh --yes`) is the one deploy step: refuses a
dirty tree or a branch behind origin, runs `stack build` + Hakyll `build` +
`check --internal-links`, pushes `hakyll`, then follows the Actions run until
the site is live.

- Push auth: the repo belongs to the private account `LukasErlenbach`, while
  gh's active account is the work one (`pnd-lerlenbach`). `deploy.sh` pins this
  clone's `.git/config` to fetch the LukasErlenbach token from gh, so a plain
  `git push` works too. Never `gh auth switch` for this repo.
- A cold CI cache makes the run take ~20 min instead of ~1 (the script says
  so up front). `keep-cache-warm.yml` reads the cache twice a week; GitHub
  disables that schedule after 60 days without a push.

## Structure

- `site.hs` — the Hakyll generator; all routing/compilation rules live here.
- `pages/*` — content pages; each becomes `/<slug>.html`.
- `templates/*` — HTML templates.
- `static/**` — css, js, fonts, images, documents (copied verbatim).

## Hard constraints

- URLs stay **root-relative**; do NOT use `relativizeUrls`. GitHub Pages serves
  404.html under arbitrary paths, so relative URLs would break there.
- Do NOT edit personal prose/content text (bio, project descriptions) unless
  explicitly asked. Mechanical fixes (titles, alt attributes, metadata) are fine.
- Deploys happen automatically when the `hakyll` branch is pushed
  (`.github/workflows/deploy.yml`). Never push to `hakyll` unless the change is
  meant to go live. `publish.sh` is a legacy manual path; do not use it.
- The site has German/English page pairs; when touching one language's page,
  check whether its counterpart needs the same change.
