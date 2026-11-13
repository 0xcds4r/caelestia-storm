#!/bin/sh
# Polls every widget-capable plugin and prints one line per plugin:
#   id <TAB> widget-json
# A plugin opts in with the "widget" capability and answers `widget` with
# {"icon": "speed", "text": "0.42"} (empty output hides the widget).
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
            *'"widget"'*) ;;
            *) continue ;;
        esac

        widget=$(timeout 5 "$exe" widget 2>/dev/null | tr -d '\n')
        [ -n "$widget" ] || continue

        printf '%s\t%s\n' "$id" "$widget"
    done
done
