# Lex for Zed

[Lex][lex] document format support for the [Zed editor][zed].

Provides:

- Syntax highlighting via the [tree-sitter-lex][ts-lex] grammar
- Language server (`lex-lsp`): formatting, diagnostics, code actions, outline
- Outline / symbol navigation across sessions and definitions
- Language injection for fenced verbatim blocks (Python, JSON, shell, …)

## Installation

While the extension is unpublished, install it as a dev extension:

1. Clone this repo locally.
2. In Zed, open the command palette and run `zed: install dev extension`.
3. Select the cloned directory.

Zed will compile the WASM and fetch the pinned `tree-sitter-lex` grammar.
The first time a `.lex` file opens, the extension downloads the matching
`lex-lsp` binary from `lex-fmt/lex` releases (see `shared/lex-deps.json`)
and caches it in the extension's working directory.

## Configuration

Override the language server binary in `settings.json`:

```json
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

### Lex Monochrome theme

A 4-tier grayscale syntax-override scheme — same look as the Lex
nvim/vscode plugins, scaled down to what Zed's per-language overrides
can express (color + font weight/style; per-token backgrounds and
underlines are not honoured). Pick the file matching your Zed theme's
appearance and merge it into your `settings.json`:

- [`themes/lex-monochrome.dark.json`](themes/lex-monochrome.dark.json)
- [`themes/lex-monochrome.light.json`](themes/lex-monochrome.light.json)

Each file is shaped as a complete `languages.Lex` block ready to merge.
If you switch between dark and light Zed themes, swap the snippet too —
Zed's `experimental.theme_overrides` doesn't auto-switch on appearance.

The colour table mirrors the canonical 4-tier intensity map shared
across the editor fleet (memory: theme unification project). Editing
the snippet directly fails CI; update `scripts/gen-theme.py` and
re-run.

## Development

Prerequisites: Rust + the WASM target, Node (for `tree-sitter-cli`),
[bats-core][bats], and Python 3.11+.

```sh
rustup target add wasm32-wasip2
brew install bats-core            # macOS; on Linux: apt-get install -y bats
./scripts/test-all                # full check (fmt, clippy, build, manifest, queries)
./scripts/test-all --quick        # skip the query bats suite (no network needed)
```

`scripts/test-all` is the single source of truth for quality checks. The
pre-commit hook and CI both invoke it. To install the hook:

```sh
ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
```

The pre-commit hook runs `--quick` (skips the query bats suite, which
needs either a sibling `tree-sitter-lex` checkout or network access). CI
runs the full thing.

### Running individual tests

The bats suites support `--filter` for fast iteration:

```sh
bats --filter "highlights" test/queries.bats
bats --filter "lexd-lsp" test/manifest.bats
```

### Adding an injection language

`languages/lex/injections.scm` is generated. Edit `LANGUAGES` in
`scripts/gen-injections.py`, run it, and commit the regenerated file.
The bats suite asserts the file matches the generator output.

```sh
python3 scripts/gen-injections.py
```

### Building

`scripts/build` is the single entry point for "compile this extension".
The same script runs locally, in `scripts/test-all`, and in the release
workflow.

```sh
./scripts/build               # release WASM (the only thing that ships)
./scripts/build --debug       # debug profile (faster compile, larger WASM)
./scripts/build --package     # also write zed-lex-<version>.tar.gz
./scripts/build --warm-cache  # also pre-fetch lex-lsp + grammar so first
                              # use of the dev extension is offline
```

Why this differs from vscode/lexed: a Zed extension is a tarball of
source that Zed's Marketplace builds at install time, plus runtime
binary downloads. There is no upload-this-binary step. Bundling
prebuilt binaries into platform-specific packages — the way `vscode`
ships 5 VSIXes — is not how Zed extensions reach users.

`--package` is for sideload / offline install (anyone who wants a
prebuilt extension without going through Marketplace can untar it and
`zed: install dev extension` the result).

### Releases

Releases follow the same pattern as `tree-sitter-lex`, `lex`, and
`nvim`: write release notes in `UNRELEASED.md` as work happens, then
run `scripts/create-release vX.Y.Z` to:

1. Sync the version in `extension.toml` and `Cargo.toml`
2. Prepend the notes to `CHANGELOG.md`
3. Reset `UNRELEASED.md`
4. Re-run `scripts/test-all --quick`
5. Commit, create an annotated tag with the notes, push

The tag push triggers `.github/workflows/release.yml`, which runs the
full `scripts/test-all`, then `scripts/build --package`, and attaches
the resulting `zed-lex-<version>.tar.gz` to the GitHub release with the
tag annotation as the release body.

[bats]: https://github.com/bats-core/bats-core

After editing the extension, reinstall the dev extension in Zed (the
command palette action will rebuild and reload). Logs are surfaced via
`zed: open log` or by relaunching Zed with `zed --foreground`.

## Version pins

`shared/lex-deps.json` is the single source of truth for:

- `lexd-lsp` — the LSP server version downloaded at runtime
- `tree-sitter` — the tree-sitter-lex tag (also encoded as a commit SHA in
  `extension.toml`'s `[grammars.lex] commit` field, since Zed pins grammars
  by SHA)

Bumping the LSP version is a one-file change. Bumping the grammar requires
updating both `lex-deps.json` and the SHA in `extension.toml`.

## Related

- [lex-fmt/lex][lex] — Rust workspace (parser, LSP, CLI)
- [lex-fmt/tree-sitter-lex][ts-lex] — grammar
- [lex-fmt/vscode][vscode] — VS Code extension
- [lex-fmt/nvim][nvim] — Neovim plugin
- [lex-fmt/lexed][lexed] — standalone Electron editor

[lex]: https://github.com/lex-fmt/lex
[ts-lex]: https://github.com/lex-fmt/tree-sitter-lex
[vscode]: https://github.com/lex-fmt/vscode
[nvim]: https://github.com/lex-fmt/nvim
[lexed]: https://github.com/lex-fmt/lexed
[zed]: https://zed.dev
