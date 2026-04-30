# Changelog

## 0.1.0 (unreleased)

Initial Zed extension.

- Tree-sitter grammar wired in via `lex-fmt/tree-sitter-lex@v0.9.1`
- Highlights, injections, textobjects ported from `tree-sitter-lex/queries/`
- `outline.scm`, `brackets.scm`, `indents.scm` written for Zed
- `lex-lsp` (v0.8.8) auto-downloaded from `lex-fmt/lex` releases on first use
- `lsp.lex-lsp.binary.path` setting respected for local LSP overrides
