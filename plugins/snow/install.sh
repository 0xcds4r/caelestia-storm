#!/bin/sh
# Builds the StormSnow plugin and installs it into ~/.config/caelestia/plugins/storm-snow.
set -e

here=$(cd "$(dirname "$0")" && pwd)
dest="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/plugins/storm-snow"

command -v cargo >/dev/null 2>&1 || {
    echo "cargo is required: pacman -S rust" >&2
    exit 1
}

# the binaries land in the workspace target directory (plugins/target)
cargo build --release --manifest-path "$here/Cargo.toml"
mkdir -p "$dest"
install -m755 "$here/../target/release/storm-snow" "$dest/plugin"
[ -f "$here/icon.png" ] && install -m644 "$here/icon.png" "$dest/icon.png"
[ -d "$here/shaders" ] && cp -r "$here/shaders" "$dest/"
echo "installed $dest/plugin"
