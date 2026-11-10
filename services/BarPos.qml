pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bar position: left | right | top | bottom.
// Not part of the C++ config (the plugin is packaged), so it lives in a small state file.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/caelestia"
    readonly property string path: root.stateDir + "/bar-position"

    readonly property var positions: ["left", "right", "top", "bottom"]

    property string position: "left"

    readonly property bool vertical: root.position === "left" || root.position === "right"
    readonly property bool onLeft: root.position === "left"
    readonly property bool onRight: root.position === "right"
    readonly property bool onTop: root.position === "top"
    readonly property bool onBottom: root.position === "bottom"

    function set(pos: string): void {
        if (root.positions.indexOf(pos) < 0 || pos === root.position)
            return;

        root.position = pos;
        writer.command = ["sh", "-c", `mkdir -p '${root.stateDir}' && printf '%s' '${pos}' > '${root.path}' && sleep 0.4 && setsid caelestia shell -r -d >/dev/null 2>&1 &`];
        writer.running = true;
    }

    FileView {
        path: root.path

        onLoaded: {
            const value = text().trim();
            if (value && root.positions.indexOf(value) >= 0)
                root.position = value;
        }
    }

    Process {
        id: writer
    }
}
