; Highlight queries for Lex — Zed flavour.
;
; This file is intentionally separate from tree-sitter-lex's upstream
; queries/highlights.scm, which targets nvim-treesitter / TextMate scope
; conventions (@markup.heading, @markup.bold, …). Zed's theme uses a
; different, flat capture-name vocabulary (@title, @emphasis.strong, …),
; so the same scopes don't render. The structural capture choices below
; mirror lex-analysis/src/semantic_tokens.rs at CST granularity — the
; LSP's semantic tokens still override these for clients that request
; them, but a syntactic baseline must look right too.

; === Document Title ===
(document_title
  title: (line_content) @title)

(document_subtitle
  subtitle: (line_content) @title)

(document_title
  title: (line_content
    (list_marker) @punctuation.list_marker))

; === Sessions ===
(session
  title: (line_content) @title)

(session
  title: (line_content
    (list_marker) @punctuation.list_marker))

; === Definitions ===
(definition
  subject: (subject_content) @property)

; === Verbatim Blocks ===
(verbatim_block
  subject: (subject_content) @string.special)

(verbatim_block
  (paragraph) @text.literal)
(verbatim_block
  (definition) @text.literal)
(verbatim_block
  (list) @text.literal)
(verbatim_block
  (verbatim_content) @text.literal)
(verbatim_block
  (session) @text.literal)

(verbatim_group_item
  subject: (subject_content) @string.special)
(verbatim_group_item
  (paragraph) @text.literal)
(verbatim_group_item
  (definition) @text.literal)
(verbatim_group_item
  (list) @text.literal)
(verbatim_group_item
  (verbatim_content) @text.literal)
(verbatim_group_item
  (session) @text.literal)

; === Lists ===
(list_item
  (list_marker) @punctuation.list_marker)

; === Annotations ===
(annotation_marker) @punctuation.special
(annotation_close) @punctuation.special
(annotation_header) @comment
(annotation_inline_text) @comment
(annotation_block
  (_) @comment)

; Verbatim closing metadata: the `:: label ::` line at the end of a
; verbatim block is structurally an annotation but visually it's part of
; the verbatim block. Render it as @text.literal so it doesn't pop out.
; Must come AFTER the generic annotation captures above.
(verbatim_block
  (annotation_marker) @text.literal)
(verbatim_block
  (annotation_close) @text.literal)
(verbatim_block
  (annotation_header) @text.literal)

; === Tables ===
; Table caption — emphasis to distinguish from regular definitions.
(definition
  subject: (subject_content) @emphasis
  (table_row))

; Header row — first table_row in a definition (bold).
(definition
  subject: (_) .
  (table_row
    (table_cell
      (text_content) @emphasis.strong)))

; Pipe delimiters
(table_row
  (pipe_delimiter) @punctuation.delimiter)

; Table separator rows — comment-toned (cosmetic, parser ignores them).
(table_separator_row) @comment

; === Inline formatting ===
(strong) @emphasis.strong
(emphasis) @emphasis
(code_span) @text.literal
(math_span) @text.literal
(escape_sequence) @string.escape

; === References ===
(reference) @link_text
(citation_reference) @link_text
(annotation_reference) @link_text
(url_reference) @link_uri
(file_reference) @link_uri
(session_reference) @link_text
(tocome_reference) @constant
(number_reference) @link_text
