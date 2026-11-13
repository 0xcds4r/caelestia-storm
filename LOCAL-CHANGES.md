# Local changes to the caelestia shell

This folder is a fork of `/etc/xdg/quickshell/caelestia` (copied 2026-11-11).
Quickshell prefers `~/.config/quickshell/<name>`, so the packaged config from
`/etc/xdg` is no longer read. After `pacman -Syu` (a `caelestia-shell` update)
you have to re-sync and re-apply the patches below.

## 1. `modules/bar/components/workspaces/Workspace.qml`

- `hasWindows` is hard-coded to `false` — the second row of window icons is gone,
  one cell per workspace.
- The `Loader { id: windows }` block (window icon list) was removed.
- `iconToplevel` (the active window of the workspace, otherwise the last one) and
  `appIcon` (`Icons.getAppIcon(class)` — the real icon from the `.desktop` entry)
  were added.
- `appIconComponent` (an `Image`) was added, and `indicator.sourceComponent` now
  returns: occupied workspace → app icon, otherwise shape/text/icons per `displayType`.
- The active workspace is highlighted with a `MultiEffect` shadow (shadowScale 1.24,
  shadowColor `m3primary`) on the icon container, only while `focused` — the outline
  follows the icon's own silhouette instead of drawing a pill over it.
- `import QtQuick.Effects` was added.

## 2. `modules/bar/components/workspaces/Workspaces.qml`

`Hypr.toggleSpecial("special")` was removed from `MouseArea.onClicked` — clicking the
already active workspace no longer opens/closes the special workspace (and no longer
shows its star). Such a click is a no-op now.

## 3. Workspace overview (new module)

`modules/overview/WorkspaceOverview.qml` — a 2×5 grid of workspaces with live window
previews (a `ScreencopyView` per Wayland toplevel), drag & drop of windows between
workspaces (`hl.dsp.window.move`), click on a window (focus) and on a workspace (jump).

- Previews are clamped into their cell, rounded with `Mask` (`layer.effect`), and sit on
  an opaque black backdrop (the cell background is black too when the workspace has
  windows).
- Window geometry is computed relative to the monitor's *usable* area (`reserved` from
  Hyprland), so a window fills the whole cell — no bar-shaped cut-out.
- The workspace number is only drawn for empty workspaces (`hasWindows(ws)`) — otherwise
  it bled through translucent windows (Hyprland puts the backdrop into the toplevel buffer).
- The active window of the current workspace gets a bold 3px outline (`activeWindowAddress`
  via `focusHistoryID`); the mask, backdrop and outline all use `Tokens.rounding.large`.

Navigation (`modules/launcher/Content.qml` + `WorkspaceOverview.qml`):

- `←/→` — previous/next window, `↑/↓` — by grid columns;
- `Enter` — jump to the selected workspace: focus its window if there is one, otherwise
  just switch workspace; the launcher closes;
- mouse wheel — pages through workspace groups (1–10, 11–20, …);
- the selection moves across all cells, including empty ones;
- changing the workspace with keybinds (`CTRL+SUPER+←/→`, etc.) while the overview is open
  resets the page and moves the selection to the active workspace;
- `hl.dsp.focus({ window })` makes Hyprland warp the cursor to the screen centre, so window
  focus and the cursor restore are sent in a single message
  (`Hypr.extras.batchMessage`: `dispatch focus` + `dispatch cursor.move`) — no visible jump.
  Switching workspace does not warp, so nothing is needed there.

`modules/launcher/Content.qml`:

- `readonly property bool showOverview: search.text.length === 0`;
- `WorkspaceOverview` was added to `listWrapper` (visible while the search is empty) and
  `ContentList` is hidden; `listWrapper` sizes switch between grid and list;
- clicking a workspace closes the launcher (`screenState.launcher = false`);
- `Keys.onReturnPressed` on the search bar was removed: it swallowed Return before the
  `TextInput` could emit `accepted`, so Enter never launched the highlighted app. Overview and
  clipboard modes are handled inside `onAccepted` instead;
- the search field takes focus every time the launcher opens (`forceActiveFocus()` in the
  `launcher` change handler) — with the always-alive content the `Component.onCompleted` focus
  grab only ran at shell start, which made Esc/typing flaky;
- the query is cleared when the launcher *opens* (not when it closes): clearing on close made
  the workspace overview pop up during the close animation while a search was running;
- the dashboard is hidden while a search is running (`onTextChanged` → `dashboard = launcher && text === ""`).

