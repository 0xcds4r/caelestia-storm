pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.widgets
import qs.services

FocusScope {
    id: root

    focus: true

    signal activated()
    signal dismissed()

    property var entries: []
    property int currentIndex: 0

    readonly property int cardWidth: 720
    readonly property int maxEntries: 60
    readonly property string thumbDir: "/tmp/caelestia-clip"

    implicitWidth: root.cardWidth
    implicitHeight: Math.max(200, column.implicitHeight)

    Keys.onUpPressed: root.move(-1)
    Keys.onDownPressed: root.move(1)
    Keys.onReturnPressed: root.copy(root.currentIndex)
    Keys.onEnterPressed: root.copy(root.currentIndex)
    Keys.onDeletePressed: root.remove(root.currentIndex)
    Keys.onEscapePressed: root.dismissed()

    function refresh(): void {
        root.currentIndex = 0;
        lister.running = false;
        lister.running = true;
    }

    function move(delta: int): void {
        if (root.entries.length === 0)
            return;
        root.currentIndex = Math.max(0, Math.min(root.entries.length - 1, root.currentIndex + delta));
    }

    function copy(index: int): void {
        const entry = root.entries[index];
        if (!entry)
            return;
        copier.exec(["sh", "-c", `cliphist decode ${entry.id} | wl-copy`]);
        root.activated();
    }

    function remove(index: int): void {
        const entry = root.entries[index];
        if (!entry)
            return;
        remover.exec(["sh", "-c", `cliphist list | awk -F'\t' -v id=${entry.id} '$1 == id' | cliphist delete`]);
        root.refresh();
    }

    function wipe(): void {
        wipeProc.exec(["cliphist", "wipe"]);
        root.refresh();
    }

    onVisibleChanged: {
        if (visible)
            root.refresh();
    }

    Process {
        id: lister

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(line => line.trim().length > 0);
                const parsed = [];

                for (const line of lines) {
                    if (parsed.length >= root.maxEntries)
                        break;

                    const tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;

                    const id = line.slice(0, tab);
                    const raw = line.slice(tab + 1);
                    const binary = raw.startsWith("[[ binary data");
                    const meta = binary ? (raw.match(/\[\[ binary data (\d+ \w+) (\w+) (\d+)x(\d+) \]\]/) ?? []) : [];

                    parsed.push({
                        id: id,
                        binary: binary,
                        text: binary ? `${(meta[2] ?? "image").toUpperCase()} ${meta[3] ?? ""}×${meta[4] ?? ""} · ${meta[1] ?? ""}` : raw,
                        thumb: binary ? `${root.thumbDir}/${id}.png` : ""
                    });
                }

                root.entries = parsed;
                root.currentIndex = 0;
            }
        }
    }

    Process {
        id: copier
    }

    Process {
        id: remover
    }

    Process {
        id: wipeProc
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.medium
                text: Tr.tr("Clipboard")
            }

            StyledText {
                text: root.entries.length
                color: Colours.palette.m3onSurfaceVariant
            }

            MaterialIcon {
                visible: root.entries.length > 0
                text: "delete_sweep"
                color: Colours.palette.m3onSurfaceVariant

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.wipe()
                }
            }
        }

        StyledListView {
            id: list

            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.medium
            Layout.fillHeight: false
            implicitWidth: 0
            implicitHeight: Math.min(contentHeight, 420)
            clip: true
            spacing: Tokens.spacing.extraSmall
            currentIndex: root.currentIndex

            model: ScriptModel {
                values: root.entries
            }

            delegate: StyledRect {
                id: card

                required property var modelData
                required property int index

                readonly property bool current: index === root.currentIndex
                readonly property int rowHeight: Tokens.padding.extraLarge + Tokens.padding.medium

                width: list.width
                implicitHeight: card.rowHeight + Tokens.padding.small * 2
                radius: Tokens.rounding.medium
                color: card.current ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

                RowLayout {
                    id: row

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: Tokens.spacing.medium

                    StyledClippingRect {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Math.round(card.rowHeight * 16 / 9)
                        implicitHeight: card.rowHeight
                        radius: Tokens.rounding.small
                        color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
                        visible: card.modelData.binary

                        Image {
                            id: thumb

                            anchors.fill: parent
                            asynchronous: true
                            cache: false
                            fillMode: Image.PreserveAspectCrop
                            source: ctx.ready && card.modelData.binary ? `file://${card.modelData.thumb}` : ""
                        }
                    }

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        visible: !card.modelData.binary
                        text: "content_paste"
                        color: card.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: card.modelData.text
                        maximumLineCount: card.modelData.binary ? 1 : 2
                        elide: Text.ElideRight
                        color: card.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    }

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        text: "close"
                        color: card.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentIndex = card.index;
                                root.remove(card.index);
                            }
                        }
                    }
                }

                QtObject {
                    id: ctx

                    property bool ready: false

                    Component.onCompleted: {
                        if (!card.modelData.binary)
                            return;
                        decoder.command = ["sh", "-c", `mkdir -p ${root.thumbDir} && cliphist decode ${card.modelData.id} > ${card.modelData.thumb} 2>/dev/null`];
                        decoder.running = true;
                    }

                    readonly property Process decoder: Process {
                        onExited: ctx.ready = true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: card.rowHeight
                    onClicked: {
                        root.currentIndex = card.index;
                        root.copy(card.index);
                    }
                }
            }

            onCurrentIndexChanged: positionViewAtIndex(root.currentIndex, ListView.Contain)
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.padding.large
            Layout.bottomMargin: Tokens.padding.large
            visible: root.entries.length === 0
            text: Tr.tr("Clipboard is empty")
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
