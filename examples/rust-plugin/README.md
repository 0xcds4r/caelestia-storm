# Example plugin: Storm Palette Pack

A minimal Rust plugin for the Caelestia Storm shell. It exposes three colour
schemes that show up in **Settings → Wallpaper & style → Colours → Plugin schemes**.

## Protocol

A plugin is just an executable that answers two commands:

| Command | Output |
|---------|--------|
| `info` | `{"name": "...", "description": "...", "version": "...", "capabilities": ["schemes", "actions", "widget"]}` |
| `schemes` | `[{"id": "...", "name": "...", "seed": "#rrggbb", "mode": "dark", "variant": "tonalspot"}]` |
| `actions` | `[{"id": "...", "name": "..."}]` — buttons on the plugin card |
| `run <action>` | performs the action; stdout is shown as a notification |
| `widgets` | `[{"id": "load", "icon": "speed", "text": "0.42", "tooltip": "..."}]` — taskbar items, polled every minute (a single `widget` object also works) |
| `run click <id>` | sent when a taskbar widget is clicked |
| `desktop` | `{"widgets": [{"id": "...", "anchor": "bottom-right", "icon": "...", "title": "...", "text": "...", "subtext": "..."}]}` — cards on the wallpaper |
| `window` | window descriptor (see below) |
| `event <id> <json>` | a control in that window changed |

### Windows

`window` returns JSON that the shell renders with its own widgets:

```json
{
  "title": "My plugin", "icon": "tune", "width": 560, "height": 500,
  "pages": [
    { "id": "general", "label": "General", "sections": [
      { "type": "section", "text": "Behaviour" },
      { "type": "toggle", "id": "enabled", "label": "Enabled", "subtext": "…", "value": true },
      { "type": "choice", "id": "mode", "label": "Mode", "value": "auto",
        "options": [{ "value": "auto", "text": "Auto" }] },
      { "type": "slider", "id": "strength", "label": "Strength", "min": 0, "max": 100, "value": 60 },
      { "type": "textfield", "id": "name", "label": "Name", "value": "" },
      { "type": "text", "text": "Free-form paragraph" },
      { "type": "info", "label": "Version", "value": "0.3.0" },
      { "type": "button", "id": "reset", "label": "Reset", "icon": "restart_alt" }
    ] }
  ]
}
```

One page renders as a plain window; several pages get a tab strip. Every change arrives as
`event <control id> <json value>` (buttons send `true`), after which the shell re-reads `window`,
so the plugin's state is the single source of truth.

`seed` is a single colour; the shell expands it into the full Material palette
(plus terminal/app colours) with `scripts/scheme-from-seed.py` and applies it the
same way `caelestia scheme set` does.

Drop an `icon.png` (or `.svg`/`.jpg`/`.webp`) next to the binary to give the plugin a card icon.

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