Result: `SUPER` opens the stock caelestia launcher (search at the bottom); while the query
is empty the workspace grid is shown above it, and typing switches back to the app list.

## 4. Utilities inside the launcher

- `modules/overview/UtilitiesPanel.qml` (new) — a wrapper over `qs.modules.utilities.cards.Toggles`
  with its own `PersistentProperties` (`reloadableId: "overviewUtilities"`).
- `modules/overview/KeepAwakeCard.qml` (new) — an own Keep awake card with a controllable
  height: it receives `overview.cellHeight` so it matches the first cell row. The stock card
  is disabled (`utilities.cards.keepAwake: false`).
- `modules/utilities/cards/Toggles.qml` — volume and brightness rows were added to the
  Quick toggles card (`StyledSlider`, mouse wheel), the monitor comes from
  `Brightness.getMonitorForScreen(screenState.modelData)`. Clicking the speaker icon mutes:
  `Audio.toggleMute()` remembers the volume, sets it to 0 and mutes; a second click restores
  the previous level (the slider and `%` show 0 %). The card got a `minHeight` property so
  its bottom edge lines up with the second cell row.
- `services/Audio.qml` — `toggleMute()` added.
- `modules/launcher/Content.qml` — on an empty query a full-width `Row` is shown: the
  workspace grid on the left, utilities on the right.
- `shell.json`: `utilities.cards.recorder: false` (Screen recorder card removed),
  `osd.enabled: false` (the volume/brightness OSD is disabled, everything lives in the launcher).
- `modules/drawers/Interactions.qml` — hovering the corner no longer opens utilities
  (`screenState.utilities = showUtilities` → no-op); the `caelestia:utilities` shortcut still
  opens the panel standalone.

## 4b. Notifications tab in the dashboard

- `modules/dashboard/NotificationsTab.qml` (new) — a tab with the active notifications.
  The cards are custom (icon / summary / body / app name / time / close button) instead of
  the stock `Notification.qml`: its text cross-fade glitched when the card width was bound
  to the list width (title drawn twice on top of itself). Cards fill the pane width, a
  counter and a clear-all button sit in the header, plus an empty state. The pane height
  follows the content (`implicitHeight` of the column, list capped at 460 px and scrolls).
  Cost control: at most 30 entries, summary/body rendered as short **plain-text** excerpts
  (120/220 chars) instead of markdown, `cacheBuffer: 0` — long notifications used to make the
  tab lag badly.
- `modules/dashboard/Content.qml` — the tab is added to `dashboardTabs`
  (icon `notifications`, always enabled).

## 4c. Clipboard panel (Super+V)

- `modules/overview/ClipboardPanel.qml` (new) — clipboard history from `cliphist list`
  (first 60 entries), uniform rows: text is two-line elided, image entries get a real
  thumbnail (`cliphist decode` into `/tmp/caelestia-clip/<id>.png`, decoded lazily) and a
  `PNG 703×616 · 97 KiB` label. Click or `↑/↓` + `Enter` copies via `wl-copy`; the `✕` on a
  row deletes that entry (`cliphist list | awk | cliphist delete`), the `delete_sweep` icon
  in the header wipes all (`cliphist wipe`); `Delete` removes the selected row, `Esc` closes.
  No search input in this mode — the launcher's search bar is hidden. Rows have a hover
  highlight (`m3surfaceContainerHighest`).
- `components/ScreenState.qml` — new `clipboardMode` flag.
- `modules/Shortcuts.qml` — global shortcut `caelestia:clipboard`
  (`Super+V`): opens the launcher in clipboard mode, again — closes it.
- `modules/launcher/Content.qml` — in clipboard mode the overview, app list and search bar
  are hidden and the panel is shown; keyboard focus is moved to it.
- `modules/launcher/services/Apps.qml` — `fallback()`: if the C++ searcher returns no results
  for a non-empty query, a plain case-insensitive substring match over
  `DesktopEntries.applications` is used, so a search never comes back empty when the app exists.
- `modules/launcher/Content.qml` — live previews start 220 ms after the launcher opens
  (`previewsLive`), so the open animation is not competing with screencopy startup.
- `modules/dashboard/Wrapper.qml` — the dashboard content is kept alive after the first open
  (`wasOpened`); rebuilding the calendar/media/performance panes on every open was the main
  source of the sluggishness.
