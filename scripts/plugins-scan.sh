#!/bin/sh
# Lists installed caelestia plugins, one per line:
#   id <TAB> executable <TAB> info-json <TAB> schemes-json
# A plugin is either an executable file inside the plugins directory or a directory
# containing an executable named "plugin".
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
        schemes=$("$exe" schemes 2>/dev/null | tr -d '\n')

        printf '%s\t%s\t%s\t%s\n' "$id" "$exe" "$info" "$schemes"
    done
done
