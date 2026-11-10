pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.components.containers
import qs.components.widgets

FocusScope {
    id: root

    focus: true

    Keys.onUpPressed: root.move(-1)
    Keys.onDownPressed: root.move(1)
    Keys.onReturnPressed: root.copy(root.currentIndex)
    Keys.onEnterPressed: root.copy(root.currentIndex)
    Keys.onEscapePressed: root.dismissed()

    signal activated()
    signal dismissed()

    property var entries: []
    property int currentIndex: 0

    readonly property int cardWidth: 720

    implicitWidth: root.cardWidth
    implicitHeight: Math.max(200, column.implicitHeight)

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
                    const tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;

                    const id = line.slice(0, tab);
                    const raw = line.slice(tab + 1);
                    const binary = raw.startsWith("[[ binary data");
                    const text = binary ? (raw.match(/\[\[ binary data.*?(\w+) (\d+)x(\d+) \]\]/)?.slice(1).join(" ") ?? "image") : raw;

                    parsed.push({
                        id: id,
                        text: text,
                        binary: binary
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

                width: list.width
                implicitHeight: label.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: card.current ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        text: card.modelData.binary ? "image" : "content_paste"
                        color: card.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        id: label

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: card.modelData.text
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: card.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
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