- `modules/launcher/Wrapper.qml` — the loader is `active: true` again: the launcher content is built
  once at startup, so opening it is just an animation (live previews are still gated by
  `live: screenState.launcher`). Costs ~60 MiB RSS.
- `modules/launcher/Wrapper.qml` — passes the flag through and keeps the dashboard closed
(`dashboard = launcher && !clipboardMode`), so the clipboard is a standalone panel.
On close the flag is cleared by a 280 ms timer *after* the drawer finished hiding, otherwise
the normal launcher flashed during the close animation.

## 5. Recorder state does not freeze

`services/Recorder.qml` — the `pidof` poll runs while `refCount > 0 || props.running`, so the
recording state and timer keep updating when no card is on screen. `start()`/`stop()` are
guarded against double invocation (the CLI toggles when a recording already exists), and the
poll never spawns the CLI while `commandProc` is still running.

## 6. Keep awake survives a shell restart

`PersistentProperties` in this version does not write state to disk (no file exists), so
`IdleInhibitor` was reset on every shell restart. `IdleState.qml` (instantiated in `shell.qml`)
writes `~/.local/state/caelestia/idle-inhibited` on change and restores it on startup.
In `KeepAwakeCard` the `onToggled` handler does not write unless the value actually differs
(protection against binding echo).

## 7. Settings → About branding

`modules/nexus/pages/AboutPage.qml` — the hero title is "Caelestia Storm", the version line is
`v2.5.0 | STORM 1.0`, and `AnimatedLogo` was replaced with an `Image`
(`assets/storm-logo.png`, 128×128).

## 8. Dashboard only together with Super

- `shell.json`: `dashboard.showOnHover: false` — the top panel no longer expands on edge hover.
- `modules/launcher/Wrapper.qml`: a `Connections` block on `screenState` keeps
  `dashboard = launcher`.
- `modules/drawers/Interactions.qml`: the dashboard hover block *and* the
  `onContainsMouseChanged` reset only run when `dashboard.showOnHover` is enabled.
  Previously `screenState.dashboard = showDashboard` ran on every mouse move with
  `showOnHover: false`, so the panel opened by the launcher was closed again a few
  milliseconds later — that's why it "sometimes didn't appear".

## 8b. Launcher dismisses tray popouts

`modules/launcher/Wrapper.qml` — when the launcher opens, `panels.popouts.hasCurrent = false`
and `panels.bar.closeTray()` are called, so an open tray menu (SNI popout) no longer stays on
top of the overview.
`modules/drawers/Interactions.qml` — while `screenState.launcher` is true, hovering the bar no
longer calls `bar.checkPopout()`, so tray popouts/tooltips don't render behind the launcher.

## 8c. Taskbar position (left / right / top / bottom)

- `services/BarPos.qml` (new) — `position`, kept in `~/.local/state/caelestia/bar-position`
  (the C++ config is packaged, so no new key there); derived `vertical`, `onLeft/onRight/onTop/onBottom`.
  `set()` only writes the state file and updates the property: every consumer is bound to `BarPos`,
  so the bar re-lays itself out in place (no shell restart, no lost popouts/drawers).
- `modules/bar/BarWrapper.qml` — orientation aware: the thickness animates on the width axis for a
  vertical bar and on the height axis for a horizontal one.
- `modules/bar/Bar.qml` — `GridLayout` (`columns: vertical ? 1 : -1` / `rows: vertical ? -1 : 1`),
  axis-aware padding, spacer fill, entry margins and popout/wheel coordinates.
- `modules/bar/components/StatusIcons.qml`, `Tray.qml`, `Clock.qml`, `ActiveWindow.qml` — horizontal
  variants (`GridLayout`/`RowLayout`, axis-aware sizes, rotation and popout centres) positioned with
  plain `x`/`y` bindings. Conditional anchors (`anchors.left: cond ? item : undefined`) must not be
  used here: assigning `undefined` does not detach an anchor at runtime, so a live position switch
  collapsed the icon rows (the status pill and tray lost their icons).
- `modules/bar/components/workspaces/Workspaces.qml` — a `Row` of `Workspace` delegates for the
  horizontal pill with explicit sizes and a per-cell `MouseArea` declared *after* the delegate so it
  actually receives the click. The vertical content is hidden in horizontal mode
  (`visible: root.vertical`) — it used to keep rendering and produce duplicate icons. No extra
  highlight/background is drawn: the active workspace is shown by its own icon only
  (`OccupiedBg`/`GapMarkers`/`ActiveIndicator` stay vertical-only, their geometry is built on
  `LazyListView.layoutY/preferredHeight`).
