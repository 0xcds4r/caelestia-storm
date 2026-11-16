#!/bin/sh
# Builds the Snow plugin and installs it into ~/.config/caelestia/plugins/snow.
set -e

here=$(cd "$(dirname "$0")" && pwd)
dest="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/plugins/snow"

command -v cargo >/dev/null 2>&1 || {
    echo "cargo is required: pacman -S rust" >&2
    exit 1
}

# the binaries land in the workspace target directory (plugins/target)
cargo build --release --manifest-path "$here/Cargo.toml"
mkdir -p "$dest"
install -m755 "$here/../target/release/snow" "$dest/plugin"
echo "installed $dest/plugin"
