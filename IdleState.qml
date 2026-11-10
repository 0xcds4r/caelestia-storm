import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Local patch: PersistentProperties doesn't survive a shell restart here,
// so keep the idle inhibitor state in a tiny file of our own.
Item {
    id: root

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/caelestia"

    FileView {
        id: stateFile

        path: root.dir + "/idle-inhibited"

        onLoaded: {
            if (text().trim() === "true")
                IdleInhibitor.enabled = true;
        }
    }

    Connections {
        function onEnabledChanged(): void {
            writer.command = ["sh", "-c", `mkdir -p "${root.dir}" && printf '%s' '${IdleInhibitor.enabled}' > "${root.dir}/idle-inhibited"`];
            writer.running = true;
        }

        target: IdleInhibitor
    }

    Process {
        id: writer
    }
}
