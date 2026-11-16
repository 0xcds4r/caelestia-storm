#!/bin/sh
# Polls every bind-capable plugin and prints one line per plugin:
#   plugin-id <TAB> binds-json
# A plugin opts in with the "binds" capability and answers `binds` with
#   [ { "id": "toggle", "key": "CTRL + SUPER + SHIFT + S", "description": "..." } ]
disabled_file="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/disabled-plugins"
is_disabled() {
    [ -f "$disabled_file" ] && grep -qx "$1" "$disabled_file"
}

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
        is_disabled "$id" && continue

        info=$("$exe" info 2>/dev/null | tr -d '\n')
        case "$info" in
            *'"binds"'*) ;;
            *) continue ;;
        esac

        binds=$(timeout 5 "$exe" binds 2>/dev/null | tr -d '\n')
        [ -n "$binds" ] && [ "$binds" != "[]" ] || continue

        printf '%s\t%s\n' "$id" "$binds"
    done
done
