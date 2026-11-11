<h1>
  <img src="./assets/storm-logo.png" width="40" alt="logo" align="absmiddle" /> Caelestia Storm
</h1>

A personal rice built on top of [caelestia-dots/shell](https://github.com/caelestia-dots/shell) —
a fork of the Quickshell config with a reworked left bar and a workspace overview.

![Caelestia Storm](./preview.png)

Everything that differs from upstream is documented in [`LOCAL-CHANGES.md`](./LOCAL-CHANGES.md).

## What's changed

**Bar (left panel by default)**
- one cell per workspace, with the real app icon (from the `.desktop` entry) instead of a dot;
- the focused window gets a glow that follows the icon's silhouette (`MultiEffect` shadow);
- the status block shows the current keyboard layout (`us`/`ru`), a microphone mute toggle, the
  network icon (a `vpn_lock` globe while the traffic goes through a tunnel) and a power button;
- the bar can sit on the **left, right, top or bottom** (the code supports all four, only
  *left* is selectable for now) — Settings → Taskbar → Position;
- clicking the **clock** toggles 24h/12h, clicking the **mic** mutes it;
- `Alt+J` hides/shows the whole taskbar.

**Super / launcher**
- the stock caelestia search, with a 2×5 workspace grid above it:
  - live window previews (`ScreencopyView`), drag a window onto another workspace to move it;
  - arrow keys move the selection (`↑/↓` by rows, `←/→` by one), `Enter` jumps to the workspace
    (or focuses its window), the scroll wheel pages through workspace groups;
- on the right: a compact *Keep awake* card and *Quick toggles*, where the volume and
  brightness sliders live (click the speaker icon to mute — volume drops to 0 % and back);
- the stock volume/brightness OSD is disabled — everything happens in the launcher;
- the search falls back to a plain substring match when the C++ searcher returns nothing,
  `Enter` launches the highlighted app, and the panel content is pre-built so opening is instant;
- the dashboard (Dashboard / Media / Performance / Weather / **Notifications**) expands only
  together with the launcher; the notifications tab has its own cards, a counter, clear-all
  and an auto-sized pane (plain-text excerpts, max 30 entries — cheap to render);
- clicking the weather card (dashboard or Weather tab) switches **°F** ↔ **°C**.

**Clipboard (`Super+V`)**
- a standalone panel (no search bar, no dashboard) with the `cliphist` history;
- text entries and real image thumbnails, uniform rows with a hover highlight;
- click or `Enter` copies the entry, `✕` deletes one, `delete_sweep` wipes the history.

**Other**
- *Keep awake* survives shell restarts (`~/.local/state/caelestia/idle-inhibited`);
- Nexus → About: “Caelestia Storm”, custom logo, `v2.5.0 | STORM 1.2`;
- the bar logo is the Arch mark, wallpaper is drawn by the shell.

## Install

Requires `caelestia-shell` 2.5.0 from the AUR (or a compatible version) and `quickshell-git`.

**Quick install**

```sh
curl -fsSL https://raw.githubusercontent.com/0xcds4r/caelestia-storm/main/install.sh | bash
```

The script checks dependencies, backs up the existing config
(`~/.local/state/caelestia-storm/backups/`), clones/updates the shell config, installs
`shell.json` and restarts the shell. Options: `-f` overwrite `shell.json`, `-n` don't restart.

Or from a checkout:

```sh
git clone https://github.com/0xcds4r/caelestia-storm.git
cd caelestia-storm
./install.sh
```

**Manual install**

```sh
git clone https://github.com/0xcds4r/caelestia-storm.git ~/.config/quickshell/caelestia
mkdir -p ~/.config/caelestia
cp ~/.config/quickshell/caelestia/extra/caelestia-shell.json ~/.config/caelestia/shell.json
caelestia shell -r -d
```

`extra/caelestia-shell.json` is the shell config (volume/brightness inside Quick toggles,
10 workspaces, `osd.enabled: false`, etc.).

**Hyprland keybinds.** The rice expects a few binds; add them to your Hyprland config if they
differ. For the lua-style config used by caelestia/end-4:

```lua
hl.bind("SUPER + SUPER_L", hl.dsp.global("caelestia:launcher"), { release = true }) -- launcher + overview
hl.bind("SUPER + V", hl.dsp.global("caelestia:clipboard"))                          -- clipboard panel
```

For a plain `hyprland.conf`:

```
bind  = SUPER, V, global, caelestia:clipboard
```

## Updating from upstream

The fork fully shadows the packaged config in `/etc/xdg/quickshell/caelestia`.
After updating `caelestia-shell` you have to re-sync and re-apply the patches —
see `LOCAL-CHANGES.md` for the exact steps.

## License

GPL-3.0-only, same as upstream (see `LICENSE`).
