; codebook query for the Lex document format.
;
; codebook (https://github.com/blopker/codebook) is a tree-sitter-driven
; spell checker that runs as a language server. Users install it as a Zed
; extension; codebook then dispatches per-language `.scm` query files —
; capturing nodes tagged `@string` or `@comment` for spell-checking.
;
; This query is shipped here as a reference; codebook does not (yet) load
; per-language queries from user config, so the file must land in codebook
; upstream (or in a fork) for Zed-side spell-check to honor it. See the
; "Spell checking" section of the zed-lex README for installation status.
;
; Spell-check policy (mirrors tree-sitter-lex/queries/highlights.scm):
;   - All prose is checked: titles, paragraphs, list items, definition
;     subjects, table cells, verbatim subjects, annotation block bodies,
;     and trailing descriptors on `:: label :: <text>`.
;   - Annotation labels/params and verbatim block bodies are NOT checked
;     (verbatim is code/preformatted; labels are structural identifiers).
;   - Inline atoms (code spans, math spans, references, escapes) are not
;     captured as they have their own node kinds.
;
; Tag convention: codebook's default config includes the `string` tag.
; Nodes not captured here are implicitly excluded from spell-checking.

; --- Prose leaves ------------------------------------------------------

(line_content) @string
(text_content) @string
(subject_content) @string
(annotation_inline_text) @string

; --- Suppress prose nested inside verbatim bodies ----------------------
;
; Verbatim block bodies are code; their inner text_line/line_content
; nodes inherit the catch-all captures above. We suppress by re-tagging
; them with `@_skip` (no spell semantic) — codebook's later-pattern-wins
; semantics drop the @string in favor of the unrecognized capture.
;
; Uses #has-ancestor? — supported by Neovim and (per codebook's
; tree-sitter-rust binding) accepted via standard predicate evaluation.
; If a codebook build doesn't honor this predicate, the result is
; conservative over-checking inside verbatim bodies, not under-checking
; of prose.

((line_content) @_skip
  (#has-ancestor? @_skip verbatim_block verbatim_group_item))
((text_content) @_skip
  (#has-ancestor? @_skip verbatim_block verbatim_group_item))
((subject_content) @_skip
  (#has-ancestor? @_skip verbatim_block verbatim_group_item)
  (#not-has-parent? @_skip verbatim_block verbatim_group_item))
