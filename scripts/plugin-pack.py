#!/usr/bin/env python3
"""Pack installed caelestia plugins into `.stormpack` archives.

A `.stormpack` is a plain zip file with a custom extension, laid out as
    <plugin-id>/plugin ...other files...
so it can be imported again with plugin-unpack.py.
"""

from __future__ import annotations

import argparse
import os
import sys
import zipfile
from pathlib import Path


def plugin_dirs() -> list[Path]:
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
    return [config / "caelestia" / "plugins", data / "caelestia" / "plugins"]


def discover() -> dict[str, Path]:
    found: dict[str, Path] = {}

    for directory in plugin_dirs():
        if not directory.is_dir():
            continue

        for entry in sorted(directory.iterdir()):
            if entry.name.startswith(".") or entry.name in found:
                continue

            if entry.is_dir():
                if (entry / "plugin").is_file() and os.access(entry / "plugin", os.X_OK):
                    found[entry.name] = entry
            elif entry.is_file() and os.access(entry, os.X_OK):
                found[entry.name] = entry

    return found


def write_entry(archive: zipfile.ZipFile, name: str, source: Path) -> None:
    info = zipfile.ZipInfo(name)
    info.external_attr = (0o755 if os.access(source, os.X_OK) else 0o644) << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(info, source.read_bytes())


def pack(archive: zipfile.ZipFile, plugin_id: str, entry: Path) -> None:
    if entry.is_dir():
        for path in sorted(entry.rglob("*")):
            if path.is_file():
                write_entry(archive, f"{plugin_id}/{path.relative_to(entry)}", path)
    else:
        write_entry(archive, f"{plugin_id}/plugin", entry)


def output_dir() -> Path:
    directory = Path(os.environ.get("XDG_DOWNLOAD_DIR") or Path.home() / "Downloads")
    return directory if directory.is_dir() else Path.home()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ids", nargs="*", help="plugin ids to export (default: all)")
    parser.add_argument("--all", action="store_true", help="export every installed plugin into one archive")
    args = parser.parse_args()

    plugins = discover()

    if args.all:
        targets = sorted(plugins)
        if not targets:
            print("nothing to export", file=sys.stderr)
            return 1
        path = output_dir() / "caelestia-plugins.stormpack"
        with zipfile.ZipFile(path, "w") as archive:
            for plugin_id in targets:
                pack(archive, plugin_id, plugins[plugin_id])
        print(path)
        return 0

    if not args.ids:
        print("usage: plugin-pack.py <plugin-id>... | --all", file=sys.stderr)
        return 2

    written = []
    for plugin_id in args.ids:
        entry = plugins.get(plugin_id)
        if entry is None:
            print(f"unknown plugin: {plugin_id}", file=sys.stderr)
            continue

        path = output_dir() / f"caelestia-plugin-{plugin_id}.stormpack"
        with zipfile.ZipFile(path, "w") as archive:
            pack(archive, plugin_id, entry)
        written.append(str(path))

    if not written:
        return 1

    print("\n".join(written))
    return 0


if __name__ == "__main__":
    sys.exit(main())
