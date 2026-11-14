pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Default handlers for URI schemes and MIME types, backed by xdg-mime / mimeapps.list.
Singleton {
    id: root

    // [{type, current, registered: [desktop ids]}]
    property var entries: []
    // Bumped when the desktop entry database becomes available, so name/icon lookups re-evaluate
    property int desktopRevision: 0

    function find(type: string): var {
        return root.entries.find(entry => entry.type === type) ?? null;
    }

    function current(type: string): string {
        return root.find(type)?.current ?? "";
    }

    function registered(type: string): var {
        return root.find(type)?.registered ?? [];
    }

    // Desktop entry ids from the mime database keep the ".desktop" suffix, Quickshell stores them
    // without it.
    function entryFor(id: string): var {
        root.desktopRevision;
        if (!id)
            return null;
        return DesktopEntries.byId(id) ?? DesktopEntries.byId(id.replace(/\.desktop$/, ""));
    }

    function applicationName(id: string): string {
        return root.entryFor(id)?.name ?? id;
    }

    function applicationIcon(id: string): string {
        return Quickshell.iconPath(root.entryFor(id)?.icon ?? "", "image-missing");
    }

    function refresh(): void {
        if (!listProc.running)
            listProc.running = true;
    }

    function setDefault(type: string, id: string): void {
        if (!type || !id)
            return;

        setProc.command = ["sh", Quickshell.shellPath("scripts/mime-defaults.sh"), "set", type, id];
        setProc.running = true;
    }

    function load(text: string): void {
        const list = [];

        for (const line of text.split("\n")) {
            if (!line.trim())
                continue;

            const [type, current, registered] = line.split("\t");
            list.push({
                type: type,
                current: current ?? "",
                registered: (registered ?? "").split("|").filter(id => id.length > 0)
            });
        }

        root.entries = list;
    }

    Component.onCompleted: root.refresh()

    Connections {
        function onApplicationsChanged(): void {
            root.desktopRevision++;
        }

        target: DesktopEntries
    }

    Process {
        id: listProc

        command: ["sh", Quickshell.shellPath("scripts/mime-defaults.sh"), "list"]

        stdout: StdioCollector {
            onStreamFinished: root.load(text)
        }
    }

    Process {
        id: setProc

        onExited: root.refresh()
    }
}
