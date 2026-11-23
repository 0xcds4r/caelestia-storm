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
    // Hyprland: `general:resize_on_border` — right-drag near a window edge resizes it
    property bool resizeOnBorder: false
    // Plugin ids that the user turned off
    property var disabledPlugins: []
    // Plugin scheme currently applied ("<plugin id>:<scheme id>"), empty for built-in schemes
    property string appliedPluginScheme: ""
    // Scheme to restore when the plugin owning the current scheme is disabled (JSON)
    property string previousScheme: ""

    function save(): void {
        const data = JSON.stringify({
            panelsDragOpen: root.panelsDragOpen,
            resizeOnBorder: root.resizeOnBorder,
            disabledPlugins: root.disabledPlugins,
            appliedPluginScheme: root.appliedPluginScheme,
            previousScheme: root.previousScheme
        });
        // The plugin scripts read this file so they do not even execute disabled plugins.
        const disabled = root.disabledPlugins.join("\n");
        writer.command = ["sh", "-c", `mkdir -p '${root.stateDir}' && printf '%s' '${data}' > '${root.path}' && printf '%s' '${disabled}' > '${root.stateDir}/disabled-plugins'`];
        writer.running = true;
    }

    function setPanelsDragOpen(value: bool): void {
        root.panelsDragOpen = value;
        root.save();
    }

    function setResizeOnBorder(value: bool): void {
        root.resizeOnBorder = value;

        // Both gestures start with a drag at a window edge, so they cannot be on at the same time
        if (value)
            root.panelsDragOpen = false;

        root.save();
        Hypr.applyWindowOptions();
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
                if (typeof data.resizeOnBorder === "boolean")
                    root.resizeOnBorder = data.resizeOnBorder;
                if (Array.isArray(data.disabledPlugins))
                    root.disabledPlugins = data.disabledPlugins;
                if (typeof data.appliedPluginScheme === "string")
                    root.appliedPluginScheme = data.appliedPluginScheme;
                if (typeof data.previousScheme === "string")
                    root.previousScheme = data.previousScheme;
            } catch (error) {
                console.warn("Unable to parse ui-prefs.json:", error);
            }
        }
    }

    Process {
        id: writer
    }
}
