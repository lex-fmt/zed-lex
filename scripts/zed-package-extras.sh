#!/usr/bin/env bash
# Consumer extras hook for the canonical zed-extension release workflow.
#
# Runs AFTER arthur-debert/release/.github/workflows/zed-extension.yml
# has assembled the standard bundle in $BUNDLE_DIR (extension.toml +
# extension.wasm + Cargo.{toml,lock} + src/ + languages/ + themes/ +
# snippets/ + LICENSE/README/CHANGELOG) and BEFORE the tarball is
# created.
#
# What we add:
#   shared/lex-deps.json — pinned versions for the runtime-downloaded
#   lexd-lsp binary and the tree-sitter-lex grammar tarball. The
#   extension's Rust code reads this at install/first-use time, so it
#   MUST ship in the published bundle. The canonical layout doesn't
#   include `shared/`, so this hook restores it.
#
# Env contract (from the canonical workflow):
#   BUNDLE_DIR      absolute path to the assembled bundle (= $GITHUB_WORKSPACE/dist)
#   EXTENSION_NAME  resolved extension name (e.g. "lex")
#   VERSION         release version (e.g. "0.2.0")
#
# Working dir at hook time is the repo root.

set -euo pipefail

: "${BUNDLE_DIR:?BUNDLE_DIR must be set by the canonical workflow}"

if [ ! -d shared ]; then
    echo "::error::shared/ directory missing at repo root — expected shared/lex-deps.json"
    exit 1
fi

if [ ! -f shared/lex-deps.json ]; then
    echo "::error::shared/lex-deps.json missing — runtime deps pin file"
    exit 1
fi

cp -R shared "${BUNDLE_DIR}/"
echo "Copied shared/ into bundle:"
ls -la "${BUNDLE_DIR}/shared/"
