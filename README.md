# WhoNeedsFrameworks for Hakyll

This theme is a fork of [benedikt-mayer.github.io](https://github.com/benedikt-mayer/benedikt-mayer.github.io) of Benedikt Mayer which is a fork of [CleanMagicMedium-Hakyll](https://github.com/katychuang/CleanMagic-hakyll) of Dr. Katherine Chuang which is a fork of [CleanMagicMedium-Jekyll](https://github.com/SpaceG/CleanMagicMedium-Jekyll) originally published by Lucas Gatsas.

It works completely without any CSS or JavaScript frameworks while retaining responsiveness by using modern CSS3. This reduces page size and thus load times significantly and cleans up the code base.

For installation instructions visit [CleanMagicMedium-Hakyll](https://github.com/katychuang/CleanMagic-hakyll).

Install hakyll `curl -sSL https://get.haskellstack.org/ | sh`.

To test locally, run `stack run watch` and open http://localhost:35730.

## Publishing

Pushing to the `hakyll` branch triggers `.github/workflows/deploy.yml`, which builds the
site with Stack on CI and publishes `_site/` to GitHub Pages. No local build is needed to
deploy. The repository's Pages source must be set to "GitHub Actions" (Settings → Pages).

`publish.sh` is the old manual path (local build, rsync into the `master` branch). It is
kept only as a fallback until the Actions deploy is confirmed working, then it and the
`master` branch can go.
