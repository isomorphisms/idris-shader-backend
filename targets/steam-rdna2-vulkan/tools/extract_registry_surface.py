#!/usr/bin/env python3
"""Extract the core compiler-visible Vulkan/SPIR-V verb surface.

Usage:
  python extract_registry_surface.py --vk-xml vk.xml --spirv-grammar spirv.core.grammar.json

The inputs are the Khronos machine-readable registries.  No extension command or
extension-only SPIR-V opcode is promoted into the baseline merely because it is
present in those registries.
"""

from __future__ import annotations

import argparse
import json
import xml.etree.ElementTree as ET
from pathlib import Path


def version_tuple(text: str) -> tuple[int, int]:
    major, minor = text.split(".", 1)
    return int(major), int(minor)


def vulkan_core_commands(path: Path, maximum=(1, 4)) -> list[str]:
    root = ET.parse(path).getroot()
    out: set[str] = set()
    accepted_prefixes = (
        "VK_BASE_VERSION_",
        "VK_COMPUTE_VERSION_",
        "VK_GRAPHICS_VERSION_",
        "VK_VERSION_",
    )
    for feature in root.findall("feature"):
        api = feature.get("api", "")
        name = feature.get("name", "")
        number = feature.get("number")
        if "vulkan" not in api.split(","):
            continue
        if not name.startswith(accepted_prefixes) or number is None:
            continue
        if version_tuple(number) > maximum:
            continue
        # Deprecated/superseded core calls are still callable core operations,
        # so collect all command references under the feature except removals.
        for child in feature:
            if child.tag == "remove":
                continue
            for command in child.findall(".//command"):
                name = command.get("name")
                if name:
                    out.add(name)
    return sorted(out)


def spirv_core_instructions(path: Path, maximum=(1, 6)) -> list[str]:
    grammar = json.loads(path.read_text())
    out: set[str] = set()
    for instruction in grammar["instructions"]:
        version = instruction.get("version")
        if not version or version == "None":
            continue
        if version_tuple(version) <= maximum:
            out.add(instruction["opname"])
    return sorted(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--vk-xml", type=Path, required=True)
    ap.add_argument("--spirv-grammar", type=Path, required=True)
    args = ap.parse_args()

    vk = vulkan_core_commands(args.vk_xml)
    spv = spirv_core_instructions(args.spirv_grammar)

    print("VULKAN 1.4 CORE COMMANDS")
    for name in vk:
        print(name)
    print()
    print("SPIR-V 1.6 REVISION-7 CORE INSTRUCTIONS")
    for name in spv:
        print(name)


if __name__ == "__main__":
    main()
