# <img src="./assets/storm-logo.png" width="34" alt="logo" /> Caelestia Storm

A personal rice built on top of [caelestia-dots/shell](https://github.com/caelestia-dots/shell) —
a fork of the Quickshell config with a reworked left bar and a workspace overview.

![Caelestia Storm](./preview.png)

Everything that differs from upstream is documented in [`LOCAL-CHANGES.md`](./LOCAL-CHANGES.md).

## What's changed

**Bar (left panel)**
- one cell per workspace, with the real app icon (from the `.desktop` entry) instead of a dot;
- the focused window gets a glow that follows the icon's silhouette (`MultiEffect` shadow);
- the status block shows the current keyboard layout (`us`/`ru`) instead of caps/num and bluetooth icons.

**Super / launcher**
- the stock caelestia search, with a 2×5 workspace grid above it:
  - live window previews (`ScreencopyView`), drag a window onto another workspace to move it;
  - arrow keys move the selection (`↑/↓` by rows, `←/→` by one), `Enter` jumps to the workspace
    (or focuses its window), the scroll wheel pages through workspace groups;
- on the right: a compact *Keep awake* card and *Quick toggles*, where the volume and
  brightness sliders live (click the speaker icon to mute — volume drops to 0 % and back);
- the stock volume/brightness OSD is disabled — everything happens in the launcher;
- the dashboard (Dashboard / Media / Performance / Weather) expands only together with the launcher.

**Other**
- *Keep awake* survives shell restarts (`~/.local/state/caelestia/idle-inhibited`);
- Nexus → About: “Caelestia Storm”, custom logo, `v2.5.0 | STORM 1.0`;
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

## Updating from upstream

The fork fully shadows the packaged config in `/etc/xdg/quickshell/caelestia`.
After updating `caelestia-shell` you have to re-sync and re-apply the patches —
see `LOCAL-CHANGES.md` for the exact steps.

## License

GPL-3.0-only, same as upstream (see `LICENSE`).
