#!/usr/bin/env python3
"""Extract public deko3d verbs and Dk option/enumerant names from deko3d.h.

Usage:
  python extract_deko3d_surface.py path/to/deko3d.h

Pin the input revision in acceptance evidence.  The readable SURFACE.txt and
DEKO3D-OPTIONS.txt are documentation; this extractor is the completeness oracle
for the public C header as deko3d evolves.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

FUNC_RE = re.compile(r"\b(dk[A-Z][A-Za-z0-9_]*)\s*\(")
ENUM_RE = re.compile(r"\b(Dk[A-Za-z0-9_]+)\s*(?:=|,)")
DEFINE_RE = re.compile(r"^\s*#define\s+(DK_[A-Z0-9_]+)\b", re.M)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: extract_deko3d_surface.py deko3d.h")
    text = Path(sys.argv[1]).read_text(encoding="utf-8")

    print("DEKO3D PUBLIC VERBS")
    for name in sorted(set(FUNC_RE.findall(text))):
        print(name)

    print("\nDEKO3D ENUMERANTS / OPTIONS")
    for name in sorted(set(ENUM_RE.findall(text))):
        print(name)

    print("\nDEKO3D PUBLIC CONSTANT MACROS")
    for name in sorted(set(DEFINE_RE.findall(text))):
        print(name)


if __name__ == "__main__":
    main()
