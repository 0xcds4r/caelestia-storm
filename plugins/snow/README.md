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
- `run toggle` / `run status` / `run reset` — flip, report or reset the snow;
- `binds` — one global shortcut, `CTRL + SUPER + SHIFT + S`, toggles the snow (`run bind toggle`).

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

- By default the snow is drawn on the wallpaper layer, so it falls *behind* windows. The
  “Above the windows” toggle switches the effect to the overlay layer: a full-screen click-through
  surface above everything, including fullscreen windows.
- The overlay needs one Hyprland rule, otherwise the catch-all `xray` layerrule blurs it:

  ```lua
  hl.layer_rule({ match = { namespace = "caelestia-effect-overlay" }, blur = false, xray = false })
  ```
- The snowfall itself is `shaders/snow.frag`, shipped with the plugin and rendered by the shell's
  generic shader effect. Its uniforms are `density`, `wind`, `flakeSize` and `strength`; the fall
  speed is the effect's `timeScale`. Changing any of them writes the value straight into the
  running shader, nothing is rebuilt.
- Rebuild the baked shader after editing the source (needs `qt6-shadertools`):

  ```sh
  cd shaders && qsb --qt6 -o snow.frag.qsb snow.frag && ./../install.sh
  ```
