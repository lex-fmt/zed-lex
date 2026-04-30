; Injection queries for Lex — Zed flavour.
;
; Verbatim blocks closed with a recognised language annotation get that
; language injected into their content. Zed's documented injection
; predicates are #set! and #eq?; the upstream tree-sitter-lex
; injections.scm relies on #gsub! to extract the first word from a
; potentially-parametrised header (e.g. ":: json format=pretty ::"),
; which Zed doesn't necessarily support. We instead enumerate each
; known language with #match? on the raw annotation_header text.
;
; Languages not listed here pass through with no injection — the user
; will see lex-text styling, which is harmless. To add a language,
; copy a block and change the two strings.
;
; The "table" annotation is intentionally absent: table contents are
; lex with inline syntax, not a foreign language.

; --- python ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*python\\b")
 (#set! injection.language "python")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*python\\b")
 (#set! injection.language "python")
 (#set! injection.combined))

; --- json ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*json\\b")
 (#set! injection.language "json")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*json\\b")
 (#set! injection.language "json")
 (#set! injection.combined))

; --- javascript / typescript ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*(javascript|js)\\b")
 (#set! injection.language "javascript")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*(javascript|js)\\b")
 (#set! injection.language "javascript")
 (#set! injection.combined))

((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*(typescript|ts)\\b")
 (#set! injection.language "typescript")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*(typescript|ts)\\b")
 (#set! injection.language "typescript")
 (#set! injection.combined))

; --- rust ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*rust\\b")
 (#set! injection.language "rust")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*rust\\b")
 (#set! injection.language "rust")
 (#set! injection.combined))

; --- go ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*go\\b")
 (#set! injection.language "go")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*go\\b")
 (#set! injection.language "go")
 (#set! injection.combined))

; --- shell / bash ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*(bash|shell|sh|zsh)\\b")
 (#set! injection.language "shellscript")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*(bash|shell|sh|zsh)\\b")
 (#set! injection.language "shellscript")
 (#set! injection.combined))

; --- yaml ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*yaml\\b")
 (#set! injection.language "yaml")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*yaml\\b")
 (#set! injection.language "yaml")
 (#set! injection.combined))

; --- toml ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*toml\\b")
 (#set! injection.language "toml")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*toml\\b")
 (#set! injection.language "toml")
 (#set! injection.combined))

; --- html ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*html\\b")
 (#set! injection.language "html")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*html\\b")
 (#set! injection.language "html")
 (#set! injection.combined))

; --- css ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*css\\b")
 (#set! injection.language "css")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*css\\b")
 (#set! injection.language "css")
 (#set! injection.combined))

; --- sql ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*sql\\b")
 (#set! injection.language "sql")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*sql\\b")
 (#set! injection.language "sql")
 (#set! injection.combined))

; --- markdown ---
((verbatim_block
  (paragraph) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*(markdown|md)\\b")
 (#set! injection.language "markdown")
 (#set! injection.combined))

((verbatim_block
  (verbatim_content) @injection.content
  (annotation_header) @_lang)
 (#match? @_lang "^\\s*(markdown|md)\\b")
 (#set! injection.language "markdown")
 (#set! injection.combined))
