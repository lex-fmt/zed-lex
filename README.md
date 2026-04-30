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

## Development

```sh
rustup target add wasm32-wasip2
./scripts/test-all              # full check (fmt, clippy, build, manifest, queries)
./scripts/test-all --quick      # skip the query smoke test (no network needed)
```

`scripts/test-all` is the single source of truth for quality checks. The
pre-commit hook and CI both invoke it. To install the hook:

```sh
ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
```

The pre-commit hook runs `--quick` (skips the query smoke test, which
needs either a sibling `tree-sitter-lex` checkout or network access). CI
runs the full thing.

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
