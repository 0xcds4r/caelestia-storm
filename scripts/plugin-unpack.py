#!/usr/bin/env python3
"""Install `.stormpack` plugin archives (a zip with the plugin folders inside)."""

from __future__ import annotations

import os
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path


def plugins_dir() -> Path:
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return config / "caelestia" / "plugins"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: plugin-unpack.py <archive.stormpack>", file=sys.stderr)
        return 2

    archive_path = Path(sys.argv[1]).expanduser()
    if not archive_path.is_file():
        print(f"no such file: {archive_path}", file=sys.stderr)
        return 2

    if not zipfile.is_zipfile(archive_path):
        print(f"not a valid archive: {archive_path}", file=sys.stderr)
        return 1

    destination = plugins_dir()
    destination.mkdir(parents=True, exist_ok=True)

    installed: list[str] = []

    with tempfile.TemporaryDirectory() as tmp, zipfile.ZipFile(archive_path) as archive:
        for member in archive.infolist():
            name = Path(member.filename)
            if name.is_absolute() or ".." in name.parts:
                print(f"skipping unsafe path: {member.filename}", file=sys.stderr)
                continue
            archive.extract(member, tmp)

        for entry in sorted(Path(tmp).iterdir()):
            plugin_id = entry.name
            target = destination / plugin_id

            if target.exists() and not target.is_dir():
                target.unlink()
            if target.is_dir():
                shutil.rmtree(target)

            shutil.move(str(entry), str(target))

            executable = target / "plugin" if target.is_dir() else target
            if executable.is_file():
                executable.chmod(executable.stat().st_mode | 0o111)

            installed.append(plugin_id)

    if not installed:
        print("archive contained no plugins", file=sys.stderr)
        return 1

    print(" ".join(installed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
