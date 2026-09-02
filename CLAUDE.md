# CLAUDE.md — lukaserlenbach.github.io

Hakyll portfolio site (Haskell, stack). Framework-free by design: no CSS/JS
frameworks, modern CSS3 only. Keep it that way.

## Build & verify

- `stack build` — compile the generator; must be warning-clean.
- `stack run build` — generate the full site into `_site/`; must succeed.
- `stack run watch` — local preview at http://localhost:35730 (interactive only).

A change is only done when both `stack build` and `stack run build` pass.

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
