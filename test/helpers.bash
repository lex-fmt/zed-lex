# Shared helpers for the zed-lex bats suite.
#
# Loaded via:  load 'helpers'   from a .bats file under test/.
#
# Provides:
#   - Path constants ($REPO_DIR, $QUERY_DIR, $FIXTURE, $GRAMMAR_DIR)
#   - setup_grammar         — resolve/download/generate tree-sitter-lex source
#   - assert_query_parses   — run `tree-sitter query` and fail on stderr/exit
#   - assert_query_captures — assert at least N captures of a given name
#   - assert_toml_has_field — TOML field-presence (via python3 tomllib)
#   - assert_json_field_eq  — JSON field equality (via python3 json)
#   - assert_sha40          — value is a 40-char lowercase hex string
#   - assert_v_prefixed     — value begins with "v" (release-tag convention)
#
# All helpers fail loudly with a useful diff/message; bats prints the
# function name and the @test name on failure.

# --- Path constants ----------------------------------------------------------

# test/helpers.bash -> repo root
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUERY_DIR="$REPO_DIR/languages/lex"
FIXTURE="$REPO_DIR/test/fixtures/sample.lex"
TS_CLI="npx --yes tree-sitter-cli@0.25"

# Cache the resolved grammar path for the suite. setup_grammar writes
# here, exports it, and tests inherit it from the environment.
# Don't clobber an already-exported value (helpers.bash is reloaded in
# every @test, but bats keeps the env across them).
GRAMMAR_DIR="${GRAMMAR_DIR:-}"

# --- Grammar resolution ------------------------------------------------------

# Resolve tree-sitter-lex source (parser.c + scanner.c + grammar.js + generated
# grammar.json) and echo its path.  Resolution order:
#   1. ../tree-sitter-lex sibling checkout
#   2. /tmp/tree-sitter-lex (already-extracted)
#   3. Download release tarball from GitHub at the version pinned in
#      shared/lex-deps.json
# Always runs `tree-sitter generate` (idempotent) so grammar.json exists.
setup_grammar() {
    if [[ -n "$GRAMMAR_DIR" && -f "$GRAMMAR_DIR/src/grammar.json" ]]; then
        echo "$GRAMMAR_DIR"
        return 0
    fi

    local dir=""
    if [[ -d "$REPO_DIR/../tree-sitter-lex/src" ]]; then
        dir="$(cd "$REPO_DIR/../tree-sitter-lex" && pwd)"
    elif [[ -d /tmp/tree-sitter-lex/src ]]; then
        dir=/tmp/tree-sitter-lex
    else
        local ts_version ts_repo url
        ts_version=$(python3 -c "import json;print(json.load(open('$REPO_DIR/shared/lex-deps.json'))['tree-sitter'])")
        ts_repo=$(python3 -c "import json;d=json.load(open('$REPO_DIR/shared/lex-deps.json'));print(d.get('tree-sitter-repo','lex-fmt/tree-sitter-lex'))")
        dir="$(mktemp -d -t zed-lex-ts.XXXXXX)/tree-sitter-lex"
        mkdir -p "$dir"
        url="https://github.com/${ts_repo}/releases/download/${ts_version}/tree-sitter.tar.gz"
        curl -fsSL "$url" -o "$dir/tree-sitter.tar.gz"
        tar -xzf "$dir/tree-sitter.tar.gz" -C "$dir"
    fi

    ( cd "$dir" && $TS_CLI generate >/dev/null )
    GRAMMAR_DIR="$dir"
    export GRAMMAR_DIR
    echo "$dir"
}

# --- Query assertions --------------------------------------------------------

# Confirm a .scm query parses and runs without error against $FIXTURE.
# Empty .scm files are treated as valid (intentional placeholders).
assert_query_parses() {
    local query="$1"
    if [[ ! -s "$query" ]]; then
        return 0
    fi
    local out
    out=$(cd "$GRAMMAR_DIR" && $TS_CLI query "$query" "$FIXTURE" 2>&1)
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "query failed: $query" >&2
        echo "$out" | head -20 >&2
        return 1
    fi
}

# Assert a query produces at least $min captures named @$name. Useful for
# regression tests like "outline.scm must capture at least 3 sessions
# from the fixture".
assert_query_captures() {
    local query="$1" name="$2" min="${3:-1}"
    local out count
    out=$(cd "$GRAMMAR_DIR" && $TS_CLI query "$query" "$FIXTURE" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "query failed to run: $query" >&2
        echo "$out" | head -10 >&2
        return 1
    fi
    count=$(echo "$out" | grep -cE "capture: [0-9]+ - $name|capture: $name" || true)
    if [[ "$count" -lt "$min" ]]; then
        echo "expected ≥$min @$name captures from $query, got $count" >&2
        echo "$out" | head -20 >&2
        return 1
    fi
}

# --- Manifest assertions -----------------------------------------------------

# Read a top-level field from extension.toml. Fails if the field is missing.
toml_field() {
    local field="$1"
    python3 - <<PY
import sys, tomllib
with open("$REPO_DIR/extension.toml","rb") as f:
    data = tomllib.load(f)
v = data.get("$field")
if v is None:
    sys.exit("missing field: $field")
print(v)
PY
}

# Read a nested field like "grammars.lex.commit".
toml_path() {
    local path="$1"
    python3 - <<PY
import sys, tomllib
with open("$REPO_DIR/extension.toml","rb") as f:
    data = tomllib.load(f)
node = data
for part in "$path".split("."):
    if not isinstance(node, dict) or part not in node:
        sys.exit("missing path: $path")
    node = node[part]
print(node)
PY
}

assert_toml_has_field() {
    local field="$1"
    toml_field "$field" >/dev/null
}

assert_toml_has_path() {
    local path="$1"
    toml_path "$path" >/dev/null
}

# Assert a JSON field at $REPO_DIR/$file equals $expected.
assert_json_field_eq() {
    local file="$1" key="$2" expected="$3"
    local got
    got=$(python3 -c "import json;print(json.load(open('$REPO_DIR/$file'))['$key'])")
    if [[ "$got" != "$expected" ]]; then
        echo "$file: $key = $got (expected $expected)" >&2
        return 1
    fi
}

assert_json_has_key() {
    local file="$1" key="$2"
    python3 -c "import json,sys;d=json.load(open('$REPO_DIR/$file'));sys.exit(0 if '$key' in d else 1)" \
        || { echo "$file: missing key $key" >&2; return 1; }
}

# --- Format assertions -------------------------------------------------------

assert_sha40() {
    local v="$1"
    [[ "$v" =~ ^[0-9a-f]{40}$ ]] \
        || { echo "not a 40-char lowercase hex SHA: $v" >&2; return 1; }
}

assert_v_prefixed() {
    local v="$1"
    [[ "$v" =~ ^v[0-9] ]] \
        || { echo "expected v-prefixed version, got: $v" >&2; return 1; }
}
