<!-- Release notes for the next version. -->
<!-- Updated as work is done; consumed by scripts/create-release. -->

- Lex Monochrome: 4-tier grayscale syntax overrides, generated from
  `scripts/gen-theme.py` into `themes/lex-monochrome.json`. Ships
  `theme_overrides` for One Dark and One Light keyed by theme name so
  Zed auto-applies the right colours when system appearance flips.
- Earlier per-language `experimental.theme_overrides` form is rejected
  by Zed's settings schema; the supported path is top-level
  `theme_overrides` keyed by theme name. Documented the global-scope
  trade-off in README.
- New bats test (`themes/lex-monochrome.json matches scripts/gen-theme.py`)
  guards drift between the snippet and the generator.
