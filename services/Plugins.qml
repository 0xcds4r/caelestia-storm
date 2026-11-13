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
    // Stable key for the set of widget plugins, so the bar's repeater is not rebuilt on every poll
    property string widgetSignature: ""
    property bool scanning: false

    // Emitted after a plugin handled an event (e.g. a control in its window changed)
    signal eventFinished(string pluginId)

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
        UiPrefs.setPluginEnabled(pluginId, enabled);
        root.rebuildSchemes();
    }

    function applyScheme(scheme: var): void {
        if (!scheme?.seed)
            return;

        applyProc.command = ["python3", Quickshell.shellPath("scripts/scheme-from-seed.py"), "--seed", scheme.seed, "--mode", scheme.mode ?? "dark", "--variant", scheme.variant ?? "tonalspot"];
        applyProc.running = true;

        UiPrefs.appliedPluginScheme = scheme.key;
        UiPrefs.save();
    }

    function widgetFor(key: string): var {
        return root.widgets.find(widget => widget.key === key) ?? null;
    }

    function refreshWidgets(): void {
        if (widgetPoll.running)
            return;

        widgetPoll.running = true;

        if (!desktopPoll.running)
            desktopPoll.running = true;
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
                    icon: widget.icon ?? "",
                    title: widget.title ?? "",
                    text: widget.text ?? "",
                    subtext: widget.subtext ?? ""
                });
            }
        }

        root.desktopWidgets = list;
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

        if (UiPrefs.appliedPluginScheme.startsWith(`${plugin.id}:`)) {
            UiPrefs.appliedPluginScheme = "";
            UiPrefs.save();
        }
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
        id: desktopPoll

        command: ["sh", Quickshell.shellPath("scripts/plugins-desktop.sh")]

        stdout: StdioCollector {
            onStreamFinished: root.applyDesktop(text)
        }
    }

    Process {
        id: widgetPoll

        command: ["sh", Quickshell.shellPath("scripts/plugins-widgets.sh")]

        stdout: StdioCollector {
            onStreamFinished: root.applyWidgets(text)
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
