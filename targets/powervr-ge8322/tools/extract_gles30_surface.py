#!/usr/bin/env python3
"""Extract the OpenGL ES 3.0 core API surface from Khronos gl.xml.

Usage:
  python extract_gles30_surface.py path/to/gl.xml

The Khronos OpenGL registry represents OpenGL ES 2.0 and later with api="gles2".
This script collects commands and enumerants required by core ES features through
3.0, excluding later core versions and extensions.  The registry is the
completeness authority for the host API list in SURFACE.txt.
"""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def version_tuple(text: str) -> tuple[int, int]:
    major, minor = text.split(".", 1)
    return int(major), int(minor)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: extract_gles30_surface.py gl.xml")

    root = ET.parse(Path(sys.argv[1])).getroot()
    commands: set[str] = set()
    enums: set[str] = set()

    for feature in root.findall("feature"):
        if feature.get("api") != "gles2":
            continue
        number = feature.get("number")
        if number is None or version_tuple(number) > (3, 0):
            continue

        for block in feature:
            if block.tag == "remove":
                # Core ES features through 3.0 do not need removed names in the
                # resulting callable surface.
                continue
            api = block.get("api")
            if api is not None and "gles2" not in api.split(","):
                continue
            for command in block.findall("command"):
                name = command.get("name")
                if name:
                    commands.add(name)
            for enum in block.findall("enum"):
                name = enum.get("name")
                if name:
                    enums.add(name)

    print("OPENGL ES 3.0 CORE COMMANDS")
    for name in sorted(commands):
        print(name)

    print("\nOPENGL ES 3.0 CORE ENUMERANTS")
    for name in sorted(enums):
        print(name)


if __name__ == "__main__":
    main()
