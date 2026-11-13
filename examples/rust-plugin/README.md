# Example plugin: Storm Palette Pack

A minimal Rust plugin for the Caelestia Storm shell. It exposes three colour
schemes that show up in **Settings → Wallpaper & style → Colours → Plugin schemes**.

## Protocol

A plugin is just an executable that answers two commands:

| Command   | Output |
|-----------|--------|
| `info`    | `{"name": "...", "description": "...", "version": "...", "capabilities": ["schemes"]}` |
| `schemes` | `[{"id": "...", "name": "...", "seed": "#rrggbb", "mode": "dark", "variant": "tonalspot"}]` |

`seed` is a single colour; the shell expands it into the full Material palette
(plus terminal/app colours) with `scripts/scheme-from-seed.py` and applies it the
same way `caelestia scheme set` does.

`mode` (`dark`/`light`) and `variant` (`tonalspot`, `vibrant`, `expressive`,
`fidelity`, `fruitsalad`, `monochrome`, `neutral`, `rainbow`, `content`) are optional
and default to the current ones.

## Build and install

```sh
cargo build --release
mkdir -p ~/.config/caelestia/plugins
cp target/release/storm-palette-pack ~/.config/caelestia/plugins/
```

Then open Settings → Plugins and hit **Rescan plugins** (or restart the shell).
A plugin can also be a directory containing an executable named `plugin`.

## Sharing

Settings → Plugins exports the installed plugin as `~/Downloads/caelestia-plugin-<id>.stormpack`
(a zip with a custom extension) and imports it back on another machine.
