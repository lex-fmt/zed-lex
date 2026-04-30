# Lex for Zed

[Lex][lex] document format support for the [Zed editor][zed].

Sister extensions: [`lex-fmt/vscode`][vscode] · [`lex-fmt/nvim`][nvim] ·
[`lex-fmt/lexed`][lexed] (standalone editor).

## Features

- **Syntax highlighting** for `.lex` files via the
  [`tree-sitter-lex`][ts-lex] grammar — sessions, definitions, tables,
  inline emphasis, references, the lot.
- **Language server (`lex-lsp`)** for formatting (`cmd-shift-i` or
  format-on-save), diagnostics with quickfixes (e.g. _add missing
  footnote definition_), code actions, and document symbols.
- **Outline / symbol navigation** (`cmd-shift-o`) over the document
  title, sessions, and definitions, with the CST hierarchy preserved
  so subsessions nest correctly.
- **Language injection** for verbatim blocks closed with a recognised
  language annotation — `:: python ::`, `:: json ::`, `:: rust ::`,
  `:: bash ::`, and 9 more. Embedded code highlights in its own
  language. ([Add more.](#adding-an-injection-language))
- **Lex Monochrome theme** — a 4-tier grayscale syntax scheme matching
  the nvim/vscode plugins, scoped to `.lex` files via a dual-tagged
  capture trick so it doesn't bleed into your other languages.

## Installation

Until the extension is published to the Zed Marketplace, install it as
a dev extension:

1. Clone this repo somewhere local.
2. In Zed, open the command palette (`cmd-shift-p`) and run
   `zed: install dev extension`.
3. Pick the cloned directory.

Zed compiles the WASM in place and fetches the pinned `tree-sitter-lex`
grammar (~5–10 s, network). The first time you open a `.lex` file, the
extension downloads the matching `lex-lsp` binary from
[`lex-fmt/lex`][lex] releases and caches it inside the extension's
working directory. Subsequent opens are offline.

To update later: `zed: rebuild dev extension` (or uninstall + reinstall
the dev extension if your Zed build doesn't have the rebuild action).

## Usage

Open any `.lex` file. The status bar should read **Lex** (not Plain
Text). On first open you may briefly see a "Downloading…" hint while
`lex-lsp` is fetched.

| Action | How |
|---|---|
| Format buffer | `cmd-shift-i` (or set `format_on_save` in settings) |
| Outline / symbol picker | `cmd-shift-o` |
| Go to definition | `f12` (works on references and footnote citations) |
| Code actions / quickfixes | `cmd-.` |
| Diagnostics panel | `cmd-shift-m` |

Logs from the extension and LSP show up in `zed: open log`. For
verbose startup logs, launch Zed from a terminal with `zed --foreground`.

## Configuration

### Override the language server binary

Useful when developing `lex-lsp` itself: point Zed at your local build
instead of the auto-downloaded one.

```jsonc
{
  "lsp": {
    "lex-lsp": {
      "binary": {
        "path": "/path/to/your/lex-lsp"
      },
      "initialization_options": {},
      "settings": {}
    }
  }
}
```

Resolution order in the extension's Rust code: this `binary.path` →
`lex-lsp` on `$PATH` → cached download → fresh GitHub download.

### Format on save

```jsonc
{
  "languages": {
    "Lex": {
      "format_on_save": "on"
    }
  }
}
```

## Theme — Lex Monochrome

A four-tier grayscale syntax scheme matching the look of the nvim and
vscode editions. The premise: prose is content, structure is
scaffolding — fade the scaffolding so the prose reads first.

### Intensity hierarchy

| Tier | Light mode | Dark mode | Used for |
|---|---|---|---|
| **normal** | `#000000` | `#e0e0e0` | Headings, prose body, definition subjects, bold/italic, code |
| **muted** | `#808080` | `#888888` | List markers, references, links |
| **faint** | `#b3b3b3` | `#666666` | Annotations (`:: ::`), verbatim metadata, table pipes |
| **faintest** | `#cacaca` | `#555555` | Inline syntax markers (reserved, unused under Zed currently) |

Headings stay bold. Definition subjects and emphasis stay italic.
Strong stays bold. Everything else is colour only — Zed's syntax
overrides don't accept per-token background or text-decoration, so the
code-block background and reference underlines from nvim/vscode don't
carry over here.

### Install

1. Open Zed's `settings.json` (`cmd-,` → "Open Settings JSON" or
   `~/.config/zed/settings.json`).
2. Merge the `theme_overrides` block from
   [`themes/lex-monochrome.json`](themes/lex-monochrome.json) into your
   settings.
3. Save. Zed reloads.

```jsonc
{
  "theme_overrides": {
    "One Dark":  { "syntax": { /* dark intensities */ } },
    "One Light": { "syntax": { /* light intensities */ } }
  }
}
```

When `theme.mode` is `system`, Zed swaps between One Dark and One Light
on macOS appearance change — and the matching override comes with it
automatically. No swap script, no manual flip.

### Lex-only scope

`theme_overrides` is global: a key like `"comment"` would recolour
comments in *every* file in that theme, not just `.lex`. To scope it,
`languages/lex/highlights.scm` dual-tags every overridable capture:

```scheme
(session title: (line_content) @title @title.lex)
```

Zed walks captures right-to-left, using the first one the active theme
has a style for. The shipped override defines `title.lex`, `comment.lex`,
`emphasis.strong.lex`, etc. — only Lex's grammar emits those, so the
override doesn't reach Python, Markdown, or anything else. They keep
their normal theme colours.

If you ever remove the override, the rightmost capture (`title.lex`)
silently misses, the leftward (`title`) hits the base theme, and Lex
files render with the same syntax styling as everything else. Clean
degradation.

### Adding more themes

[`themes/lex-monochrome.json`](themes/lex-monochrome.json) ships
overrides for One Dark and One Light because they're Zed's defaults
and what most "system mode" setups use. To add Ayu, Gruvbox,
Andromeda, etc., edit `THEMES` in
[`scripts/gen-theme.py`](scripts/gen-theme.py) and re-run. The
generator emits the new entries; the bats suite asserts the snippet
matches the generator output, so out-of-sync edits fail CI.

```python
THEMES = {
    "One Dark":          "dark",
    "One Light":         "light",
    "Ayu Dark":          "dark",      # add your theme
    "Gruvbox Dark Hard": "dark",
}
```

### Removing or customising

To turn the override off entirely, delete the `theme_overrides` block
from your settings.json. Lex files immediately fall back to the base
theme's syntax colouring (with the same structural highlighting from
`highlights.scm`).

To customise individual colours without forking, override the specific
keys after the merged block — e.g. to keep monochrome but make
references blue:

```jsonc
"theme_overrides": {
  "One Light": {
    "syntax": {
      // …generated keys…
      "link_text.lex": { "color": "#1a73e8" },
      "link_uri.lex":  { "color": "#1a73e8" }
    }
  }
}
```

## Troubleshooting

**File opens as Plain Text, not Lex.**
Check your file extension is `.lex` (not `.txt` or similar). If it
genuinely is `.lex`, reinstall the dev extension and restart Zed.

**`lex-lsp` doesn't start.**
Open `zed: open log`. The extension logs the binary download attempt
on first launch — watch for asset-name mismatches (your platform may
not have a prebuilt; set `lsp.lex-lsp.binary.path` to a local build).
Or run `zed --foreground` from a terminal to see live logs.

**Highlights look unstyled.**
Most likely the dev extension didn't fully install; check `zed: open log`
for compile errors. Less likely: your active theme is missing styles
for the captures we emit (`@title`, `@comment`, etc.). Switch to One
Dark or One Light to confirm — those are what we test against.

**Theme override is wrong colour after switching macOS to dark mode.**
Confirm both `One Dark` and `One Light` blocks are present in your
`theme_overrides`. If only one is, Zed will style the other with no
override (using the base theme), which can look jarring after Lex
Monochrome.

**`Property experimental.theme_overrides is not allowed`.**
You're using the older form. The supported path is top-level
`theme_overrides` keyed by theme name — see [Theme — Lex Monochrome](#theme--lex-monochrome).

## How it works

Three pieces. The extension itself is the smallest of them.

```
┌────────────────────┐     fetched at install time
│ tree-sitter-lex    │◄─── (extension.toml: grammars.lex.commit)
│  parser + queries  │
└─────────┬──────────┘
          │ structural highlights, injections, outline
          ▼
┌────────────────────┐     downloaded at first use
│ zed-lex (this)     │◄─── (src/lex.rs ↔ shared/lex-deps.json)
│  • WASM extension  │
│  • languages/lex/  │
│  • themes/         │
└─────────┬──────────┘
          │ spawns
          ▼
┌────────────────────┐     formatting, diagnostics, code actions,
│ lex-lsp            │     semantic tokens (override structural
│  Rust LSP server   │     highlights for clients that ask)
└────────────────────┘
```

- `extension.toml` declares the grammar (Git URL + 40-char SHA — Zed
  fetches it) and the LSP server (Zed asks our Rust code for the
  command).
- `src/lex.rs` is a Rust → WASM shim. On first `.lex` open it
  resolves the `lex-lsp` binary (settings → `$PATH` → cache → fresh
  GitHub download), returning a `Command` for Zed to spawn. ~210
  lines.
- `languages/lex/*.scm` are the queries Zed runs against the parse
  tree: `highlights.scm` (dual-tagged for theme scoping),
  `injections.scm` (generated, 13 languages × 6 content types),
  `outline.scm`, `textobjects.scm`, `brackets.scm`, `indents.scm`.
- `shared/lex-deps.json` pins the runtime versions
  (`lexd-lsp: vX.Y.Z`, `tree-sitter: vX.Y.Z`). The Rust code reads it
  via `include_str!()` at WASM compile time.

## Version pins

`shared/lex-deps.json` is the single source of truth for the runtime
versions:

- `lexd-lsp` — the LSP server tag downloaded from `lex-fmt/lex`.
- `tree-sitter` — the `tree-sitter-lex` tag. The 40-char SHA for that
  tag also lives in `extension.toml`'s `[grammars.lex] commit` (Zed
  pins grammars by SHA, not tag).

Bumping the LSP version is a one-file change. Bumping the grammar
needs both `lex-deps.json` and the SHA in `extension.toml`.

## Development

Prerequisites: Rust + the WASM target, Node (for `tree-sitter-cli`),
[bats-core][bats], and Python 3.11+.

```sh
rustup target add wasm32-wasip2
brew install bats-core            # macOS; on Linux: apt-get install -y bats
./scripts/test-all                # full check (fmt, clippy, build, manifest, queries)
./scripts/test-all --quick        # skip the query bats suite (no network needed)
```

`scripts/test-all` is the single source of truth for quality checks.
Pre-commit hook and CI both invoke it. Install the hook:

```sh
ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
```

The hook runs `--quick` (skips query bats — needs sibling
`tree-sitter-lex` checkout or network); CI runs the full thing.

After editing extension code or queries, reinstall the dev extension
in Zed (or run `zed: rebuild dev extension`). Logs in `zed: open log`
or via `zed --foreground`.

### Running individual tests

```sh
bats --filter "highlights" test/queries.bats
bats --filter "lexd-lsp"   test/manifest.bats
```

### Adding an injection language

`languages/lex/injections.scm` is generated. Edit `LANGUAGES` in
[`scripts/gen-injections.py`](scripts/gen-injections.py) and re-run.
The bats suite asserts the file matches generator output, so
hand-edits to the .scm file fail CI.

```sh
python3 scripts/gen-injections.py
```

### Adding / customising themes

Edit `THEMES` or `SYNTAX_OVERRIDES` in
[`scripts/gen-theme.py`](scripts/gen-theme.py) and re-run.
`themes/lex-monochrome.json` regenerates; the bats sync test runs on
every commit.

### Building

```sh
./scripts/build               # release WASM (the only thing that ships)
./scripts/build --debug       # debug profile (faster compile)
./scripts/build --package     # also write zed-lex-<version>.tar.gz
./scripts/build --warm-cache  # also pre-fetch lex-lsp + grammar so the
                              # next dev-extension install is offline
```

Zed extensions don't ship binaries the way vscode VSIXes do — the
published artifact is just the WASM, and `lex-lsp` is downloaded by
the extension's own code at runtime via Zed's sandboxed `download_file`
API. So "bundling" in the vscode sense doesn't apply here. `--package`
exists for sideload / offline install, not as the primary
distribution path.

### Releases

Same pattern as `tree-sitter-lex`, `lex`, `nvim`. Write release notes
in `UNRELEASED.md` as work happens, then:

```sh
./scripts/create-release v0.2.0
```

That syncs the version in `extension.toml` and `Cargo.toml`, prepends
the notes to `CHANGELOG.md`, resets `UNRELEASED.md`, re-runs
`scripts/test-all --quick`, and creates an annotated tag with the
notes. The tag push triggers `.github/workflows/release.yml`, which
runs the full test suite, builds `zed-lex-<version>.tar.gz` via
`scripts/build --package`, and attaches it to the GitHub release with
the tag annotation as the body.

## Related

- [`lex-fmt/lex`][lex] — Rust workspace (parser, LSP, CLI)
- [`lex-fmt/tree-sitter-lex`][ts-lex] — grammar
- [`lex-fmt/vscode`][vscode] — VS Code extension
- [`lex-fmt/nvim`][nvim] — Neovim plugin
- [`lex-fmt/lexed`][lexed] — standalone Electron editor

## License

MIT — see [LICENSE](LICENSE).

[lex]: https://github.com/lex-fmt/lex
[ts-lex]: https://github.com/lex-fmt/tree-sitter-lex
[vscode]: https://github.com/lex-fmt/vscode
[nvim]: https://github.com/lex-fmt/nvim
[lexed]: https://github.com/lex-fmt/lexed
[zed]: https://zed.dev
[bats]: https://github.com/bats-core/bats-core
