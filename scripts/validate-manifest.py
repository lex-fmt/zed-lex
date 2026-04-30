#!/usr/bin/env python3
"""Validate extension.toml and shared/lex-deps.json.

Checks:
  - extension.toml has all required top-level fields
  - every [grammars.<id>] has a 40-char `commit` SHA and a `repository` URL
  - every [language_servers.<id>] has a `name`
  - shared/lex-deps.json parses and has the expected keys
"""

from __future__ import annotations

import json
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ERRORS: list[str] = []


def err(msg: str) -> None:
    ERRORS.append(msg)


def check_extension_toml() -> None:
    path = ROOT / "extension.toml"
    if not path.exists():
        err(f"missing {path}")
        return
    with path.open("rb") as fh:
        data = tomllib.load(fh)

    required = ["id", "name", "version", "schema_version", "authors",
                "description", "repository"]
    for key in required:
        if key not in data:
            err(f"extension.toml: missing required field {key!r}")

    grammars = data.get("grammars", {})
    if not grammars:
        err("extension.toml: no [grammars.*] table")
    for name, g in grammars.items():
        if "repository" not in g:
            err(f"extension.toml: [grammars.{name}] missing repository")
        if "commit" not in g:
            err(f"extension.toml: [grammars.{name}] missing commit")
        elif len(g["commit"]) != 40 or not all(
            c in "0123456789abcdef" for c in g["commit"]
        ):
            err(f"extension.toml: [grammars.{name}] commit must be a "
                f"40-char hex SHA, got {g['commit']!r}")

    servers = data.get("language_servers", {})
    if not servers:
        err("extension.toml: no [language_servers.*] table")
    for name, s in servers.items():
        if "name" not in s:
            err(f"extension.toml: [language_servers.{name}] missing name")


def check_lex_deps() -> None:
    path = ROOT / "shared" / "lex-deps.json"
    if not path.exists():
        err(f"missing {path}")
        return
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        err(f"shared/lex-deps.json: invalid JSON: {e}")
        return

    for key in ("lexd-lsp", "lexd-lsp-repo"):
        if key not in data:
            err(f"shared/lex-deps.json: missing key {key!r}")
    lsp = data.get("lexd-lsp", "")
    if lsp and not lsp.startswith("v"):
        err(f"shared/lex-deps.json: lexd-lsp version should start with 'v', "
            f"got {lsp!r}")


def main() -> int:
    check_extension_toml()
    check_lex_deps()
    if ERRORS:
        for e in ERRORS:
            print(f"  ✗ {e}", file=sys.stderr)
        print(f"FAIL: {len(ERRORS)} manifest error(s)", file=sys.stderr)
        return 1
    print("  ✓ extension.toml")
    print("  ✓ shared/lex-deps.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
