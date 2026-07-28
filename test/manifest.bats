#!/usr/bin/env bats
# Manifest-shape tests for extension.toml and shared/lex-deps.json.
# Each invariant is its own @test so failures point at exactly what
# regressed.

load 'helpers'

# --- extension.toml: top-level required fields ------------------------------

@test "extension.toml has id" { assert_toml_has_field id; }
@test "extension.toml has name" { assert_toml_has_field name; }
@test "extension.toml has version" { assert_toml_has_field version; }
@test "extension.toml has schema_version" { assert_toml_has_field schema_version; }
@test "extension.toml has authors" { assert_toml_has_field authors; }
@test "extension.toml has description" { assert_toml_has_field description; }
@test "extension.toml has repository" { assert_toml_has_field repository; }

# --- extension.toml: grammar wiring -----------------------------------------

@test "extension.toml has [grammars.lex]" {
    assert_toml_has_path grammars.lex
}

@test "[grammars.lex].repository points at lex-fmt/tree-sitter-lex" {
    run toml_path grammars.lex.repository
    [ "$status" -eq 0 ]
    [[ "$output" == *"lex-fmt/tree-sitter-lex"* ]]
}

@test "[grammars.lex].commit is a 40-char hex SHA" {
    run toml_path grammars.lex.commit
    [ "$status" -eq 0 ]
    assert_sha40 "$output"
}

# --- extension.toml: language server wiring ---------------------------------

@test "extension.toml has [language_servers.lex-lsp]" {
    assert_toml_has_path language_servers.lex-lsp
}

@test "[language_servers.lex-lsp].name is set" {
    assert_toml_has_path language_servers.lex-lsp.name
}

# --- shared/lex-deps.json ----------------------------------------------------

@test "shared/lex-deps.json parses as JSON" {
    python3 -c "import json;json.load(open('$REPO_DIR/shared/lex-deps.json'))"
}

@test "shared/lex-deps.json pins lexd-lsp" {
    assert_json_has_key shared/lex-deps.json lexd-lsp
}

@test "shared/lex-deps.json: lexd-lsp version is v-prefixed" {
    local v
    v=$(python3 -c "import json;print(json.load(open('$REPO_DIR/shared/lex-deps.json'))['lexd-lsp'])")
    assert_v_prefixed "$v"
}

@test "shared/lex-deps.json: lexd-lsp-repo is set" {
    assert_json_has_key shared/lex-deps.json lexd-lsp-repo
}

# lex-deps.json pins only what the Rust code downloads at runtime — the
# lexd-lsp binary. The grammar is not downloaded by us at all: Zed clones
# and builds it from [grammars.lex] in extension.toml. A `tree-sitter` key
# here reads as a live pin to anyone auditing who consumes tree-sitter-lex,
# while nothing enforces it (serde drops unknown keys), so it silently goes
# stale. Keep it deleted.
@test "shared/lex-deps.json carries no tree-sitter pin" {
    run assert_json_has_key shared/lex-deps.json tree-sitter
    [ "$status" -ne 0 ]
    run assert_json_has_key shared/lex-deps.json tree-sitter-repo
    [ "$status" -ne 0 ]
}

# --- generators ----- ----- ----- ----- ----- ----- ----- ----- ----- ------

# injections.scm is mechanically derived from gen-injections.py to keep
# the (language × content-type) matrix consistent. If you edit
# injections.scm directly this test reminds you to update the script.
@test "injections.scm matches app-bin/gen-injections.py" {
    python3 "$REPO_DIR/app-bin/gen-injections.py" --check
}

# themes/lex-monochrome.json is generated from gen-theme.py. Keeps the
# canonical 4-tier color map and Zed capture-name mapping in one place;
# touching the snippet directly fails this test.
@test "themes/lex-monochrome.json matches app-bin/gen-theme.py" {
    python3 "$REPO_DIR/app-bin/gen-theme.py" --check
}
