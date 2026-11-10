pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Detects whether the default route goes through a tunnel (WireGuard, tun/tap, etc.)
Singleton {
    id: root

    property string iface: ""
    readonly property bool active: root.iface.length > 0

    Process {
        id: probe

        command: ["sh", "-c", "ip route get 1.1.1.1 2>/dev/null | head -1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/dev\s+(\S+)/);
                const dev = match ? match[1] : "";
                root.iface = /^(tun|tap|wg|ppp|tailscale|zt|nordlynx|proton)/.test(dev) ? dev : "";
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: probe.running = true
    }
}
