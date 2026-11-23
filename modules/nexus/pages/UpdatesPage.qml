pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Updates: the Storm config (git), the caelestia packages and the rest of the system.
PageBase {
    id: root

    readonly property string shellDir: logic.shellDir
    readonly property var packages: logic.packages
    readonly property string installedCommit: logic.installedCommit
    readonly property string remoteCommit: logic.remoteCommit
    readonly property string helper: logic.helper
    readonly property bool checking: logic.checking
    readonly property string message: logic.message
    readonly property var pending: logic.pending
    readonly property var versions: logic.versions
    readonly property bool stormBehind: logic.stormBehind
    readonly property int pendingCount: logic.pendingCount

    title: Tr.tr("Updates")

    Component.onCompleted: logic.check()

    function check(): void {
        logic.check();
    }

    function updateStorm(): void {
        logic.updateStorm();
    }

    function updatePackages(): void {
        logic.updatePackages();
    }

    function installStorm(): void {
        logic.installStorm();
    }

    // A non-visual holder so `Process` objects have an Item to live in.
    Item {
        id: logic

        visible: false
        width: 0
        height: 0

        readonly property string shellDir: Quickshell.shellPath("assets/wallpaper.webp").replace(/\/assets\/wallpaper\.webp$/, "")
        readonly property string repoUrl: "https://github.com/0xcds4r/caelestia-storm.git"
        readonly property var packages: ["caelestia-shell", "caelestia-cli", "quickshell-git"]

        property string installedCommit: ""
        property string remoteCommit: ""
        property string helper: ""
        property bool checking: false
        property string message: ""
        property var pending: ({})
        property var versions: ({})

        readonly property bool stormBehind: installedCommit.length > 0 && remoteCommit.length > 0 && remoteCommit !== installedCommit
        readonly property int pendingCount: Object.keys(pending).length

        function check(): void {
            if (logic.checking)
                return;

            logic.checking = true;
            logic.message = "";
            installedProc.running = true;
        }

        function updateStorm(): void {
            logic.message = Tr.tr("Updating the Storm config…");
            pullProc.running = true;
        }

        function installStorm(): void {
            const terminal = GlobalConfig.general.apps.terminal ?? ["kitty"];
            const command = `cd ${logic.shellDir} && ./install.sh -y -n; echo; read -n1 -p 'press enter to close'`;

            Quickshell.execDetached([...terminal, "-e", "sh", "-c", command]);
            logic.message = Tr.tr("Opened the Storm installer in a terminal.");
        }

        function updatePackages(): void {
            const terminal = GlobalConfig.general.apps.terminal ?? ["kitty"];
            const command = `${logic.helper || "paru"} -Syu --needed ${logic.packages.join(" ")}; echo; read -n1 -p 'press enter to close'`;

            Quickshell.execDetached([...terminal, "-e", "sh", "-c", command]);
            logic.message = Tr.tr("Opened the package update in a terminal.");
        }

    Process {
        id: helperProc

        command: ["sh", "-c", "command -v paru 2>/dev/null || command -v yay 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: logic.helper = text.trim()
        }

        onExited: versionsProc.running = true
    }

    Process {
        id: installedProc

        command: ["git", "-C", logic.shellDir, "rev-parse", "--short", "HEAD"]

        stdout: StdioCollector {
            onStreamFinished: logic.installedCommit = text.trim()
        }

        onExited: remoteProc.running = true
    }

    Process {
        id: remoteProc

        command: ["git", "ls-remote", logic.repoUrl, "refs/heads/main"]

        stdout: StdioCollector {
            onStreamFinished: {
                const commit = text.trim().split(/\s+/)[0] ?? "";
                logic.remoteCommit = commit.slice(0, 7);
            }
        }

        onExited: helperProc.running = true
    }

    Process {
        id: versionsProc

        command: ["pacman", "-Q", ...logic.packages]

        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};

                for (const line of text.split("\n")) {
                    const [name, version] = line.trim().split(/\s+/);
                    if (name && version)
                        map[name] = version;
                }

                logic.versions = map;
            }
        }

        onExited: repoPendingProc.running = true
    }

    Process {
        id: repoPendingProc

        command: ["sh", "-c", "command -v checkupdates >/dev/null 2>&1 && checkupdates || pacman -Qu"]

        stdout: StdioCollector {
            onStreamFinished: logic.mergePending(text, false)
        }

        onExited: aurPendingProc.running = true
    }

    Process {
        id: aurPendingProc

        command: ["sh", "-c", "test -n \"$1\" && \"$1\" -Qua 2>/dev/null || true", "sh", logic.helper]

        stdout: StdioCollector {
            onStreamFinished: logic.mergePending(text, true)
        }

        onExited: logic.checking = false
    }

    Process {
        id: pullProc

        command: ["sh", "-c", `git -C "${logic.shellDir}" pull --ff-only 2>&1`]

        stdout: StdioCollector {
            onStreamFinished: {
                const summary = text.trim().split("\n").slice(-1)[0] ?? "";
                logic.message = summary.length > 0 ? summary : Tr.tr("Already up to date.");
            }
        }

        onExited: logic.check()
    }

        // `checkupdates` and `paru -Qua` both print `name old -> new`.
        function mergePending(text: string, append: bool): void {
            const map = append ? Object.assign({}, logic.pending) : {};

            for (const line of text.split("\n")) {
                const match = line.trim().match(/^(\S+)\s+(\S+)\s+->\s+(\S+)$/);
                if (match)
                    map[match[1]] = `${match[2]} → ${match[3]}`;
            }

            logic.pending = map;
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: Tr.tr("Caelestia Storm")
        }

        InfoRow {
            label: Tr.tr("Installed commit")
            value: root.installedCommit.length > 0 ? root.installedCommit : "—"
            icon: "commit"
        }

        InfoRow {
            label: Tr.tr("Main branch")
            value: root.remoteCommit.length > 0 ? root.remoteCommit : "—"
            icon: "cloud_download"
        }

        InfoRow {
            visible: root.stormBehind
            label: Tr.tr("Update available")
            value: Tr.tr("%1 commit behind").arg("1+")
            icon: "new_releases"
            iconColour: Colours.palette.m3primary
        }

        RowButton {
            icon: "system_update_alt"
            visible: root.installedCommit.length > 0
            text: Tr.tr("Update Storm")
            subtext: Tr.tr("git pull in %1").arg(root.shellDir)
            disabled: root.checking
            onClicked: root.updateStorm()
        }

        RowButton {
            icon: "download_for_offline"
            visible: root.installedCommit.length === 0
            text: Tr.tr("Install Storm")
            subtext: Tr.tr("runs install.sh in a terminal")
            onClicked: root.installStorm()
        }

        RowButton {
            icon: "restart_alt"
            text: Tr.tr("Restart shell")
            subtext: Tr.tr("caelestia shell -r -d")
            onClicked: Quickshell.execDetached(["caelestia", "shell", "-r", "-d"])
        }

        SectionHeader {
            text: Tr.tr("Caelestia packages")
        }

        Repeater {
            model: root.packages

            InfoRow {
                required property string modelData

                label: modelData
                value: {
                    const update = root.pending[modelData];
                    const installed = root.versions[modelData] ?? Tr.tr("not installed");

                    return update ? `${installed}  ·  ${update}` : installed;
                }
                icon: root.pending[modelData] ? "arrow_circle_up" : "check_circle"
                iconColour: root.pending[modelData] ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }
        }

        SectionHeader {
            text: Tr.tr("System libraries")
        }

        InfoRow {
            label: Tr.tr("Pending updates")
            value: root.checking ? Tr.tr("checking…") : root.pendingCount.toString()
            icon: "inventory_2"
            iconColour: root.pendingCount > 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        }

        Repeater {
            model: Object.keys(root.pending).filter(name => !root.packages.includes(name)).slice(0, 12)

            InfoRow {
                required property string modelData

                label: modelData
                value: root.pending[modelData] ?? ""
                icon: "deployed_code_update"
            }
        }

        RowButton {
            icon: "sync"
            text: Tr.tr("Check for updates")
            subtext: Tr.tr("Storm, packages and libraries")
            disabled: root.checking
            onClicked: root.check()
        }

        RowButton {
            icon: "download"
            text: Tr.tr("Update packages")
            subtext: root.helper.length > 0 ? `${root.helper} -Syu --needed …` : Tr.tr("no paru or yay found")
            disabled: root.helper.length === 0
            onClicked: root.updatePackages()
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.message.length > 0
            text: root.message
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            wrapMode: Text.Wrap
        }
    }
}
