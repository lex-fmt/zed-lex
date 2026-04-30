#!/usr/bin/env python3
"""Generate themes/lex-monochrome.{dark,light}.json from the canonical
4-tier intensity color map.

Lex Monochrome is the same scheme shipped in the nvim plugin
(`lua/lex/theme.lua`) and the vscode extension. Until
`comms/shared/theme.json` lands as a single source of truth across all
editors (active project per ../.padz / memory), the colour table is
duplicated here.

Output snippets are pasted into Zed's settings.json under:

    languages > Lex > experimental.theme_overrides > syntax

Zed's per-language `experimental.theme_overrides` supports `color`,
`font_style`, and `font_weight` only; per-token background and
text-decoration are not honoured, so the code-block background and
reference underlines from nvim/vscode don't carry over. Colour does the
heavy lifting through the intensity hierarchy.

Run after editing the COLORS / SYNTAX_OVERRIDES tables, then commit the
regenerated files. The bats suite runs `gen-theme.py --check` so an
out-of-sync snippet fails CI.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Canonical 4-tier monochrome palette
#
# CANDIDATE for promotion to comms/shared/theme.json once the cross-editor
# unification project (memory: project_theme_unification.md) lands. nvim
# already uses these exact values in lua/lex/theme.lua; vscode/lexed are
# scheduled to align in their own repos.
# ---------------------------------------------------------------------------

COLORS = {
    "dark": {
        "normal":   "#e0e0e0",   # readers focus here
        "muted":    "#888888",   # structural markers, references
        "faint":    "#666666",   # meta-info, annotations
        "faintest": "#555555",   # inline syntax markers
    },
    "light": {
        "normal":   "#000000",
        "muted":    "#808080",
        "faint":    "#b3b3b3",
        "faintest": "#cacaca",
    },
}

# ---------------------------------------------------------------------------
# Mapping: Zed syntax-capture name -> { intensity, font_style?, font_weight? }
#
# Keys mirror the captures emitted by languages/lex/highlights.scm.
# Anything not listed inherits the active theme's default for that capture.
# Intensity names index into COLORS[appearance]. Weight 700 is "bold".
# ---------------------------------------------------------------------------

# 700 is the canonical "bold" font-weight in CSS / Zed's schema.
BOLD = 700

SYNTAX_OVERRIDES: dict[str, dict] = {
    # Headings: document title, session titles. Bold to read as primary.
    "title": {"intensity": "normal", "font_weight": BOLD},

    # Definition subjects: italic, full intensity (the reader cares about
    # the term being defined).
    "property": {"intensity": "normal", "font_style": "italic"},

    # Verbatim / code / math content. In nvim/vscode there's a code_bg,
    # but Zed overrides don't accept background_color — colour only.
    "text.literal": {"intensity": "normal"},

    # Verbatim subjects (the line introducing a code block) and the
    # closing :: lang :: line — meta, faint.
    "string.special": {"intensity": "faint"},

    # List markers: muted italic, signal "structural" without competing
    # with the prose body.
    "punctuation.list_marker": {"intensity": "muted", "font_style": "italic"},

    # Inline emphasis / strong. Bold is bold; italic is italic.
    "emphasis":         {"intensity": "normal", "font_style": "italic"},
    "emphasis.strong":  {"intensity": "normal", "font_weight": BOLD},

    # Escape sequences (\*, \_, …): faint; they're scaffolding.
    "string.escape": {"intensity": "faint"},

    # Annotation markers `::` and the body between them: faint; metadata.
    "punctuation.special": {"intensity": "faint"},
    "comment":             {"intensity": "faint"},

    # References / links: muted. Underline isn't honoured by overrides
    # (per Zed schema), so we lean on colour.
    "link_text": {"intensity": "muted"},
    "link_uri":  {"intensity": "muted"},

    # tocome references: muted constant.
    "constant": {"intensity": "muted"},

    # Table pipes: faint, structural.
    "punctuation.delimiter": {"intensity": "faint"},
}


def render_overrides(appearance: str) -> dict:
    """Return the full settings-shape so the file is copy-paste-mergeable
    into the user's settings.json without restructuring."""
    palette = COLORS[appearance]
    syntax = {}
    for capture, spec in SYNTAX_OVERRIDES.items():
        entry = {"color": palette[spec["intensity"]]}
        if "font_style" in spec:
            entry["font_style"] = spec["font_style"]
        if "font_weight" in spec:
            entry["font_weight"] = spec["font_weight"]
        syntax[capture] = entry

    return {
        "languages": {
            "Lex": {
                "experimental.theme_overrides": {"syntax": syntax}
            }
        }
    }


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    themes_dir = repo_root / "themes"
    themes_dir.mkdir(exist_ok=True)

    targets = {
        themes_dir / "lex-monochrome.dark.json":  render_overrides("dark"),
        themes_dir / "lex-monochrome.light.json": render_overrides("light"),
    }

    if "--check" in sys.argv:
        ok = True
        for path, expected in targets.items():
            if not path.exists():
                print(f"FAIL: {path.relative_to(repo_root)} missing", file=sys.stderr)
                ok = False
                continue
            actual = json.loads(path.read_text())
            if actual != expected:
                print(
                    f"FAIL: {path.relative_to(repo_root)} out of sync.\n"
                    f"      Run: python3 scripts/gen-theme.py",
                    file=sys.stderr,
                )
                ok = False
        if not ok:
            return 1
        for path in targets:
            print(f"  ✓ {path.relative_to(repo_root)} matches generator")
        return 0

    for path, content in targets.items():
        path.write_text(json.dumps(content, indent=2) + "\n")
        print(f"wrote {path.relative_to(repo_root)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
