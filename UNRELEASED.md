<!-- Release notes for the next version. -->
<!-- Updated as work is done; consumed by scripts/create-release. -->

- Lex Monochrome: 4-tier grayscale syntax overrides, generated from
  `scripts/gen-theme.py` into `themes/lex-monochrome.json`. Ships
  `theme_overrides` for One Dark and One Light keyed by theme name so
  Zed auto-applies the right colours when system appearance flips.
- Lex-only scope via dual-tagged captures in `languages/lex/highlights.scm`:
  every overridable capture is emitted as `@x @x.lex`. Zed picks the
  rightmost first, so theme_overrides keyed on `title.lex` / `comment.lex`
  etc. only reach Lex files; other languages keep their base styling.
  (Earlier per-language `experimental.theme_overrides` form is rejected
  by Zed's settings schema; the supported path is top-level
  `theme_overrides` keyed by theme name, hence this dual-capture trick.)
- New bats tests guard the dual-tagging regression and the
  `gen-theme.py` ↔ `themes/lex-monochrome.json` sync.
