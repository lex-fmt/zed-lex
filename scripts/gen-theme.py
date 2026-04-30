#!/usr/bin/env python3
"""Generate themes/lex-monochrome.json from the canonical 4-tier
intensity color map.

Lex Monochrome is the same scheme shipped in the nvim plugin
(`lua/lex/theme.lua`) and the vscode extension. Until
`comms/shared/theme.json` lands as a single source of truth across all
editors (active project per memory), the colour table is duplicated here.

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

Run after editing COLORS / SYNTAX_OVERRIDES / THEMES, then commit the
regenerated file. The bats suite runs `gen-theme.py --check` so an
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
# unification project lands.
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

# Themes to emit overrides for. The key is the exact Zed theme name (as
# shown in the theme picker); the value is the appearance the colours
# should be rendered for. Add more entries here for users on Ayu,
# Gruvbox, Andromeda, etc.
THEMES = {
    "One Dark":  "dark",
    "One Light": "light",
}

# ---------------------------------------------------------------------------
# Mapping: Zed syntax-capture name -> { intensity, font_style?, font_weight? }
# Mirrors the captures emitted by languages/lex/highlights.scm.
# ---------------------------------------------------------------------------

BOLD = 700  # canonical CSS / Zed "bold" weight

SYNTAX_OVERRIDES: dict[str, dict] = {
    "title":                   {"intensity": "normal", "font_weight": BOLD},
    "property":                {"intensity": "normal", "font_style": "italic"},
    "text.literal":            {"intensity": "normal"},
    "string.special":          {"intensity": "faint"},
    "punctuation.list_marker": {"intensity": "muted",  "font_style": "italic"},
    "emphasis":                {"intensity": "normal", "font_style": "italic"},
    "emphasis.strong":         {"intensity": "normal", "font_weight": BOLD},
    "string.escape":           {"intensity": "faint"},
    "punctuation.special":     {"intensity": "faint"},
    "comment":                 {"intensity": "faint"},
    "link_text":               {"intensity": "muted"},
    "link_uri":                {"intensity": "muted"},
    "constant":                {"intensity": "muted"},
    "punctuation.delimiter":   {"intensity": "faint"},
}


def render_syntax(appearance: str) -> dict:
    palette = COLORS[appearance]
    syntax = {}
    for capture, spec in SYNTAX_OVERRIDES.items():
        entry = {"color": palette[spec["intensity"]]}
        if "font_style" in spec:
            entry["font_style"] = spec["font_style"]
        if "font_weight" in spec:
            entry["font_weight"] = spec["font_weight"]
        syntax[capture] = entry
    return syntax


def render() -> dict:
    return {
        "theme_overrides": {
            theme_name: {"syntax": render_syntax(appearance)}
            for theme_name, appearance in THEMES.items()
        }
    }


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    target = repo_root / "themes" / "lex-monochrome.json"
    target.parent.mkdir(exist_ok=True)
    expected = render()

    if "--check" in sys.argv:
        if not target.exists():
            print(f"FAIL: {target.relative_to(repo_root)} missing", file=sys.stderr)
            return 1
        actual = json.loads(target.read_text())
        if actual != expected:
            print(
                f"FAIL: {target.relative_to(repo_root)} out of sync.\n"
                f"      Run: python3 scripts/gen-theme.py",
                file=sys.stderr,
            )
            return 1
        print(f"  ✓ {target.relative_to(repo_root)} matches generator")
        return 0

    target.write_text(json.dumps(expected, indent=2) + "\n")
    print(f"wrote {target.relative_to(repo_root)} ({len(THEMES)} themes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
