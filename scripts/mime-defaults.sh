#!/bin/sh
# Lists the default handlers for a curated set of MIME types / URI schemes, and lets you change them.
#   mime-defaults.sh list
#     -> one line per type: <type> <TAB> <current desktop id> <TAB> <space separated registered ids>
#   mime-defaults.sh set <type> <desktop id>
#     -> writes ~/.config/mimeapps.list through xdg-mime

types="x-scheme-handler/https x-scheme-handler/mailto x-scheme-handler/tg x-scheme-handler/tonsite x-scheme-handler/magnet inode/directory text/plain video/mp4 audio/mpeg image/png application/pdf"

case "$1" in
    list)
        for type in $types; do
            current=$(xdg-mime query default "$type" 2>/dev/null)
            registered=$(gio mime "$type" 2>/dev/null | awk '/^Registered applications:/{f=1;next} /^Recommended applications:/{f=0} f && NF {gsub(/^[ \t]+/,""); printf "%s|", $0}')
            [ -n "$current$registered" ] || continue
            printf '%s\t%s\t%s\n' "$type" "$current" "$registered"
        done
        ;;
    set)
        type="$2"
        id="$3"
        [ -n "$type" ] && [ -n "$id" ] || exit 2
        xdg-mime default "$id" "$type" || exit 1
        ;;
    *)
        echo "usage: mime-defaults.sh list|set <type> <desktop-id>" >&2
        exit 2
        ;;
esac
