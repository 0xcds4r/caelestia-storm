pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Rust (or any language) plugins: an executable in ~/.config/caelestia/plugins that answers
//   `info`     -> {"name": "...", "description": "...", "version": "...", "capabilities": ["schemes"]}
//   `schemes`  -> [{"id": "...", "name": "...", "seed": "#rrggbb", "mode": "dark|light", "variant": "..."}]
// Plugin schemes are expanded into a full palette by scripts/scheme-from-seed.py and applied.
Singleton {
    id: root

    property var plugins: []
    property var schemes: []
    property bool scanning: false

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

            const [id, path, infoRaw, schemesRaw] = parts;

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

            list.push({
                id: id,
                path: path,
                name: info.name ?? id,
                description: info.description ?? "",
                version: info.version ?? "",
                capabilities: info.capabilities ?? [],
                schemes: Array.isArray(schemes) ? schemes : [],
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

        onExited: root.scanning = false
    }

    Process {
        id: applyProc

        onExited: root.refresh()
    }
}
