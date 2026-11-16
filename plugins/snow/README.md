# StormSnow

A Caelestia Storm plugin that makes it snow on the desktop.

It depends on the shared helper crate `storm-plugin-api` (`plugins/api`, path dependency):
everything the protocol needs — JSON builders, row types, event parsing, the `key=value` state store —
comes from there.

The shell does the drawing (`modules/background/Snow.qml` + a fragment shader on the
background layer, behind the windows); this executable only owns the settings:

- `info` — manifest (`effects`, `window`, `actions` capabilities);
- `effects` — `{"effects": [{"type": "snow", "density": ..., "wind": ...}]}`, empty when off;
- `window` — the settings page rendered by Nexus (toggle, presets, sliders);
- `event <control> <json>` — a control changed, persisted to `~/.local/state/snow.conf`;
- `run toggle` / `run status` / `run reset` — flip, report or reset the snow.

## Install

```sh
./install.sh          # cargo build --release + install into ~/.config/caelestia/plugins/snow
```

(The crate is part of the `plugins/` cargo workspace, so the binary ends up in `plugins/target/release`.)

Then open Nexus → Plugins, find “StormSnow” and press the open button for the settings page. The plugin
is enabled by default and keeps no taskbar widget — everything lives in that window.

## Presets

| Preset   | Density | Wind | Speed | Size |
|----------|---------|------|-------|------|
| Light    | 0.18    | 0.15 | 0.75  | 0.85 |
| Even     | 0.35    | 0.30 | 1.00  | 1.00 |
| Blizzard | 0.75    | 0.85 | 1.60  | 1.15 |

Moving any slider switches the preset to Custom. Settings live in the plugin's own state file,
so they survive shell restarts and plugin updates.

## Notes

- The snow is drawn on the wallpaper layer, so it falls *behind* windows (like the reference
  GNOME extension does on the desktop); it never covers your windows and takes no input.
- Flakes are procedural (three shader layers of hashed cells), so density, wind and speed
  change without rebuilding anything. The shader is precompiled:
  `/usr/lib/qt6/bin/qsb --qt6 -o snow.frag.qsb snow.frag` (needs `qt6-shadertools`).