- `modules/drawers/Regions.qml` — the click-through mask is XOR'd with the window, so the base region
  has to cover the screen *without* the bar's edge; the insets are now computed per side from
  `BarPos`. The base region previously assumed a left bar, so a horizontal bar (and every empty
  workspace, where `dragMaskPadding` is 80) landed inside the click-through area and the whole bar
  ignored clicks. Child regions are offset from the bar side (`bar.implicitHeight` for a horizontal
  bar) and the popout region shrinks on the height axis when the bar is horizontal.
- `modules/bar/popouts/ClipWrapper.qml` — orientation aware: on a horizontal bar the popout is
  centred on the hovered entry's x and slides down from the bar (`height` animation) instead of being
  pinned to the left edge and positioned by `y`. The position is clamped so the whole popout
  background (which is a little wider than the content) stays on screen.
- `modules/drawers/ContentWindow.qml` — the popout background's extra width (deform padding) is
  added on the left only for a vertical bar (so the panel tucks under the bar) and split evenly for a
  horizontal one, so the popout content is centred in its background.
- `modules/bar/Bar.qml` — `checkPopout()` hit-tests status icons by their own geometry (the
  `GridLayout`'s width lagged behind its children, so `childAt` missed them in horizontal mode).
- `modules/bar/popouts/Wrapper.qml` — the wrapper now takes its own width/height from the content
  (`width/height: nonAnim*`). It is positioned with plain `x`/`y`, so without this it stayed 0x0 and
  the popout content was centred around a zero-size origin — the panel showed, but its contents were
  pushed half outside, i.e. "half empty".
- `modules/bar/popouts/ClipWrapper.qml` — the child wrapper is positioned with `x`/`y` bindings
  instead of conditional anchors; assigning `undefined` to `anchors.top`/`verticalCenter` collapsed
  the wrapper's height to 0.
- `modules/bar/popouts/ActiveWindow.qml` — width falls back to the preview size (when
  `Hypr.activeToplevel` was momentarily null the implicit width went negative and the popout
  rendered invisible). `Bar.checkPopout()` additionally only opens this popout when
  `Hypr.activeToplevel` exists: Quickshell only learns the active window from Hyprland *events*, so
  right after a shell restart (with a window already focused) it is `null` and the popout was a
  large empty panel with just an icon.
- `modules/drawers/Interactions.qml` — `onPressed` also calls `bar.checkPopout()`, so the entries
  open on click and not only on hover (hover was unreliable and left the bar dead in horizontal mode).
- `modules/drawers/ContentWindow.qml` — panel blob `y` offset follows the bar (`panel.y + bar.implicitHeight`
  for a horizontal bar), otherwise the dashboard/launcher background stayed as an empty strip under the bar.
- `modules/drawers/ContentWindow.qml`, `Panels.qml`, `Interactions.qml` — bar slot placed with explicit
  geometry, panels inset from the bar side (left/right/top/bottom), hover region and popout coordinate
  follow the orientation; the blob background cut (`borderLeft`/`borderTop`) follows the bar's side.
- `modules/drawers/Exclusions.qml` — the exclusive zone (the screen area the bar reserves) is moved to
  the bar's edge: top/bottom for a horizontal bar, left/right for a vertical one.
- `modules/bar/components/Tray.qml` — the collapsed (compact) tray only applies to a vertical bar; in a
  horizontal one the icons overflowed the reserved width and overlapped the neighbouring entries.
- `modules/nexus/pages/panels/TaskbarPanel.qml` — `SelectRow` for the position with `Left` and `Top`
  (bottom/right are implemented but not exposed).
- `modules/drawers/Interactions.qml` — missing `qs.services` import added (`BarPos`).

## 8d. Weather card toggles °F/°C

`modules/dashboard/dash/SmallWeather.qml` and `modules/dashboard/WeatherTab.qml` (the big card) —
a `MouseArea` over the card switches
`GlobalConfig.services.weatherUnits` between `Fahrenheit` and `Celsius` (same value the Nexus
Language & Region page writes).

## 8e. Clock toggles 24h/12h

`modules/bar/components/Clock.qml` — a `MouseArea` over the clock switches
`GlobalConfig.services.clockFormat` between `TwelveHour` and `TwentyFourHour`.

## 8f. Hide the taskbar (Alt+J)

- `services/BarPos.qml` — session-only `hidden` flag + `toggleHidden()`.
- `modules/bar/BarWrapper.qml` — `shouldBeVisible`/`exclusiveZone` respect `BarPos.hidden`, so the
  bar collapses and windows take the freed space.
- `modules/Shortcuts.qml` — global shortcut `caelestia:barToggle`.
- Hyprland bind: `ALT + J → hl.dsp.global("caelestia:barToggle")`.

## 9. `~/.config/caelestia/shell.json`

- `bar.workspaces.activeIndicator: false` — the stock filled pill indicator is disabled,
  otherwise it repaints/covers the app icon;
- `bar.workspaces.shown: 10`, `bar.statusIcons`: `kbLayout` + `microphone` on,
  `lockStatus`/`bluetooth` removed;
- `modules/bar/components/StatusIcons.qml`: a click router on the pill — clicking the
  microphone entry toggles mic mute (`Audio.toggleMicMute()`), other entries stay as before;
- `services/Tunnel.qml` (new) — polls `ip route get 1.1.1.1` every 5 s and reports whether the
  default route goes through a tunnel (`tun*`, `tap*`, `wg*`, `ppp*`, tailscale, …);
- `modules/bar/components/StatusIcons.qml`: the network icon becomes a `vpn_lock` globe while
  `Tunnel.active`, and the pill routes clicks to the entry under the cursor (mic = mute toggle);
- `services/Hypr.qml`: `kbLayout` falls back to the last known value — `activeKeymap` is
  briefly empty while Hyprland reloads devices (caps/num lock, layout switch), which used to
  show `??`. The layout list parser also accepts descriptions with commas/digits now;
- `utilities.toasts.kbLayoutChanged: false` — no popup on layout change.

## How to update (after a package update)

```sh
cp -a /etc/xdg/quickshell/caelestia/. ~/.config/quickshell/caelestia/
# then re-apply the sections above
```

Or drop the fork entirely and go back to the stock config:
`rm -rf ~/.config/quickshell/caelestia && caelestia shell -r -d`

## Plugins

- **Rule:** whenever the plugin protocol grows, extend `examples/rust-plugin/src/api.rs` in the same
  change (builders, parsers, docs in its README) so plugin authors get the helper immediately.
- Plugin API: `info`, `schemes`, `actions` + `run <action>`, `widgets` (a list of taskbar items, each
  clickable via `run click <widget id>`; the old single `widget` still works), and windows: `window` returns a descriptor (`title`, `pages[]` with `label`/`icon` and
  `sections[]`) rendered by `modules/nexus/PluginWindow.qml` with the shell's own components
  (`section`, `text`, `info`, `toggle`, `button`, `textfield`, `slider`, `choice`). Control changes
  are sent as `event <id> <json>`; the window re-reads the descriptor when the plugin is done. `scripts/plugins-widgets.sh` polls widget-capable plugins every minute; `Plugins.widgets`
  feeds the taskbar, `Plugins.widgetSignature` keeps the bar's repeater stable so a poll only updates
  the widget text instead of rebuilding the bar.
- `scripts/plugins-scan.sh` + `services/Plugins.qml` — plugins are executables discovered in
  `~/.config/caelestia/plugins` and `~/.local/share/caelestia/plugins` (a bare executable, or a
  directory with an executable named `plugin`). Each is asked for `info` and `schemes` JSON; the
  scan runs through a single shell process and is exposed as `Plugins.plugins` / `Plugins.schemes`.
- `scripts/scheme-from-seed.py` — expands a seed colour into the full palette via
  `caelestia.utils.material.generator.gen_scheme`, writes `scheme.json` and runs
  `apply_colours()`, so plugin schemes theme terminals/GTK/Qt just like `caelestia scheme set`.
  The stored scheme name is `dynamic` because the CLI only accepts names that resolve to a scheme
  file shipped in the read-only package.
- Web views: `components/WebSnapshot.qml` + `scripts/webview-snapshot.sh` render a page with
  headless Chromium into a PNG and refresh it (default 60 s). Embedding QtWebEngine directly aborts
  the shell — Chromium wants argv that Quickshell's launcher does not pass ("Argument list is empty
  … base::CommandLine cannot be properly initialized") — so plugin web views are snapshots.
  Available as the `webview` window row and as desktop cards with a `url`.
- `modules/background/DesktopWidgets.qml` — desktop widgets from the `desktop` plugin command:
  cards (`icon`, `title`, `text`, `subtext`, `width`) placed by `anchor`
  (`top-left`/`top-right`/`bottom-left`/`bottom-right`/`center`) + `margin`, or absolute `x`/`y`.
  They live in the background window, so they sit under every window on the wallpaper.
- `modules/nexus/pages/PluginsPage.qml` (page index 5, previously a placeholder) — installed plugins
  with a per-plugin toggle, a trash button (inline "Delete …?" confirmation), action buttons and
  import / rescan.
  A plugin directory may ship `icon.{png,svg,jpg,jpeg,webp}` (or `<id>.<ext>` next to a bare
  executable); `scripts/plugins-scan.sh` reports it and the card shows it on the left.
- `scripts/plugin-unpack.py` + `scripts/plugin-remove.py` — `.stormpack` is a plain zip with a custom
  extension, laid out as `<plugin-id>/plugin …`. Import extracts it into
  `~/.config/caelestia/plugins` (rejecting absolute paths and `..`), restores the executable bit and
  rescans; removal deletes the plugin file/directory from the plugin directories only.
  The import dialog uses the shell's `FileDialog` with a `*.stormpack` filter.
  `scripts/plugin-pack.py` is kept as a CLI helper for packing plugins (`--all` or one id).
- `modules/nexus/pages/wallandstyle/ColourSelect.qml` — "Plugin schemes" chips; the applied one is
  tracked in `UiPrefs.appliedPluginScheme` and cleared when a built-in scheme is picked.
- `services/UiPrefs.qml` — persists `disabledPlugins` and `appliedPluginScheme`.
- `examples/rust-plugin/` — buildable Rust example (`cargo build --release`) with `src/api.rs`, a
  dependency-free helper module: JSON `Fields` builder, `Plugin`/`Scheme`/`Action`/`Widget`/
  `Desktop`/`Window`+`Page`+`Row` builders, `Event` parsing and a `key=value` `State` store.

## Colour scheme picker

`modules/nexus/pages/wallandstyle/ColourSelect.qml` — the "Colours" sub-page of Wallpaper & style was
a placeholder, now it picks the scheme:

- scheme chips (`dynamic` + every scheme shipped with `caelestia scheme`) and flavour chips, shown
  only for schemes that have more than one flavour;
- variant dropdown (`tonalspot` … `content`) and a "random scheme" row;
- everything runs through `caelestia scheme set`. `-m` is passed only when the scheme cannot imply
  the mode itself — flavours like catppuccin `latte`/rosepine `dawn` are light by definition, and
  forcing `-m dark` produced mismatched palettes.
- `services/Colours.qml` now also exposes `variant` (read from `scheme.json`).

## Drag-to-open switch

`services/UiPrefs.qml` (new) — small persisted preferences (`~/.local/state/caelestia/ui-prefs.json`),
currently `panelsDragOpen` (default `true`).

- `modules/drawers/Interactions.qml` — the dashboard (top) and launcher (bottom) drag handlers are
  gated on it.
- `modules/drawers/ContentWindow.qml` — `dragMaskPadding` returns 0 when the switch is off, so the
  screen edges stay fully clickable instead of reserving a dead strip for dragging.
- `modules/nexus/pages/PanelsPage.qml` — new "Behaviour" section with the toggle above the panel list.

## Weather retry

`services/Weather.qml` — `fetchWeatherData()` got an error callback: open-meteo answers `503` when it
rate-limits, and without a retry the dashboard stayed on "No weather" until the next hourly refresh.
Failed requests now retry with a 5 → 30 minute backoff (`fetchRetries`, `retryTimer`), reset on success.

## Verification checklist (read before touching the bar)

Learned the hard way — never leave the machine in a half-tested state.

- **Key injection:** send explicit press *and* release (`ydotool key 1:1`, wait, `ydotool key 1:0`).
  A bare `ydotool key 1` can emit only the release, which looks exactly like a dead Escape key.
  Never leave a virtual device with stuck keys; if keys misbehave, re-send the releases first and
  only then blame the config.
- **Shell restarts:** batch edits, then `caelestia shell -k` + `caelestia shell -d` once. Do not
  restart after every one-line change.
- **Always restore the working state before reporting done:**
  - `~/.local/state/caelestia/bar-position` = `left`;
  - keyboard layout back to `us` (`hyprctl switchxkblayout <main-kbd> 0`) — clicking the layout
    popout during testing switches it for real;
  - no drawers/popouts left open;
  - `hyprctl monitors` → `reserved` matches the bar side;
  - screenshot both orientations when the bar layout changed.
