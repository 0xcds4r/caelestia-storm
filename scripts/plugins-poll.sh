#!/bin/sh
# Single pass over the plugin directories for everything the shell polls every minute.
#
# Prints one line per plugin/capability, TAB separated:
#   widgets <TAB> id <TAB> json
#   desktop <TAB> id <TAB> json
#   effects <TAB> id <TAB> json
#   binds   <TAB> id <TAB> json
#
# `info` is asked once per plugin (the four capability scripts used to ask it four times) and only
# the commands a plugin actually advertises are executed.
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
        [ -n "$info" ] || continue

        case "$info" in
            *'"widgets"'* | *'"widget"'*)
                widgets=$(timeout 5 "$exe" widgets 2>/dev/null | tr -d '\n')
                if [ -n "$widgets" ] && [ "$widgets" != "[]" ]; then
                    printf 'widgets\t%s\t{"plugin":"%s","widgets":%s}\n' "$id" "$id" "$widgets"
                else
                    widget=$(timeout 5 "$exe" widget 2>/dev/null | tr -d '\n')
                    [ -n "$widget" ] && printf 'widgets\t%s\t{"plugin":"%s","widgets":[%s]}\n' "$id" "$id" "$widget"
                fi
                ;;
        esac

        case "$info" in
            *'"desktop"'*)
                desktop=$(timeout 5 "$exe" desktop 2>/dev/null | tr -d '\n')
                [ -n "$desktop" ] && printf 'desktop\t%s\t%s\n' "$id" "$desktop"
                ;;
        esac

        case "$info" in
            *'"effects"'*)
                effects=$(timeout 5 "$exe" effects 2>/dev/null | tr -d '\n')
                [ -n "$effects" ] && [ "$effects" != "[]" ] && printf 'effects\t%s\t%s\n' "$id" "$effects"
                ;;
        esac

        case "$info" in
            *'"binds"'*)
                binds=$(timeout 5 "$exe" binds 2>/dev/null | tr -d '\n')
                [ -n "$binds" ] && [ "$binds" != "[]" ] && printf 'binds\t%s\t%s\n' "$id" "$binds"
                ;;
        esac
    done
done
