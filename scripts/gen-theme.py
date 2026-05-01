#!/usr/bin/env python3
"""Generate themes/lex-monochrome.json from the canonical theme data in
`comms/shared/theming/lex-theme.json`.

The canonical file carries the 4-tier intensity palette and the ~33 VSCode
semantic-token IDs. Zed has no LSP-semantic-tokens hook — it themes
through tree-sitter captures only — so this generator carries an inline
mapping from Zed's `*.lex` capture names (emitted by
`languages/lex/highlights.scm`) to the canonical token IDs. Color and
style come from the canonical file; the capture mapping is Zed-local.

Output is a single Zed `theme_overrides` object keyed by theme name.
That's the only override mechanism Zed actually supports for syntax
recoloring with auto dark/light switching. The trade-off is that the
override is **global** — it applies to every file in those themes, not
just .lex. (Zed has no per-language theme override path; the
`languages.<Lang>.experimental.theme_overrides` form some older docs
suggest is rejected by current settings schema validation.)

By default we generate overrides for One Dark / One Light because
they're Zed's defaults and what most "system mode" setups use. To add
more themes, edit THEMES below and re-run.

Run after editing the canonical file or CAPTURE_TO_TOKEN / THEMES, then
commit the regenerated file. The bats suite runs `gen-theme.py --check`
so an out-of-sync snippet fails CI.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
CANONICAL = REPO_DIR / "comms" / "shared" / "theming" / "lex-theme.json"
TARGET = REPO_DIR / "themes" / "lex-monochrome.json"

# Themes to emit overrides for. The key is the exact Zed theme name (as
# shown in the theme picker); the value is the appearance the colours
# should be rendered for. Add more entries here for users on Ayu,
# Gruvbox, Andromeda, etc.
THEMES = {
    "One Dark":  "dark",
    "One Light": "light",
}

BOLD = 700  # canonical CSS / Zed "bold" weight

# Mapping: Zed syntax-capture name -> canonical VSCode token ID.
#
# Captures are dual-tagged in highlights.scm (e.g. `@title @title.lex`)
# so the .lex variant exists; targeting the .lex suffix means the
# override only reaches Lex files.
#
# Some Zed captures are coarser than VSCode tokens (e.g. zed has one
# `title.lex` for both DocumentTitle and SessionTitleText); we pick the
# token whose styling preserves existing zed behavior. To split them
# you'd need new captures in highlights.scm first.
CAPTURE_TO_TOKEN: dict[str, str] = {
    "title.lex":                   "SessionTitleText",
    "property.lex":                "DefinitionSubject",
    "text.literal.lex":            "VerbatimContent",
    "string.special.lex":          "VerbatimSubject",
    "punctuation.list_marker.lex": "ListMarker",
    "emphasis.lex":                "InlineEmphasis",
    "emphasis.strong.lex":         "InlineStrong",
    "string.escape.lex":           "VerbatimSubject",
    "punctuation.special.lex":     "VerbatimSubject",
    "comment.lex":                 "AnnotationContent",
    "link_text.lex":               "Reference",
    "link_uri.lex":                "Reference",
    "constant.lex":                "Reference",
    "punctuation.delimiter.lex":   "VerbatimSubject",
}


def load_canonical() -> dict:
    return json.loads(CANONICAL.read_text())


def render_capture(token: dict, palette: dict, appearance: str) -> dict:
    # Note: the canonical token may carry a `background` hint, but Zed's
    # syntax-override schema doesn't support backgrounds (or underlines)
    # on the syntax-capture path, so we silently drop those here.
    # Underlines on link captures come from Zed's link styling, not from
    # theme_overrides.
    entry: dict = {"color": palette[token["intensity"]][appearance]}
    styles = token.get("styles", [])
    if "italic" in styles:
        entry["font_style"] = "italic"
    if "bold" in styles:
        entry["font_weight"] = BOLD
    return entry


def render_syntax(canonical: dict, appearance: str) -> dict:
    palette = canonical["intensities"]
    tokens = canonical["tokens"]
    syntax = {}
    for capture, token_id in CAPTURE_TO_TOKEN.items():
        if token_id not in tokens:
            raise SystemExit(
                f"FAIL: gen-theme.py CAPTURE_TO_TOKEN references unknown token '{token_id}' "
                f"(for capture '{capture}'). Update comms/shared/theming/lex-theme.json "
                f"or fix the mapping in this script."
            )
        syntax[capture] = render_capture(tokens[token_id], palette, appearance)
    return syntax


def render() -> dict:
    canonical = load_canonical()
    return {
        "theme_overrides": {
            theme_name: {"syntax": render_syntax(canonical, appearance)}
            for theme_name, appearance in THEMES.items()
        }
    }


def main() -> int:
    if not CANONICAL.exists():
        print(
            f"FAIL: canonical theme not found at {CANONICAL.relative_to(REPO_DIR)}.\n"
            f"      Did you forget `git submodule update --init`?",
            file=sys.stderr,
        )
        return 1

    expected = render()
    TARGET.parent.mkdir(exist_ok=True)

    if "--check" in sys.argv:
        if not TARGET.exists():
            print(f"FAIL: {TARGET.relative_to(REPO_DIR)} missing", file=sys.stderr)
            return 1
        actual = json.loads(TARGET.read_text())
        if actual != expected:
            print(
                f"FAIL: {TARGET.relative_to(REPO_DIR)} out of sync.\n"
                f"      Run: python3 scripts/gen-theme.py",
                file=sys.stderr,
            )
            return 1
        print(f"  ✓ {TARGET.relative_to(REPO_DIR)} matches generator")
        return 0

    TARGET.write_text(json.dumps(expected, indent=2) + "\n")
    print(f"wrote {TARGET.relative_to(REPO_DIR)} ({len(THEMES)} themes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
