#!/usr/bin/env bats
# Codebook spell-check query tests.
#
# Validates that `codebook/queries/lex.scm` (shipped here as a reference
# for upstream codebook) is syntactically valid against the lex grammar
# and produces @string captures at every expected prose position in the
# canonical spellcheck fixture.
#
# Limitation: tree-sitter CLI does not evaluate `#has-ancestor?`
# predicates, so the verbatim-body suppression in lex.scm is not
# exercised here. Real e2e validation requires running codebook itself
# against the fixture, which is a follow-up once the query lands in
# codebook upstream.

load 'helpers'

CODEBOOK_QUERY="$REPO_DIR/codebook/queries/lex.scm"
SPELL_FIXTURE="$REPO_DIR/test/fixtures/spellcheck-fixture.lex"

setup_file() {
    setup_grammar >/dev/null
}

# --- query is structurally valid ---------------------------------------------

@test "codebook/queries/lex.scm parses against the spellcheck fixture" {
    [[ -s "$CODEBOOK_QUERY" ]] || skip "codebook query not present"
    out=$(cd "$GRAMMAR_DIR" && $TS_CLI query "$CODEBOOK_QUERY" "$SPELL_FIXTURE" 2>&1)
    rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "query failed to parse:" >&2
        echo "$out" | head -10 >&2
        return 1
    fi
}

# --- prose positions emit @string captures -----------------------------------

assert_string_capture_on_line() {
    local line_text="$1"
    out=$(cd "$GRAMMAR_DIR" && $TS_CLI query "$CODEBOOK_QUERY" "$SPELL_FIXTURE" 2>&1)
    if ! grep -F "$line_text" <<<"$out" | grep -qE "capture: [0-9]+ - string"; then
        echo "no @string capture covering: $line_text" >&2
        echo "---" >&2
        echo "$out" | grep -F "$line_text" | head -5 >&2
        return 1
    fi
}

@test "doc title is captured as @string" {
    assert_string_capture_on_line "Spelchek Fixture Document"
}

@test "subtitle is captured as @string" {
    assert_string_capture_on_line "A subtitle that contians a recieve typo"
}

@test "session title is captured as @string" {
    assert_string_capture_on_line "Sectoin: Prose tests"
}

@test "paragraph prose is captured as @string" {
    assert_string_capture_on_line "A paragraph that occured here"
}

@test "list item is captured as @string" {
    assert_string_capture_on_line "A list item with the Mispelled term inside it"
}

@test "definition subject is captured as @string" {
    assert_string_capture_on_line "Mispelled term:"
}

@test "table caption is captured as @string" {
    assert_string_capture_on_line "Brokn table caption:"
}

@test "table cell content is captured as @string" {
    assert_string_capture_on_line "cell with occured"
}

@test "verbatim subject is captured as @string (prose per policy)" {
    assert_string_capture_on_line "Pythn code example:"
}

@test "annotation trailing descriptor is captured as @string" {
    assert_string_capture_on_line "trailing descriptor with teh typo"
}

@test "annotation block body is captured as @string" {
    assert_string_capture_on_line "The body of this annotation contians teh prose"
}

# --- aggregate counts --------------------------------------------------------

@test "codebook query produces enough @string captures for the fixture (≥15)" {
    out=$(cd "$GRAMMAR_DIR" && $TS_CLI query "$CODEBOOK_QUERY" "$SPELL_FIXTURE" 2>&1)
    count=$(echo "$out" | grep -cE "capture: [0-9]+ - string" || true)
    if [[ "$count" -lt 15 ]]; then
        echo "expected ≥15 @string captures, got $count" >&2
        return 1
    fi
}
