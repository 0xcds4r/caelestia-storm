#!/usr/bin/env python3
"""Remove an installed plugin (file or directory) from the plugin directories."""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path


def plugin_dirs() -> list[Path]:
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
    return [config / "caelestia" / "plugins", data / "caelestia" / "plugins"]


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: plugin-remove.py <plugin-id>", file=sys.stderr)
        return 2

    plugin_id = sys.argv[1]
    if not plugin_id or plugin_id.startswith(".") or "/" in plugin_id or plugin_id in ("..", "."):
        print(f"invalid plugin id: {plugin_id}", file=sys.stderr)
        return 2

    for directory in plugin_dirs():
        target = directory / plugin_id
        if target.is_dir():
            shutil.rmtree(target)
            print(plugin_id)
            return 0
        if target.is_file():
            target.unlink()
            print(plugin_id)
            return 0

    print(f"plugin not found: {plugin_id}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
