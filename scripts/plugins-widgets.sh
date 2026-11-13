#!/bin/sh
# Polls every widget-capable plugin and prints one line per bar widget:
#   plugin-id <TAB> widget-id <TAB> widget-json
# A plugin opts in with the "widget" capability and answers either
#   `widgets` -> [{"id": "load", "icon": "speed", "text": "0.42"}, ...]   (several widgets)
#   `widget`  -> {"icon": "...", "text": "..."}                           (a single unnamed one)
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

        widgets=$(timeout 5 "$exe" widgets 2>/dev/null | tr -d '\n')
        if [ -n "$widgets" ] && [ "$widgets" != "[]" ]; then
            printf '{ "plugin": "%s", "widgets": %s }\n' "$id" "$widgets"
            continue
        fi

        widget=$(timeout 5 "$exe" widget 2>/dev/null | tr -d '\n')
        [ -n "$widget" ] || continue

        printf '{ "plugin": "%s", "widgets": [%s] }\n' "$id" "$widget"
    done
done
