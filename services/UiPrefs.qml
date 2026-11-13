pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// UI preferences that are not part of the (packaged) C++ config, persisted as JSON in the state dir.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/caelestia"
    readonly property string path: root.stateDir + "/ui-prefs.json"

    // Open the dashboard (top) / launcher (bottom) by holding and dragging from the screen edge
    property bool panelsDragOpen: true
    // Plugin ids that the user turned off
    property var disabledPlugins: []
    // Plugin scheme currently applied ("<plugin id>:<scheme id>"), empty for built-in schemes
    property string appliedPluginScheme: ""

    function save(): void {
        const data = JSON.stringify({
            panelsDragOpen: root.panelsDragOpen,
            disabledPlugins: root.disabledPlugins,
            appliedPluginScheme: root.appliedPluginScheme
        });
        writer.command = ["sh", "-c", `mkdir -p '${root.stateDir}' && printf '%s' '${data}' > '${root.path}'`];
        writer.running = true;
    }

    function setPanelsDragOpen(value: bool): void {
        root.panelsDragOpen = value;
        root.save();
    }

    function setPluginEnabled(pluginId: string, enabled: bool): void {
        const list = root.disabledPlugins.filter(id => id !== pluginId);
        if (!enabled)
            list.push(pluginId);
        root.disabledPlugins = list;
        root.save();
    }

    FileView {
        path: root.path

        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (typeof data.panelsDragOpen === "boolean")
                    root.panelsDragOpen = data.panelsDragOpen;
                if (Array.isArray(data.disabledPlugins))
                    root.disabledPlugins = data.disabledPlugins;
                if (typeof data.appliedPluginScheme === "string")
                    root.appliedPluginScheme = data.appliedPluginScheme;
            } catch (error) {
                console.warn("Unable to parse ui-prefs.json:", error);
            }
        }
    }

    Process {
        id: writer
    }
}
