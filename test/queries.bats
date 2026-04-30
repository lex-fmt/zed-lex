#!/usr/bin/env bats
# Tree-sitter query tests.
#
# - parses-against-fixture: every .scm query must parse + run without error
#   against the embedded sample.lex
# - capture-shape: targeted assertions that prove a query actually fires —
#   not just that it's syntactically valid

load 'helpers'

setup_file() {
    setup_grammar >/dev/null
}

# --- structural: every .scm parses ------------------------------------------

@test "highlights.scm parses against sample.lex" {
    assert_query_parses "$QUERY_DIR/highlights.scm"
}

@test "injections.scm parses against sample.lex" {
    assert_query_parses "$QUERY_DIR/injections.scm"
}

@test "outline.scm parses against sample.lex" {
    assert_query_parses "$QUERY_DIR/outline.scm"
}

@test "textobjects.scm parses against sample.lex" {
    assert_query_parses "$QUERY_DIR/textobjects.scm"
}

@test "brackets.scm parses against sample.lex" {
    assert_query_parses "$QUERY_DIR/brackets.scm"
}

@test "indents.scm parses against sample.lex" {
    assert_query_parses "$QUERY_DIR/indents.scm"
}

# --- behavioural: queries fire on the fixture --------------------------------

@test "outline.scm captures the document title and at least one session" {
    # sample.lex has 7 sessions and 1 document title — at least 4 @name
    # captures is a comfortable lower bound that catches regressions
    # without being brittle.
    assert_query_captures "$QUERY_DIR/outline.scm" name 4
}

@test "highlights.scm captures @title (heading-level captures)" {
    assert_query_captures "$QUERY_DIR/highlights.scm" title 2
}

@test "highlights.scm captures @property (definition subjects)" {
    assert_query_captures "$QUERY_DIR/highlights.scm" property 1
}

@test "highlights.scm captures @punctuation.list_marker" {
    assert_query_captures "$QUERY_DIR/highlights.scm" punctuation.list_marker 2
}

# Lex-specific dual-tag: every theme-overridable capture is emitted both
# as @x and @x.lex. The .lex variants are what theme_overrides targets,
# so if dual-tagging regresses, theme_overrides silently stops working
# for that capture.
@test "highlights.scm dual-tags @title.lex" {
    assert_query_captures "$QUERY_DIR/highlights.scm" title.lex 2
}

@test "highlights.scm dual-tags @comment.lex" {
    assert_query_captures "$QUERY_DIR/highlights.scm" comment.lex 1
}

@test "highlights.scm dual-tags @emphasis.lex" {
    assert_query_captures "$QUERY_DIR/highlights.scm" emphasis.lex 1
}

@test "injections.scm fires injection.content for python and json blocks" {
    assert_query_captures "$QUERY_DIR/injections.scm" injection.content 2
}
