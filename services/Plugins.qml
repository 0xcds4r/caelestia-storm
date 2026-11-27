pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import qs.services

// Rust (or any language) plugins: an executable in ~/.config/caelestia/plugins that answers
//   `info`     -> {"name": "...", "description": "...", "version": "...", "capabilities": ["schemes"]}
//   `schemes`  -> [{"id": "...", "name": "...", "seed": "#rrggbb", "mode": "dark|light", "variant": "..."}]
// Plugin schemes are expanded into a full palette by scripts/scheme-from-seed.py and applied.
Singleton {
    id: root

    property var plugins: []
    property var schemes: []
    property var widgets: []
    property var desktopWidgets: []
    property var effects: []
    property var binds: []
    // Stable key for the set of widget plugins, so the bar's repeater is not rebuilt on every poll
    property string widgetSignature: ""
    property bool scanning: false

    // Emitted after a plugin handled an event (e.g. a control in its window changed)
    signal eventFinished(string pluginId)
    // Emitted when the user disables or removes a plugin, so its windows can close
    signal pluginDisabled(string pluginId)

    readonly property var schemePlugins: root.plugins.filter(p => p.enabled && p.schemes.length > 0)

    function refresh(): void {
        if (scan.running)
            return;

        root.scanning = true;
        scan.running = true;
    }

    function isEnabled(pluginId: string): bool {
        return UiPrefs.disabledPlugins.indexOf(pluginId) === -1;
    }

    function setEnabled(pluginId: string, enabled: bool): void {
        if (!enabled)
            root.forgetPlugin(pluginId, true);

        UiPrefs.setPluginEnabled(pluginId, enabled);
        root.rebuildSchemes();

        if (enabled)
            root.refreshWidgets();
    }

    // Stops everything a plugin contributed: bar widgets, desktop widgets, windows, and (optionally)
    // the colour scheme it applied.
    function forgetPlugin(pluginId: string, restoreScheme: bool): void {
        root.widgets = root.widgets.filter(widget => widget.pluginId !== pluginId);
        root.widgetSignature = root.widgets.map(widget => widget.key).join(",");
        root.desktopWidgets = root.desktopWidgets.filter(widget => widget.pluginId !== pluginId);
        root.effects = root.effects.filter(effect => effect.pluginId !== pluginId);
        root.binds = root.binds.filter(bind => bind.pluginId !== pluginId);
        root.registerBinds();
        root.pluginDisabled(pluginId);

        if (!UiPrefs.appliedPluginScheme.startsWith(`${pluginId}:`))
            return;

        const previous = UiPrefs.previousScheme;
        UiPrefs.appliedPluginScheme = "";
        UiPrefs.previousScheme = "";
        UiPrefs.save();

        if (!restoreScheme || !previous)
            return;

        try {
            const scheme = JSON.parse(previous);
            const args = ["caelestia", "scheme", "set", "-n", scheme.name];
            if (scheme.flavour)
                args.push("-f", scheme.flavour);
            if (scheme.variant)
                args.push("-v", scheme.variant);
            if (scheme.mode)
                args.push("-m", scheme.mode);
            schemeProc.command = args;
            schemeProc.running = true;
        } catch (error) {
            console.warn("unable to restore the previous scheme:", error);
        }
    }

    function applyScheme(scheme: var): void {
        if (!scheme?.seed)
            return;

        if (!UiPrefs.appliedPluginScheme) {
            UiPrefs.previousScheme = JSON.stringify({
                name: Colours.scheme,
                flavour: Colours.flavour,
                mode: Colours.light ? "light" : "dark",
                variant: Colours.variant
            });
            UiPrefs.save();
        }

        applyProc.command = ["python3", Quickshell.shellPath("scripts/scheme-from-seed.py"), "--seed", scheme.seed, "--mode", scheme.mode ?? "dark", "--variant", scheme.variant ?? "tonalspot"];
        applyProc.running = true;

        UiPrefs.appliedPluginScheme = scheme.key;
        UiPrefs.save();
    }

    function widgetFor(key: string): var {
        return root.widgets.find(widget => widget.key === key) ?? null;
    }

    // Everything a plugin can contribute is collected by a single script pass: one process per
    // minute instead of four, and `info` is asked once per plugin instead of four times.
    function refreshPoll(): void {
        if (pollProc.running)
            return;

        pollProc.running = true;
    }

    function refreshWidgets(): void {
        root.refreshPoll();
    }

    function applyPoll(text: string): void {
        let widgets = "";
        let desktop = "";
        let effects = "";
        let binds = "";

        for (const line of text.split("\n")) {
            const match = line.match(/^(widgets|desktop|effects|binds)\t(.*)$/);
            if (!match)
                continue;

            const [, kind, payload] = match;

            if (kind === "widgets")
                widgets += `${payload}\n`;
            else if (kind === "desktop")
                desktop += `${payload}\n`;
            else if (kind === "effects")
                effects += `${payload}\n`;
            else
                binds += `${payload}\n`;
        }

        root.applyWidgets(widgets);
        root.applyDesktop(desktop);
        root.applyEffects(effects);
        root.applyBinds(binds);
    }

    function applyDesktop(text: string): void {
        const list = [];

        for (const line of text.split("\n")) {
            if (!line.trim())
                continue;

            const separator = line.indexOf("\t");
            if (separator < 0)
                continue;

            const id = line.slice(0, separator);
            if (!root.isEnabled(id))
                continue;

            let data;
            try {
                data = JSON.parse(line.slice(separator + 1));
            } catch (error) {
                continue;
            }

            const widgets = data?.widgets ?? [];
            for (let index = 0; index < widgets.length; index++) {
                const widget = widgets[index] ?? {};

                list.push({
                    key: `${id}:${widget.id ?? index}`,
                    pluginId: id,
                    x: widget.x,
                    y: widget.y,
                    anchor: widget.anchor ?? "",
                    margin: widget.margin,
                    width: widget.width,
                    height: widget.height,
                    url: widget.url ?? "",
                    refresh: widget.refresh,
                    icon: widget.icon ?? "",
                    title: widget.title ?? "",
                    text: widget.text ?? "",
                    subtext: widget.subtext ?? ""
                });
            }
        }

        root.desktopWidgets = list;
    }

    // Background effects (snow, ...) declared by plugins: one line per plugin, `id <TAB> json`.
    function applyEffects(text: string): void {
        const list = [];

        for (const line of text.split("\n")) {
            if (!line.trim())
                continue;

            const separator = line.indexOf("\t");
            if (separator < 0)
                continue;

            const id = line.slice(0, separator);
            if (!root.isEnabled(id))
                continue;

            let data;
            try {
                data = JSON.parse(line.slice(separator + 1));
            } catch (error) {
                continue;
            }

            const effects = data?.effects ?? [];
            for (let index = 0; index < effects.length; index++) {
                const effect = effects[index] ?? {};
                const type = effect.type ?? "";

                if (type !== "shader")
                    continue;

                // shader paths are relative to the plugin executable
                const plugin = root.plugins.find(item => item.id === id);
                const executable = plugin?.path ?? "";
                const directory = executable.includes("/") ? executable.slice(0, executable.lastIndexOf("/")) : "";
                let fragment = effect.fragment ?? "";

                if (fragment && !fragment.startsWith("/") && !fragment.startsWith("file:") && directory)
                    fragment = `${directory}/${fragment}`;

                list.push({
                    key: `${id}:${type}:${index}`,
                    pluginId: id,
                    type: type,
                    fragment: fragment.startsWith("file:") || !fragment ? fragment : `file://${fragment}`,
                    uniforms: effect.uniforms ?? {},
                    timeScale: effect.timeScale ?? 1,
                    renderScale: effect.renderScale ?? 1,
                    layer: effect.layer === "overlay" ? "overlay" : "background",
                    monitors: Array.isArray(effect.monitors) ? effect.monitors : []
                });
            }
        }

        root.effects = list;
    }

    // True when the effect should be drawn on this screen (empty `monitors` = everywhere).
    function effectOnScreen(effect: var, screenName: string): bool {
        const monitors = effect?.monitors ?? [];

        if (!Array.isArray(monitors) || monitors.length === 0)
            return true;

        return monitors.indexOf(screenName) !== -1;
    }

    // Keyboard shortcuts: `binds` capability, registered as Hyprland binds that call
    // `caelestia:plugin:<plugin>:<bind>` and end up in `run bind <id>` of that plugin.
    function applyBinds(text: string): void {
        const list = [];

        for (const line of text.split("\n")) {
            if (!line.trim())
                continue;

            const separator = line.indexOf("\t");
            if (separator < 0)
                continue;

            const id = line.slice(0, separator);
            if (!root.isEnabled(id))
                continue;

            let data;
            try {
                data = JSON.parse(line.slice(separator + 1));
            } catch (error) {
                continue;
            }

            for (const bind of Array.isArray(data) ? data : []) {
                if (!bind?.key || !bind?.id)
                    continue;

                list.push({
                    key: `${id}:${bind.id}`,
                    pluginId: id,
                    bindId: bind.id,
                    shortcut: bind.key,
                    name: `plugin:${id}:${bind.id}`,
                    description: bind.description ?? bind.id
                });
            }
        }

        root.binds = list;
        root.registerBinds();
    }

    function refreshBinds(): void {
        root.refreshPoll();
    }

    // Re-creates the Hyprland binds for the current plugin set (unbinding what was registered
    // before, so a removed plugin or a changed combo does not leave a dead shortcut behind).
    function registerBinds(): void {
        if (!Hypr.usingLua)
            return;

        const commands = [];

        for (const old of root.registeredBinds)
            commands.push(`eval hl.unbind("${old.shortcut}")`);

        for (const bind of root.binds) {
            const description = String(bind.description).replace(/"/g, "'");
            commands.push(`eval hl.bind("${bind.shortcut}", hl.dsp.global("caelestia:${bind.name}"), { description = "Plugin: ${description}" })`);
        }

        root.registeredBinds = root.binds.slice();

        if (commands.length > 0)
            Hypr.extras.batchMessage(commands);
    }

    function runBind(pluginId: string, bindId: string): void {
        const plugin = root.plugins.find(item => item.id === pluginId);

        if (plugin)
            root.runAction(plugin, "bind", bindId);
    }

    property var registeredBinds: []

    function refreshEffects(): void {
        root.refreshPoll();
    }

    function applyWidgets(text: string): void {
        const list = [];

        for (const line of text.split("\n")) {
            if (!line.trim())
                continue;

            let data;
            try {
                data = JSON.parse(line);
            } catch (error) {
                continue;
            }

            const id = data?.plugin;
            if (!id || !root.isEnabled(id))
                continue;

            const widgets = data.widgets ?? [];
            for (let index = 0; index < widgets.length; index++) {
                const widget = widgets[index] ?? {};
                const widgetId = widget.id ?? String(index);

                list.push({
                    key: `${id}:${widgetId}`,
                    pluginId: id,
                    widgetId: widgetId,
                    icon: widget.icon ?? "",
                    text: widget.text ?? "",
                    tooltip: widget.tooltip ?? ""
                });
            }
        }

        root.widgets = list;
        root.widgetSignature = list.map(widget => widget.key).join(",");
    }

    function sendEvent(plugin: var, controlId: string, value: var): void {
        if (!plugin?.path || !controlId)
            return;

        actionProc.command = [plugin.path, "event", controlId, JSON.stringify(value)];
        actionProc.running = true;
        actionProc.pendingPluginId = plugin.id;
    }

    function runAction(plugin: var, actionId: string, argument): void {
        if (!plugin?.path || !actionId)
            return;

        actionProc.command = argument ? [plugin.path, "run", actionId, argument] : [plugin.path, "run", actionId];
        actionProc.pendingPluginId = "";
        actionProc.running = true;
    }

    function runWidgetClick(pluginId: string, widgetId: string): void {
        const plugin = root.plugins.find(item => item.id === pluginId);
        if (plugin)
            root.runAction(plugin, "click", widgetId);
    }

    function notify(title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "Caelestia", title, body]);
    }

    function removePlugin(plugin: var): void {
        if (!plugin?.id)
            return;

        removeProc.command = ["python3", Quickshell.shellPath("scripts/plugin-remove.py"), plugin.id];
        removeProc.running = true;

        root.forgetPlugin(plugin.id, true);
    }

    function importArchive(path: string): void {
        if (!path)
            return;

        importProc.command = ["python3", Quickshell.shellPath("scripts/plugin-unpack.py"), path];
        importProc.running = true;
    }

    function rebuildSchemes(): void {
        const list = [];

        for (const plugin of root.plugins) {
            if (!plugin.enabled)
                continue;
            for (const scheme of plugin.schemes) {
                list.push({
                    key: `${plugin.id}:${scheme.id}`,
                    pluginId: plugin.id,
                    pluginName: plugin.name,
                    id: scheme.id,
                    name: scheme.name ?? scheme.id,
                    seed: scheme.seed,
                    mode: scheme.mode ?? "dark",
                    variant: scheme.variant ?? "tonalspot"
                });
            }
        }

        root.schemes = list;
    }

    function load(text: string): void {
        const list = [];

        for (const line of text.split("\n")) {
            if (!line.trim())
                continue;

            const parts = line.split("\t");
            if (parts.length < 4)
                continue;

            const [id, path, infoRaw, schemesRaw, icon, actionsRaw] = parts;

            let info;
            try {
                info = JSON.parse(infoRaw);
            } catch (error) {
                continue;
            }

            let schemes = [];
            try {
                schemes = JSON.parse(schemesRaw);
            } catch (error) {
                schemes = [];
            }

            let actions = [];
            try {
                actions = JSON.parse(actionsRaw);
            } catch (error) {
                actions = [];
            }

            list.push({
                id: id,
                path: path,
                name: info.name ?? id,
                description: info.description ?? "",
                version: info.version ?? "",
                capabilities: info.capabilities ?? [],
                schemes: Array.isArray(schemes) ? schemes : [],
                actions: Array.isArray(actions) ? actions : [],
                icon: icon && icon.length > 0 ? `file://${icon}` : "",
                enabled: root.isEnabled(id)
            });
        }

        root.plugins = list;
        root.rebuildSchemes();
    }

    Component.onCompleted: root.refresh()

    // a Hyprland config reload drops every runtime bind, so register the plugin ones again
    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.registeredBinds = [];
            root.registerBinds();
        }
    }

    Connections {
        function onDisabledPluginsChanged(): void {
            for (const plugin of root.plugins)
                plugin.enabled = root.isEnabled(plugin.id);
            root.rebuildSchemes();
        }

        target: UiPrefs
    }

    Process {
        id: scan

        command: ["sh", Quickshell.shellPath("scripts/plugins-scan.sh")]

        stdout: StdioCollector {
            onStreamFinished: root.load(text)
        }

        onExited: {
            root.scanning = false;
            root.refreshWidgets();
        }
    }

    Process {
        id: applyProc

        onExited: root.refresh()
    }

    Process {
        id: schemeProc
    }

    Process {
        id: pollProc

        command: ["sh", Quickshell.shellPath("scripts/plugins-poll.sh")]

        stdout: StdioCollector {
            onStreamFinished: root.applyPoll(text)
        }
    }

    Process {
        id: actionProc

        property string pendingPluginId: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message)
                    root.notify(Tr.tr("Plugin"), message);
            }
        }

        onExited: {
            root.refreshEffects();

            if (actionProc.pendingPluginId) {
                root.eventFinished(actionProc.pendingPluginId);
                actionProc.pendingPluginId = "";
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true

        onTriggered: root.refreshWidgets()
    }

    Process {
        id: removeProc

        stdout: StdioCollector {
            onStreamFinished: {
                const id = text.trim();
                if (id)
                    root.notify(Tr.tr("Plugin removed"), id);
            }
        }

        onExited: root.refresh()
    }

    Process {
        id: importProc

        stdout: StdioCollector {
            onStreamFinished: {
                const ids = text.trim();
                if (ids)
                    root.notify(Tr.tr("Plugins imported"), ids);
            }
        }

        onExited: root.refresh()
    }
}
