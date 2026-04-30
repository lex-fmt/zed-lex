#!/usr/bin/env bash
# Parse-test every .scm file under languages/lex/ against a real .lex
# fixture. Confirms each query is syntactically valid and matches against
# a tree-sitter-lex parse tree without erroring.
#
# Fixture resolution order:
#   1. ../tree-sitter-lex sibling checkout (typical local dev layout)
#   2. /tmp/tree-sitter-lex (CI extracts the release tarball there)
#   3. Download tree-sitter-lex tarball from GitHub releases at the
#      version pinned in shared/lex-deps.json
#
# Requires: npx (tree-sitter-cli is installed transiently if needed).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

QUERY_DIR="$REPO_DIR/languages/lex"
TS_DIR=""

# 1. sibling checkout
if [[ -d "$REPO_DIR/../tree-sitter-lex/src" ]]; then
    TS_DIR="$(cd "$REPO_DIR/../tree-sitter-lex" && pwd)"
fi

# 2. /tmp/tree-sitter-lex
if [[ -z "$TS_DIR" && -d /tmp/tree-sitter-lex/src ]]; then
    TS_DIR=/tmp/tree-sitter-lex
fi

# 3. download the pinned release tarball
if [[ -z "$TS_DIR" ]]; then
    TS_VERSION=$(python3 -c "import json; print(json.load(open('$REPO_DIR/shared/lex-deps.json'))['tree-sitter'])")
    TS_REPO=$(python3 -c "import json; d=json.load(open('$REPO_DIR/shared/lex-deps.json')); print(d.get('tree-sitter-repo', 'lex-fmt/tree-sitter-lex'))")
    TS_DIR="$(mktemp -d -t zed-lex-ts.XXXXXX)/tree-sitter-lex"
    mkdir -p "$TS_DIR"
    URL="https://github.com/${TS_REPO}/releases/download/${TS_VERSION}/tree-sitter.tar.gz"
    echo "Downloading $URL"
    curl -fsSL "$URL" -o "$TS_DIR/tree-sitter.tar.gz"
    tar -xzf "$TS_DIR/tree-sitter.tar.gz" -C "$TS_DIR"
fi

cd "$TS_DIR"

# Generate parser if not already present
if [[ ! -f src/parser.c ]]; then
    npx --yes tree-sitter-cli@0.25 generate >/dev/null
fi

FIXTURE=""
for candidate in \
    comms/specs/benchmark/060-injection-multilang.lex \
    comms/specs/benchmark/080-gentle-introduction.lex \
    comms/specs/benchmark/010-kitchensink.lex; do
    if [[ -f "$candidate" ]]; then
        FIXTURE="$candidate"
        break
    fi
done
if [[ -z "$FIXTURE" ]]; then
    FIXTURE="$(find . -name '*.lex' -print -quit || true)"
fi
if [[ -z "$FIXTURE" ]]; then
    echo "  ✗ no .lex fixture found at $TS_DIR" >&2
    exit 1
fi

echo "  fixture: $TS_DIR/$FIXTURE"

FAILED=false
for q in "$QUERY_DIR"/*.scm; do
    name="$(basename "$q")"
    if [[ ! -s "$q" ]]; then
        echo "  ⊘ $name (empty)"
        continue
    fi
    if npx --yes tree-sitter-cli@0.25 query "$q" "$FIXTURE" >/dev/null 2>&1; then
        echo "  ✓ $name"
    else
        echo "  ✗ $name" >&2
        npx --yes tree-sitter-cli@0.25 query "$q" "$FIXTURE" 2>&1 | head -10 >&2 || true
        FAILED=true
    fi
done

$FAILED && exit 1
exit 0
