#!/bin/sh
# Renders a web page to a PNG with headless Chromium and prints the image path.
# QtWebEngine cannot be embedded in this Quickshell build (Chromium needs argv that the launcher
# does not provide), so "web views" are periodically refreshed snapshots.
# Usage: webview-snapshot.sh <url> [width] [height]
url="$1"
width="${2:-900}"
height="${3:-500}"

[ -n "$url" ] || exit 2

browser=""
for candidate in chromium chromium-browser google-chrome-stable google-chrome; do
    if command -v "$candidate" >/dev/null 2>&1; then
        browser="$candidate"
        break
    fi
done
[ -n "$browser" ] || exit 3

cache="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia/webviews"
mkdir -p "$cache"

key=$(printf '%s|%sx%s' "$url" "$width" "$height" | md5sum | cut -c1-16)
out="$cache/$key.png"
tmp="$cache/$key.tmp.png"

timeout 25 "$browser" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
    --window-size="${width},${height}" --screenshot="$tmp" "$url" >/dev/null 2>&1

if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    exit 1
fi

mv "$tmp" "$out"
echo "$out"
