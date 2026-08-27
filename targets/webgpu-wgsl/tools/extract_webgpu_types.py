#!/usr/bin/env python3
"""Extract WebGPU host verbs and option sets from gpuweb/types.

Pinned input for this branch:
  gpuweb/types 0.1.72
  commit bcb683e961c619ae5ecf6696e55507602a07609e
  dist/index.d.ts

Usage:
  python extract_webgpu_types.py path/to/dist/index.d.ts

This deliberately reports names rather than trying to restate the prose
validation rules from the WebGPU specification.  The specification remains
normative; this script is a completeness check for the named API surface.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

INTERFACE_RE = re.compile(r"(?:^|\n)interface\s+(GPU\w+)\b[^\{]*\{(.*?)\n\}", re.S)
TYPE_RE = re.compile(r"(?:^|\n)type\s+(GPU\w+)\s*=\s*(.*?);", re.S)
NAMESPACE_RE = re.compile(r"(?:^|\n)(?:declare\s+)?(?:namespace|interface)\s+(GPU\w+)\b[^\{]*\{(.*?)\n\}", re.S)
METHOD_RE = re.compile(r"^\s*([A-Za-z_]\w*)\s*(?:<[^;{]*?>)?\s*\([^;]*\)\s*:\s*[^;]+;", re.M)
STRING_RE = re.compile(r'"([^"\n]+)"')
CONST_RE = re.compile(r"^\s*(?:readonly\s+)?(?:const\s+)?([A-Z][A-Z0-9_]*)\s*(?::|=)", re.M)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: extract_webgpu_types.py dist/index.d.ts")
    text = Path(sys.argv[1]).read_text(encoding="utf-8")

    print("WEBGPU INTERFACE METHODS")
    for interface, body in sorted(INTERFACE_RE.findall(text)):
        methods = sorted(set(METHOD_RE.findall(body)))
        if methods:
            print(f"\n[{interface}]")
            for name in methods:
                print(name)

    print("\nWEBGPU STRING-UNION OPTIONS")
    for name, body in sorted(TYPE_RE.findall(text)):
        values = STRING_RE.findall(body)
        if values:
            print(f"\n[{name}]")
            for value in values:
                print(value)

    print("\nWEBGPU CONSTANT NAMESPACES")
    seen: set[tuple[str, tuple[str, ...]]] = set()
    for name, body in sorted(NAMESPACE_RE.findall(text)):
        constants = tuple(sorted(set(CONST_RE.findall(body))))
        if not constants:
            continue
        key = (name, constants)
        if key in seen:
            continue
        seen.add(key)
        print(f"\n[{name}]")
        for constant in constants:
            print(constant)


if __name__ == "__main__":
    main()
