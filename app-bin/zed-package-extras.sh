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
#   shared/lex-deps.json — the pinned version of the runtime-downloaded
#   lexd-lsp binary. The extension's Rust code reads this at install/
#   first-use time, so it MUST ship in the published bundle. The
#   canonical layout doesn't include `shared/`, so this hook restores
#   it. (The grammar is not in here and needs no shipping: Zed builds
#   tree-sitter-lex from `[grammars.lex]` in extension.toml.)
#
# Env contract (from the canonical workflow):
#   BUNDLE_DIR      absolute path to the assembled bundle (= $GITHUB_WORKSPACE/dist)
#   EXTENSION_NAME  resolved extension name (e.g. "lex")
#   VERSION         release version (e.g. "0.2.0")
#
# Working dir at hook time is the repo root.

set -euo pipefail

: "${BUNDLE_DIR:?BUNDLE_DIR must be set by the canonical workflow}"

if [ ! -d "${BUNDLE_DIR}" ]; then
    echo "::error::BUNDLE_DIR=${BUNDLE_DIR} is not a directory (or doesn't exist)"
    exit 1
fi

if [ ! -d shared ]; then
    echo "::error::shared/ directory missing at repo root — expected shared/lex-deps.json"
    exit 1
fi

if [ ! -f shared/lex-deps.json ]; then
    echo "::error::shared/lex-deps.json missing — runtime deps pin file"
    exit 1
fi

# Copy contents rather than the directory itself so the operation is
# idempotent: if BUNDLE_DIR/shared already exists (e.g. a reused build
# dir), `cp -R shared dest/` nests into dest/shared/shared. The
# `shared/.` + explicit dest dir avoids that.
mkdir -p "${BUNDLE_DIR}/shared"
cp -R shared/. "${BUNDLE_DIR}/shared/"
echo "Copied shared/ into bundle:"
ls -la "${BUNDLE_DIR}/shared/"
