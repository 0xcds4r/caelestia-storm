#!/bin/sh
# Polls every desktop-capable plugin and prints one line per plugin:
#   plugin-id <TAB> descriptor-json
# A plugin opts in with the "desktop" capability and answers `desktop` with
#   { "widgets": [ { "id": "...", "anchor": "bottom-left", "title": "...", ... } ] }
for dir in "${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/plugins" "${XDG_DATA_HOME:-$HOME/.local/share}/caelestia/plugins"; do
    [ -d "$dir" ] || continue

    for entry in "$dir"/*; do
        [ -e "$entry" ] || continue

        id=""
        exe=""
        if [ -d "$entry" ]; then
            id=$(basename "$entry")
            [ -x "$entry/plugin" ] && exe="$entry/plugin"
        elif [ -x "$entry" ]; then
            id=$(basename "$entry")
            exe="$entry"
        fi

        [ -n "$exe" ] || continue

        info=$("$exe" info 2>/dev/null | tr -d '\n')
        case "$info" in
            *'"desktop"'*) ;;
            *) continue ;;
        esac

        desktop=$(timeout 5 "$exe" desktop 2>/dev/null | tr -d '\n')
        [ -n "$desktop" ] || continue

        printf '%s\t%s\n' "$id" "$desktop"
    done
done
